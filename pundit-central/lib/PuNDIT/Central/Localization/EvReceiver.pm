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
use PuNDIT::Central::Localization::EvReceiver::RabbitMQ;
use PuNDIT::Central::Localization::EvReceiver::Test;
use PuNDIT::Central::Localization::EvStore;
use PuNDIT::Utils::Misc qw( calc_bucket_id );

# debug. Remove this for production
use Data::Dumper;

=pod

=head1 PuNDIT::Central::Localization::EvReceiver

This module reads the events from the backend and processes it into a data structure that the Localization object can use.
Starts a receiver thread.

=cut

my $logger = get_logger(__PACKAGE__);
my $runLoop = 1;

$logger->debug("Entered EvReceiver.pm");     ###

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
	my ($self) = @_;

    $logger->debug("Cleaning up EvReceiver");
	
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
        
    my $runtimePeriod = 10; # poll every 10 seconds
    my $processingDelta = 6 * 60; # process X minutes in the past
    my $refTime = calc_bucket_id(time(), $runtimePeriod) - $processingDelta; # Reference time to process
    my $runtimeOffset = 3; # offset each period by 3 seconds
    
    # init the sub-receiver based on the configuration settings
    my $subType = $cfgHash->{'pundit_central'}{$fedName}{'ev_receiver'}{'type'};
    $logger->debug("\$subType=$subType");                                                       ###
    my $subRcv;
    my $evStore; # only used for rabbitmq
    if ($subType eq "mysql")
    {
        $subRcv = new PuNDIT::Central::Localization::EvReceiver::MySQL($cfgHash, $fedName);
    }
    elsif ($subType eq "rabbitmq")
    {
        $subRcv = new PuNDIT::Central::Localization::EvReceiver::RabbitMQ($cfgHash, $fedName);  ###
        $evStore = new PuNDIT::Central::Localization::EvStore($cfgHash, $fedName);              ###
    }
    else # init the test receiver (debug)
    {
        $subRcv = new PuNDIT::Central::Localization::EvReceiver::Test();
    }
    if (!$subRcv) # add error message here
    {
        $logger->error("Couldn't initialize event sub-receiver $subType. Quitting");
        thread_exit(-1);
    }
    
    while ($runLoop)
    {
        $logger->debug("evThread woke, querying events later than $refTime");
        
        # sleep more so the threshold time isn't exceeded
        while (time() < ($refTime + $processingDelta + $runtimeOffset))
        {
            sleep(1);
        }
        
        # Get the events from the sub-receiver after refTime
        my $evHash = $subRcv->getLatestEvents($refTime);
        
        # if evStore is defined, it means we are using it
        if (defined($evStore))
        {
            $evStore->writeEvHashToDb($evHash);
        }
        
        # Add them to the EvQueues for Localisation to use
        _addHashToEvQueues($evQueues, $evHash);
        
        $refTime += $runtimePeriod; # advance the reference time after processing
        # sleep until (reference time + processingDelta + runtimeOffset) time is reached
        my $sleepTime = ($refTime + $processingDelta + $runtimeOffset) - time();       
        
        $logger->debug("evThread sleeping for $sleepTime");
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
    # 1. First entry is later than reftime OR
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
    
    # Case 1: Significant overlap or single entry in queue
    if (($selOverlap >= 0.8) || 
        (scalar(@{$evQueue->{'queue'}}) == 1)) 
    {
        return \%selected;
    }
    # Case 2+: Nonsignificant overlap, >1 entry in queue
    else 
    {
        # Check the next entry's overlap
        my %next = %{$evQueue->{'queue'}[1]}; # we already checked the length of the list before
        
        my $nextOverlap = _calcOverlap($refStart, $refEnd, $next{'startTime'}, $next{'endTime'});
        
        # next overlap is not significant. Stick to selected
        if ($nextOverlap <= 0.2)
        {
            return \%selected;
        }
        
        # selected overlap is not significant. Choose next.
        if ($selOverlap <= 0.2)
        {
            return \%next; # choose the next entry
        }
        
        # Both selected and next are significant. Consider which one to keep or average 
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

# Adds a hash of statuses (multiple src, dst pairs) to their respective evQueues
sub _addHashToEvQueues
{
    my ($evQueues, $inHash) = @_;
    
    # Skip empty hashes
#    return 0 if (%{$inHash});
    
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
    
    # returns the min of all the lastTimes from all queues. 
    # This should ensure that we don't miss entries
    return $lastTime;
}

# inserts a newly retrieved array into the event queue
# Returns the earliest inserted timestamp
# Note: This inserts padding records if there is a gap between the last entry in the queue and first entry in the array
sub _addArrayToEvQueue
{
    my ($evQueue, $srcHost, $dstHost, $evArray) = @_;

#    $logger->debug(sub { Data::Dumper::Dumper($evArray) });

    # Skip the input evArray if:
    # 1. Empty evArray, or
    # 2. Last element in evArray is before the firstTime of this queue
    if ((scalar(@{$evArray}) == 0) || 
        ($evArray->[-1]{'endTime'} < $evQueue->{'firstTime'}))
    {
        return $evQueue->{'lastTime'};
    }
    
    # Loop: discard duplicate entries from the head of evArray based on timestamp
    while ((scalar(@$evArray) > 0) && 
           ($evQueue->{'lastTime'} > $evArray->[0]{'startTime'})) 
    {
        shift(@{$evArray});
    }
    
    # Empty evArray: nothing to add
    if (scalar(@$evArray) == 0)
    {
        return $evQueue->{'lastTime'}; 
    }
    
#    my $currTime = time;
#    print $currTime . "\tstart add: $srcHost to $dstHost\t" . $evQueue->{'firstTime'} . "-" . $evQueue->{'lastTime'} . "\t";
    
    # Pad with unknown value if there is a gap greater than 1 second
    if ((($evArray->[0]{'startTime'} * 1.0) - $evQueue->{'lastTime'}) > 1)
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
    
    # At this point evArray should be completely non-overlapping with evQueue
    # Append the entire evArray to the end of evQueue
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

# return the max of 2 values
sub max
{
    my ($v1, $v2) = @_;
    
    if ($v1 > $v2)
    {
        return $v1;
    }
    return $v2;
}

# return the min of 2 values
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
    
    return ((min($refEnd, $cmpEnd) * 1.0) - max($refStart, $cmpStart)) / ($refEnd - $refStart);
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
