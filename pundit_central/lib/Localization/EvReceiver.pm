#!/usr/bin/perl
#
# Copyright 2016 Georgia Institute of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package Localization::EvReceiver;

use strict;
use threads;
use threads::shared;

use Localization::EvReceiver::MySQL;
use Localization::EvReceiver::Test;

# debug. Remove this for production
use Data::Dumper;

=pod

=head1 DESCRIPTION

This script reads the events from the database and processes it into a data structure that the loc_processor can use.

=cut

# loop control variable. Declared here so the handler has access to it
my $runLoop = 1;

sub exit_handler{
    $runLoop = 0;
}

# Top-level init for event receiver
sub new
{
	my ($class, $cfgHash, $siteName) = @_;
    
    # Shared structure that will hold the event queues
    my $evQueues = &share({});
    return undef if (!$evQueues);
    
    # Start the backend-specific receiver thread here
    my $rcvThread = threads->create(sub { run($cfgHash, $siteName, $evQueues); });
    return undef if (!$rcvThread);
    
	my $self = {
        '_rcvThr' => $rcvThread,
        '_evQueues' => $evQueues,
	};
    
    bless $self, $class;
    return $self;
}


# Top-level exit for event receiver
sub DESTROY
{
	# Do nothing?
	my ($self) = @_;
	
	$runLoop = 0;
	$self->{'_rcvThr'}->join();
}

# Returns the event table for the specified time period
sub getEventTable 
{
	my ($self, $refStart, $refEnd) = @_;

#    print time . ": Requested $refStart to $refEnd\n";

    return _getWindowFromQueues($self->{'_evQueues'}, $refStart, $refEnd);
}

# starts an infinte loop that pulls values out of a location into an internal structure
sub run
{
    my ($cfgHash, $siteName, $evQueues) = @_;
        
    my $sleepTime = 10;
    
    # init the sub-receiver based on the configuration settings
    my $subType = $cfgHash->{'pundit_central'}{$siteName}{'ev_receiver'}{'type'};
    my $subRcv;
    if ($subType eq "mysql")
    {
        $subRcv = new Localization::EvReceiver::MySQL($cfgHash, $siteName);
    }
    elsif ($subType eq "rabbitmq")
    {
        $subRcv = 'rabbitmq';
    }
    else # init the test receiver (debug)
    {
        $subRcv = new Localization::EvReceiver::Test();
    }
    thread_exit(-1) if (!$subRcv);
    
    my $lastTime = time - 300;
    
    while ($runLoop)
    {
        # Get the events from the sub-receiver
        my $evHash = $subRcv->getLatestEvents($lastTime);
        # Add it to the EvQueues
        _addHashToEvQueues($evQueues, $evHash);
        my $lastTime += $sleepTime;
        sleep($sleepTime);
    }
}

# Gets the reference window from the evQueues
sub _getWindowFromQueues
{
    my ($evQueues, $refStart, $refEnd) = @_;
    
    # Sanity check that evQueues has been populated before continuing
    return [] if (!%{$evQueues});
    
    # Loop over the evQueue entries 
    my @outArray = ();
    while (my ($srchost, $dstHash) = each %{$evQueues}) 
    {
        while (my ($dsthost, $evArray) = each %$dstHash) 
        {
            # Extract from this queue
            my $currWindow = _selectNextWindow($evQueues->{$srchost}{$dsthost}, $srchost, $dsthost, $refStart, $refEnd);
            
            # push onto the output array
            push(@outArray, $currWindow);            
        }    
    }
    return \@outArray;
    
}

