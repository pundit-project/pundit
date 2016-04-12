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

package PuNDIT::Central::Localization::EvReceiver;

use strict;
use Log::Log4perl qw(get_logger);
use threads;
use threads::shared;

use PuNDIT::Central::Localization::EvReceiver::MySQL;
use PuNDIT::Central::Localization::EvReceiver::Test;

# debug. Remove this for production
use Data::Dumper;

=pod

=head1 PuNDIT::Central::Localization::EvReceiver

This module reads the events from the backend and processes it into a data structure that the Localization object can use.
Starts a receiver thread.

=cut

my $logger = get_logger(__PACKAGE__);
my $runLoop = 1;

# Top-level init for event receiver
sub new
{
	my ($class, $cfgHash, $fedName) = @_;
    
    # Shared structure that will hold the event queues
    my $evQueues = &share({});
    if (!defined($evQueues))
    {
        $logger->error("Couldn't initialize evQueues. Quitting");
        return undef;
    }
    
    # Start the backend-specific receiver thread here
    my $rcvThread = threads->create(sub { run($cfgHash, $fedName, $evQueues); });
    if (!$rcvThread)
    {
        $logger->error("Couldn't initialize receiver thread. Quitting");
        return undef;
    }
    
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

    $logger->debug("Requested evTable from $refStart to $refEnd");
    
    my $outArrayRef = _getWindowFromQueues($self->{'_evQueues'}, $refStart, $refEnd);
    
#    $logger->debug(sub { Data::Dumper::Dumper($outArrayRef) });
    
    return $outArrayRef;
}

# starts an infinte loop that pulls values out of a location into an internal structure
sub run
{
    my ($cfgHash, $fedName, $evQueues) = @_;
        
    my $sleepTime = 10; # poll every 10 seconds
    my $lastTime = time - 6*60; # fixed timelag of 5 minutes
    
    # init the sub-receiver based on the configuration settings
    my $subType = $cfgHash->{'pundit_central'}{$fedName}{'ev_receiver'}{'type'};
    my $subRcv;
    if ($subType eq "mysql")
    {
        $subRcv = new PuNDIT::Central::Localization::EvReceiver::MySQL($cfgHash, $fedName);
    }
    elsif ($subType eq "rabbitmq")
    {
        $subRcv = 'rabbitmq';
    }
    else # init the test receiver (debug)
    {
        $subRcv = new PuNDIT::Central::Localization::EvReceiver::Test();
    }
    thread_exit(-1) if (!$subRcv);
    
    while ($runLoop)
    {
        $logger->debug("evThread woke");
        
        # Get the events from the sub-receiver after lastTime
        my $evHash = $subRcv->getLatestEvents($lastTime);
        
        # Add them to the EvQueues
        _addHashToEvQueues($evQueues, $evHash);
        
        my $lastTime += $sleepTime;
        
        $logger->debug("evThread sleeping for $sleepTime");
        sleep($sleepTime);
        
        # sleep more so the threshold time isn't exceeded
        while ((time - (5 * 60)) < $lastTime)
        {
            sleep(10);
        }
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
    while (my ($srcHost, $dstHash) = each %{$evQueues}) 
    {
        while (my ($dstHost, $evArray) = each %$dstHash) 
        {
            # Extract from this queue
            my $currWindow = _selectNextWindow($evQueues->{$srcHost}{$dstHost}, $srcHost, $dstHost, $refStart, $refEnd);
    
            if (defined($currWindow))
            {
                # push onto the output array
                push(@outArray, $currWindow);
            }            
        }    
    }
#    $logger->debug(sub { Data::Dumper::Dumper(\@outArray) });
    
    return \@outArray;
    
}

# Selects the window closest to the reference time from an evQueue
# Modifies the queue: If there are any entries earlier than this refernce time, they will be discarded 
# Assumes the queues are packed with no gaps between 2 consecutive windows
sub _selectNextWindow
{
    my ($evQueue, $srcHost, $dstHost, $refStart, $refEnd) = @_;
    
    # discard values at the start which are clearly not suitable
    # 1. Endtimes that are before the requested reference start time
    while ((scalar(@{$evQueue->{'queue'}}) > 0) && 
           ($evQueue->{'queue'}[0]->{'endTime'} < $refStart))
    {
        {
#            $logger->debug("discarding event at " . $evQueue->{'queue'}[0]{'startTime'});
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
            'srcHost' => $srcHost,
            'dstHost' => $dstHost,
            'detectionCode' => -1,
        }
    }
    
    # Now compare the queue head with the reftime
    my %selected = %{$evQueue->{'queue'}[0]};
#    $logger->debug(sub { Data::Dumper::Dumper(\%selected) });
    my $selOverlap = _calcOverlap($refStart, $refEnd, $selected{'startTime'}, $selected{'endTime'});
    
#    $logger->debug("selOverlap is $selOverlap");
    
    # Case 1: Significant overlap
    if (($selOverlap >= 0.8) || 
        (scalar(@{$evQueue->{'queue'}}) == 1)) 
    {
        return \%selected;
    }
    # Case 2+: Nonsignificant overlap
    else 
    {
        # Check the next entry's overlap
        my %next = %{$evQueue->{'queue'}[1]}; # we already checked the length of the list before
        
        my $nextOverlap = _calcOverlap($refStart, $refEnd, $next{'startTime'}, $next{'endTime'});
        
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
                $logger->debug("Selecting next entry at " . $next{'startTime'} . " over " . $selected{'startTime'});
                return \%next; # choose the next entry
            }
            else
            {
                $logger->debug("Selecting entry at " . $selected{'startTime'} . " over " . $next{'startTime'});
                return \%selected; 
            }
        }
        
        # Case 3: Both have problems, return the average of both
        if ($selected{'detectionCode'} > 0)
        {
            $logger->debug("Averaging entries at " . $selected{'startTime'} . " and " . $next{'startTime'});
            
            # average it here in this block
            my $avg = {
                'startTime' => $selected{'startTime'},
                'endTime' => $next{'endTime'},
                'srcHost' => $selected{'srcHost'},
                'dstHost' => $selected{'dstHost'},
                'detectionCode' => $selected{'detectionCode'} || $next{'detectionCode'},
            };
            
            # Do a simple averaging here
            foreach my $key (keys(%selected))
            {
                # skip these fields
                if ($key eq 'startTime' || 
                    $key eq 'endTime' || 
                    $key eq 'srcHost' ||
                    $key eq 'dstHost' ||
                    $key eq 'detectionCode')
                {
                    next;
                }
                # average the rest and store it in the new hash
                $avg->{$key} = ($selected{$key} + $next{$key}) / 2; 
            }
            return $avg;
        }
        # Case 4: First window doesn't have problems, next does. Prefer the problematic one
        else
        {
            $logger->debug("Selecting next entry 2 at " . $next{'startTime'} . " over " . $selected{'startTime'});
            return \%next;
        }
    }
}

