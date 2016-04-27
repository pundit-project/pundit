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

package PuNDIT::Central::Localization::TrReceiver;

use strict;
use Log::Log4perl qw(get_logger);
use threads;
use threads::shared;

# debug
use Data::Dumper;

use PuNDIT::Central::Localization::TrReceiver::MySQL;
use PuNDIT::Central::Localization::TrStore;
#use PuNDIT::Central::Localization::TrReceiver::ParisTr; # not used right now. Agents will report traceroutes to the MySQL database
use PuNDIT::Utils::TrHop;

=pod

=head1 PuNDIT::Central::Localization::TrReceiver

This class reads the events from the database and processes it into a data structure that the Localization object can use.
Starts a traceroute receiver thread.

=cut

my $logger = get_logger(__PACKAGE__);
my $runLoop = 1;

# Top-level init for trace receiver
sub new
{
    my ( $class, $cfgHash, $fedName ) = @_;

    # Shared structure that will hold the trace queues
    my $trQueues = &share({});
    if (!defined($trQueues))
    {
        $logger->error("Couldn't initialize trQueues. Quitting");
        return undef;
    }
    
    # Start the backend-specific receiver thread here
    my $rcvThread = threads->create(sub { run($cfgHash, $fedName, $trQueues); });
    if (!$rcvThread)
    {
        $logger->error("Couldn't initialize tr revThread. Quitting");
        return undef;
    }
    
    my $self = {
        '_rcvThr' => $rcvThread,
        '_trQueues' => $trQueues,
        '_trMatrix' => {}, # cached tr matrix
    };

    bless $self, $class;
    return $self;
}

# Top-level exit for trace receiver
sub DESTROY
{
    my ($self) = @_;
    
    $logger->debug("Cleaning up TrReceiver");
    
    $runLoop = 0;
    $self->{'_rcvThr'}->join();
}

# Public function
# Returns the matrix built from traceroutes
# Parameters:
# $refStart - timestamp of the first traceroute to get. Leave as 0 if you want all
# $refEnd - timestamp of the last traceroute to get. Leave as 0 if you want all
# Returns an array containing:
# $trMatrix - Hash of Hashes pointing to arrays of traceroutes. Simulates adjacency list
sub getTrMatrix
{
    # Get the range from the function call
    my ( $self, $refStart, $refEnd ) = @_;

    $self->_updateNetworkMap($refStart, $refEnd);
    
    return ($self->{'_trMatrix'});
}

# starts an infinte loop that pulls values out of the receiver into an internal structure
sub run
{
    my ($cfgHash, $fedName, $trQueues) = @_;
    
    # Configuration Parameters
    my $sleepTime = 60; # interval between checks, in seconds. Configure this
    my $lastTime = time - 30*60; # check starting from 30 minutes in the past
    
    # init the sub-receiver based on the configuration settings
    my $subType = $cfgHash->{'pundit_central'}{$fedName}{'tr_receiver'}{'type'};
    
    my $trRcv;
    my $trStore; # Used only for rabbitmq and traceroutema to write back results to mysql
    if ( $subType eq "mysql" )
    {
        $trRcv = new PuNDIT::Central::Localization::TrReceiver::MySQL( $cfgHash, $fedName );
    }
    elsif ( $subType eq "paristr" )
    {
#        $trRcv = new PuNDIT::Central::Localization::TrReceiver::ParisTr( $cfgHash, $fedName );
    }
    elsif ( $subType eq "rabbitmq" )
    {
#        $trRcv = new PuNDIT::Central::Localization::TrReceiver::RabbitMQ( $cfgHash, $fedName );        
        $trStore = new PuNDIT::Central::Localization::TrStore( $cfgHash, $fedName );
    }
    # Failsafe if failed to initialise
    if ( !$trRcv )
    {
        $logger->error("Couldn't init traceroute receiver $subType");
        thread_exit(-1);
    }
    
    while ($runLoop == 1)
    {
        $logger->debug("TrRcv thread woke. Querying for traces later than $lastTime");
        
        # Get the events from the sub-receiver
        my $trHash = $trRcv->getLatestTraces($lastTime);
        
        # if trStore is defined, it means we are using it
        if (defined($trStore))
        {
            $trStore->writeTrHashToDb($trHash);
        }
        
        # Add it to the TrQueues
        _addHashToTrQueues($trQueues, $trHash);
        
        $lastTime += $sleepTime;
        sleep($sleepTime);
        
        # sleep more so the threshold time isn't exceeded
        while ((time - (15 * 60)) < $lastTime)
        {
            sleep(10);
        }
    }
}