# Selects the window closest to the reference time from an evQueue
# Modifies the queue: If there are any entries earlier than this refernce time, they will be discarded 
# Assumes the queues are packed with no gaps between 2 consecutive windows
sub _selectNextWindow
{
    my ($evQueue, $srchost, $dsthost, $refStart, $refEnd) = @_;
    
    # discard values at the start which are clearly not suitable
    # 1. Endtimes that are before the requested reference start time
    while ((scalar(@{$evQueue->{'queue'}}) > 0) && 
           ($evQueue->{'queue'}[0]->{'endTime'} < $refStart))
    {
        {
            print "discarding " . $evQueue->{'queue'}[0]{'startTime'} . "\n";
            lock(@{$evQueue->{'queue'}});
            shift(@{$evQueue->{'queue'}});
        }
        
        # update firstTime after removing 
        if (scalar(@{$evQueue->{'queue'}}) > 0)
        {
            $evQueue->{'firstTime'} = $evQueue->{'queue'}[0]{'startTime'};
        }
    }
    
    # Return unknown if
    # 1. First entry is far ahead of reftime OR
    # 2. Empty queue
    if (($evQueue->{'firstTime'} > $refEnd) || 
        (scalar(@{$evQueue->{'queue'}}) == 0))
    {
        return {
            'startTime' => $refStart,
            'endTime' => $refEnd,
            'srchost' => $srchost,
            'dsthost' => $dsthost,
            'detectionCode' => -1,
        }
    }
    
    # Now compare the queue head with the reftime
    my %selected = %{$evQueue->{'queue'}[0]};
    my $selOverlap = _calcOverlap($refStart, $refEnd, $selected{'startTime'}, $selected{'endTime'});
    
    # Case 1: Significant overlap
    if (($selOverlap > 0.8) || 
        (scalar(@{$evQueue->{'queue'}}) == 1)) 
    {
        return \%selected;
    }
    # Case 2+: Nonsignificant overlap
    else 
    {
        # Check the next entry's overlap
        my %next = %{$evQueue->{'queue'}[1]}; # we already checked the length of the list before
        my $nextOverlap = _calcOverlap($refStart, $refEnd, $next{'startTime'}, $next{'endTine'});
        
        # selected overlap is not significant. Choose next.
        if ($selOverlap <= 0.2)
        {
            return \%next; # choose the next entry
        }
        
        # Case 2a: If next window doesn't have problems or is unknown, use first window
        if ($next{'detectionCode'} <= 0)
        {
            # Case 2b: Use next window if selected is unknown
            if ($selected{'detectionCode'} < 0)
            {
                return \%next; # choose the next entry
            }
            else
            {
                return \%selected; 
            }
        }
        
        # Case 3: Both have problems, return the average of both
        if ($selected{'detectionCode'} > 0)
        {
            # average it here in this block
            my $avg = {
                'startTime' => $selected{'startTime'},
                'endTime' => $next{'endTime'},
                'srchost' => $selected{'srchost'},
                'dsthost' => $selected{'dsthost'},
                'detectionCode' => $selected{'detectionCode'} || $next{'detectionCode'},
            };
            
            # Do a simple averaging here
            while (my $key = keys %selected)
            {
                # skip these fields
                if ($key eq 'startTime' || 
                    $key eq 'endTime' || 
                    $key eq 'srchost' ||
                    $key eq 'dsthost' ||
                    $key eq 'detectionCode')
                {
                    next;
                }
                # average the rest and store it in the new hash
                $avg->{$key} = ($selected{$key} + $next{$key}) / 2; 
            }
        }
        # Case 4: First window doesn't have problems, next does. Prefer the problematic one
        else
        {
            return \%next;
        }
    }
}

# Adds a hash of events (multiple src, dst pairs) to their respective evQueues
sub _addHashToEvQueues
{
    my ($evQueues, $inHash) = @_;
    
    my $lastTime;
    
    # Loop over srchost and dsthost, creating hashes where needed
    while (my ($srchost, $dstHash) = each %$inHash) 
    {
        # Don't auto vivify. Manually create shared hashes
        if (!exists($evQueues->{$srchost}))
        {
            $evQueues->{$srchost} = &share({});
        }
        
        while (my ($dsthost, $evArray) = each %$dstHash) 
        {
            # Don't auto vivify. Manually create shared hashes
            if (!exists($evQueues->{$srchost}{$dsthost}))
            {
                $evQueues->{$srchost}{$dsthost} = &share({});
                my @newArr :shared = ();
                $evQueues->{$srchost}{$dsthost}{'queue'} = \@newArr;
                my $firstTime :shared = 0;
                $evQueues->{$srchost}{$dsthost}{'firstTime'} = $firstTime;
                my $lastTime :shared = 0;
                $evQueues->{$srchost}{$dsthost}{'lastTime'} = $lastTime;
            }
            
            # Once the queue is found or created, add it to the list
            my $evQueue = $evQueues->{$srchost}{$dsthost};
            my $currLast = _addArrayToEvQueue($evQueue, $srchost, $dsthost, $evArray);
            
            # get the min of all the lasttimes from all queues
            if (!defined($lastTime) || 
                (($currLast > 0) && ($lastTime > $currLast)))
            {
                $lastTime = $currLast;
            }
        }    
    }
    
    return $lastTime;
}