# Adds a hash of events (multiple src, dst pairs) to their respective evQueues
sub _addHashToEvQueues
{
    my ($evQueues, $inHash) = @_;
    
    my $lastTime;
    
    # Loop over srcHost and dstHost, creating hashes where needed
    while (my ($srcHost, $dstHash) = each %$inHash) 
    {
        # Don't auto vivify. Manually create shared hashes
        if (!exists($evQueues->{$srcHost}))
        {
            $evQueues->{$srcHost} = &share({});
        }
        
        while (my ($dstHost, $evArray) = each %$dstHash) 
        {
            # Don't auto vivify. Manually create shared hashes
            if (!exists($evQueues->{$srcHost}{$dstHost}))
            {
                $evQueues->{$srcHost}{$dstHost} = &share({});
                my @newArr :shared = ();
                $evQueues->{$srcHost}{$dstHost}{'queue'} = \@newArr;
                my $firstTime :shared = 0;
                $evQueues->{$srcHost}{$dstHost}{'firstTime'} = $firstTime;
                my $lastTime :shared = 0;
                $evQueues->{$srcHost}{$dstHost}{'lastTime'} = $lastTime;
            }
            
            # Once the queue is found or created, add it to the list
            my $evQueue = $evQueues->{$srcHost}{$dstHost};
            my $currLast = _addArrayToEvQueue($evQueue, $srcHost, $dstHost, $evArray);
            
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
    my ($evQueue, $srcHost, $dstHost, $evArray) = @_;

#    $logger->debug(sub { Data::Dumper::Dumper($evArray) });    
    if ((scalar(@{$evArray}) == 0) || ($evArray->[-1]{'endTime'} < $evQueue->{'firstTime'}))
    {
        return $evQueue->{'lastTime'};
    }
    
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
#    print $currTime . "\tstart add: $srcHost to $dstHost\t" . $evQueue->{'firstTime'} . "-" . $evQueue->{'lastTime'} . "\t";
    
    # pad with unknown value if there is a gap greater than 1 second
    if ((($evArray->[0]{'startTime'} - $evQueue->{'lastTime'}) * 1.0) > 1)
    {
        my %newHash :shared = (  
                'startTime' => $evQueue->{'lastTime'},
                'endTime' => $evArray->[0]{'startTime'},
                'srcHost' => $srcHost,
                'dstHost' => $dstHost,
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
    if ($cmpEnd <= $refStart || $cmpStart >= $refEnd)
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
    if ($end1 <= $start2 || $end2 <= $start1)
    {
        return 0.0;
    }
    
    my $numer = min($end1, $end2) - max($start1, $start2);
    my $denom = max($end1, $end2) - min($start1, $start2);
    
    return $numer * 1.0 / $denom;
}

1;