# Adds a hash of traces (multiple src, dst pairs) to their respective trQueues
sub _addHashToTrQueues
{
    my ($trQueues, $inHash) = @_;
    
    my $lastTime;
    
    # Loop over srcHost and dstHost, creating hashes where needed
    while (my ($srcHost, $dstHash) = each %$inHash) 
    {
        # Don't auto vivify. Manually create shared hashes
        if (!exists($trQueues->{$srcHost}))
        {
            $trQueues->{$srcHost} = &share({});
        }
        
        while (my ($dstHost, $trArray) = each %$dstHash) 
        {
            # Don't auto vivify. Manually create shared hashes
            if (!exists($trQueues->{$srcHost}{$dstHost}))
            {
                $trQueues->{$srcHost}{$dstHost} = &share({});
                my @newArr :shared = ();
                $trQueues->{$srcHost}{$dstHost}{'queue'} = \@newArr;
                my $firstTime :shared = 0;
                $trQueues->{$srcHost}{$dstHost}{'firstTime'} = $firstTime;
                my $lastTime :shared = 0;
                $trQueues->{$srcHost}{$dstHost}{'lastTime'} = $lastTime;
            }
            
            # Once the queue is found or created, add it to the list
            my $trQueue = $trQueues->{$srcHost}{$dstHost};
            my $currLast = _addArrayToTrQueue($trQueue, $srcHost, $dstHost, $trArray);
            
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

# inserts a newly retrieved array into the traceroute queue
# Returns the earliest inserted timestamp
# There is no padding with unknown values, traceroutes don't need it
sub _addArrayToTrQueue
{
    my ($trQueue, $srcHost, $dstHost, $trArray) = @_;
    
    # skip if the entries already exist in the current trQueue
    if ((scalar(@$trArray) == 0) || ($trArray->[-1]{'ts'} <= $trQueue->{'lastTime'}))
    {
#        print "Already exists. Skipping\n";
        return $trQueue->{'lastTime'}; 
    }
    
    # discard duplicate entries from the array based on timestamp
    while ((scalar(@$trArray) > 0) && 
           ($trQueue->{'lastTime'} >= $trArray->[0]{'ts'})) 
    {
#        print "AddArray: Discarding tr with timestamp " . $trArray->[0]{'ts'} . "\n";
        shift(@{$trArray});
    }
    
    # nothing to add
    if (scalar(@$trArray) == 0)
    {
#        print "Nothing to add.\n";
        return $trQueue->{'lastTime'}; 
    }
    
#    my $currTime = time;
#    print $currTime . "\tstart add: $srcHost to $dstHost\t" . $trQueue->{'firstTime'} . "-" . $trQueue->{'lastTime'} . "\t";
    
    # append the entire array to the end of queue
    {
        lock(@{$trQueue->{'queue'}});
        my $sharedArr = shared_clone($trArray); # Make a shared copy of the arrayref so both threads can access it
        push(@{$trQueue->{'queue'}}, @{$sharedArr})
    }
    
    # update variables
    $trQueue->{'firstTime'} = $trQueue->{'queue'}[0]{'ts'};
    $trQueue->{'lastTime'} = $trQueue->{'queue'}[-1]{'ts'};
    
#    print " => " . $trQueue->{'firstTime'} . "-" . $trQueue->{'lastTime'} . " delay " . ($currTime - $trQueue->{'lastTime'}) . "\n";
    
    return $trQueue->{'lastTime'};
}


# Loops over the Trace Queues and finds whether the network map has changed or not
sub _updateNetworkMap
{
    my ($self, $refStart, $refEnd) = @_;
    
    my $trQueues = $self->{'_trQueues'};
    
    # Sanity check that trQueues has been populated before continuing
    return 0 if (!%{$trQueues});
    
    # Loop over the trQueue entries 
    my $changedCount = 0;
    while (my ($srcHost, $dstHash) = each %{$trQueues}) 
    {
        while (my ($dstHost, $trArray) = each %$dstHash) 
        {
            # Extract from this queue, returning whether the window changed 
            my $currTrace = _selectNextTrace($trQueues->{$srcHost}{$dstHost}, $srcHost, $dstHost, $refStart, $refEnd);
            
#            $logger->debug(sub { Data::Dumper::Dumper($currTrace) });
            
            # skip this pair if no returned value
            next unless defined($currTrace);
            
            # Update cached network map if current path doesn't exist or head is newer
            if ((!exists($self->{'_trMatrix'}{$srcHost})) ||
                (!exists($self->{'_trMatrix'}{$srcHost}{$dstHost})) || 
                ($self->{'_trMatrix'}{$srcHost}{$dstHost}{'ts'} < $currTrace->{'ts'}))
            {
                $self->_updateNetworkMapSinglePath($currTrace->{'ts'}, $srcHost, $dstHost, $currTrace);
                $changedCount += 1;
            }  
        }    
    }
    return $changedCount;
}

# Selects the trace closest to the reference time from an trQueue
# Modifies the queue: If there are any entries earlier than this refernce time, they will be discarded 
# Assumes the queues are packed with no gaps between 2 consecutive windows
sub _selectNextTrace
{
    my ($trQueue, $srcHost, $dstHost, $refStart, $refEnd) = @_;
    
    # discard values at the start which are out of date
    # 1. when the next entry is before the reference time
    while ((scalar(@{$trQueue->{'queue'}}) > 1) && 
           ($trQueue->{'queue'}[1]{'ts'} < $refEnd))
    {
        # these curly braces limit the scope of the lock
        {
#            print "discarding trace at " . $trQueue->{'queue'}[0]{'ts'} . " vs " . $trQueue->{'queue'}[1]{'ts'} . "\n";
            lock(@{$trQueue->{'queue'}});
            shift(@{$trQueue->{'queue'}});
        }
        
        # update firstTime after removing
        # We do this inside the loop so we keep the firstTime updated even if the queue is empty
        if (scalar(@{$trQueue->{'queue'}}) > 0)
        {
            $trQueue->{'firstTime'} = $trQueue->{'queue'}[0]{'ts'};
        }
    }
    
#    print "using trace at " . $trQueue->{'queue'}[0]{'ts'} . "\n";
    
    # Return empty if
    # 1. First entry is far ahead of reftime OR
    # 2. Empty queue
    if (($trQueue->{'firstTime'} > $refEnd) || 
        (scalar(@{$trQueue->{'queue'}}) == 0))
    {
        return undef;
    }
    return $trQueue->{'queue'}[0];
}

# Replaces all stars with virtual interfaces that represent possible nodes
# Also collapses loops, and if the loop is in the last N entries, will replace it with a star
# this makes a copy of the trace, which is also an unshared verson 
sub _replaceStarsAndLoopsInTrace
{
    my ($trOriginal) = @_;
    
    # output array
    my $trProcessed = {
        'ts' => $trOriginal->{'ts'},
        'path' => [],   
        'src' => $trOriginal->{'src'},
        'dst' => $trOriginal->{'dst'},
    };
    
    my $lastNonStarHop;
    my $lastStar = 0;
    my $lastLoop = 0;
    foreach my $trHop (@{$trOriginal->{'path'}})
    {
        my $currHopId = $trHop->getHopId(); 
        if ($currHopId ne '*')
        {
            # check whether it's a loop or not
            if (defined($lastNonStarHop) && $lastNonStarHop ne $currHopId)
            {
                if ($lastStar) # was preceded by a star
                {
                    my $virtualNode = new PuNDIT::Utils::TrHop($lastNonStarHop . "|*|" . $currHopId, "123");
                    push @{$trProcessed->{'path'}}, $virtualNode;
                    $lastStar = 0;
                }
                push @{$trProcessed->{'path'}}, $trHop->clone();
                $lastLoop = 0;
            }
            else # duplicate hop detected
            {
                $lastLoop = 1;
            }
            $lastNonStarHop = $currHopId; 
        }
        else # this is a star
        {
            $lastStar = 1;
        }
    }
    # last hop. Check whether it reached the destination
    if ($trProcessed->{'path'}[-1]->getHopId() ne $trOriginal->{'dst'})
    {
        # stars and loops don't reveal the last few hops before the destination, so insert 
        if ($lastStar || $lastLoop)
        {
            my $virtualNode = new PuNDIT::Utils::TrHop($lastNonStarHop . "|*|" . $trOriginal->{'dst'}, "123");
            push @{$trProcessed->{'path'}}, $virtualNode;
        }
        my $lastNode = new PuNDIT::Utils::TrHop($trOriginal->{'dst'}, "123");
        push @{$trProcessed->{'path'}}, $lastNode;
    }
    
#    $logger->debug(sub { Data::Dumper::Dumper($trProcessed) });
    
    return $trProcessed;
}

# runs the network map update algorithm based on a single path
sub _updateNetworkMapSinglePath
{
    my ($self, $currTs, $srcHost, $dstHost, $currTrace) = @_;
    
    # If is an existing path, remove the old entry
    if ((exists($self->{'_trMatrix'}{$srcHost})) &&
        (exists($self->{'_trMatrix'}{$srcHost}{$dstHost})))
    {
#        print "updateNMapSinglePath: Removing entry with timestamp " . $self->{'_trMatrix'}{$srcHost}{$dstHost}{'ts'} . "\n";
        _removeTrEntryFromMatrix($srcHost, $dstHost, $self->{'_trMatrix'});
    }

    _insertTrEntryToMatrix($srcHost, $dstHost, $currTrace, $self->{'_trMatrix'});
}

# Static method
# removes a traceroute entry from the network map.
sub _removeTrEntryFromMatrix
{
    my ($srcHost, $dstHost, $trMatrix) = @_;
    
    if ((!exists($trMatrix->{$srcHost})) ||
        (!exists($trMatrix->{$srcHost}{$dstHost})))
    {
         return undef;
    }
    
#    print "remove_tr_entry: removing this trace\n";
#    print Dumper $remove_trace;
        
    delete($trMatrix->{$srcHost}{$dstHost});
}

# Build tr matrix from a traceroute entry
# Param
# $inTrSrc - Source address
# $inTrDst - Destination address
# $inTrEntry - The traceroute. An array of addresses
# $trMatrix - Hash of traceroute paths. May be partially filled
# Returns
# The timestamp of the traceroute, or undef if skipped
sub _insertTrEntryToMatrix
{
    my ($inTrSrc, $inTrDst, $inTrEntry, $trMatrix) = @_;

#    print "inserting tr...\n";
#    print Dumper $inTrEntry;

    # skip self traces
    if ($inTrSrc eq $inTrEntry->{'path'}[0]->getHopId())
    {
        return undef;
    }

    # clean stars from the new trace
    # Add to the tr matrix
    $trMatrix->{$inTrSrc}{$inTrDst} = _replaceStarsAndLoopsInTrace($inTrEntry);

    return $inTrEntry->{'ts'};
}

# writes this back to database
sub _writeBackToDb
{
    my ($self, $inTr) = @_;
    
    return $self->{'_trStore'}->writeTrToDb($inTr);
}

1;