# inserts a newly retrieved array into the event queue
# Returns the earliest inserted timestamp
# Note: This inserts padding records if there is a gap between the last entry in the queue and first entry in the array
sub _addArrayToEvQueue
{
    my ($evQueue, $srchost, $dsthost, $evArray) = @_;
    
    return $evQueue->{'lastTime'} if ((scalar(@$evArray) == 0) || ($evArray->[-1]{'endTime'} < $evQueue->{'startTime'}));
    
    # discard duplicate entries from the array based on timestamp
    while ((scalar(@$evArray) > 0) && 
           ($evQueue->{'lastTime'} > $evArray->[0]{'startTime'})) 
    {
        shift(@{$evArray});
    }
    
    # nothing to add
    if (scalar(@$evArray) == 0)
    {
        return $evQueue->{'lastTime'}; 
    }
    
#    my $currTime = time;
#    print $currTime . "\tstart add: $srchost to $dsthost\t" . $evQueue->{'firstTime'} . "-" . $evQueue->{'lastTime'} . "\t";
    
    # pad with unknown value if there is a gap greater than 1 second
    if ((($evArray->[0]{'startTime'} - $evQueue->{'lastTime'}) * 1.0) > 1)
    {
        my %newHash :shared = (  
                'startTime' => $evQueue->{'lastTime'},
                'endTime' => $evArray->[0]{'startTime'},
                'srchost' => $srchost,
                'dsthost' => $dsthost,
                'detectionCode' => -1,
            );
        push(@{$evQueue->{'queue'}}, \%newHash);
    }
    
    # append the entire array to the end of queue
    {
        lock(@{$evQueue->{'queue'}});
        my $sharedArr = shared_clone($evArray); # Make a shared copy of the arrayref so both threads can access it
        push(@{$evQueue->{'queue'}}, @{$sharedArr})
    }
    
    # update variables
    $evQueue->{'firstTime'} = $evQueue->{'queue'}[0]{'startTime'};
    $evQueue->{'lastTime'} = $evQueue->{'queue'}[-1]{'endTime'};
    
#    print " => " . $evQueue->{'firstTime'} . "-" . $evQueue->{'lastTime'} . " delay " . ($currTime - $evQueue->{'lastTime'}) . "\n";
    
    return $evQueue->{'lastTime'};
}

sub max
{
    my ($v1, $v2) = @_;
    
    if ($v1 > $v2)
    {
        return $v1;
    }
    return $v2;
}

sub min
{
    my ($v1, $v2) = @_;
    
    if ($v1 < $v2)
    {
        return $v1;
    }
    return $v2;
}

# compares the overlap of a comparison period versus a reference time
# Returns a value from 0.0 to 1.0, where 1.0 fully overlaps the reference time
sub _calcOverlap
{
    my ($refStart, $refEnd, $cmpStart, $cmpEnd) = @_;
    
    # no overlap. Reject immediately
    if ($cmpEnd < $refStart || $cmpStart > $refEnd)
    {
        return 0.0;
    }
    
    return (min($refEnd, $cmpEnd) - max($refStart, $cmpStart)) * 1.0 / ($refEnd - $refStart);
}

# Calculates the overlap metric for 2 time periods
# not used, since we want it in relation to reference time
sub _calcOverlap2
{
    my ($start1, $end1, $start2, $end2) = @_;
    
    # error check for overlap
    if ($end1 < $start2 || $end2 < $start1)
    {
        return 0.0;
    }
    
    my $numer = min($end1, $end2) - max($start1, $start2);
    my $denom = max($end1, $end2) - min($start1, $start2);
    
    return $numer * 1.0 / $denom;
}

1;