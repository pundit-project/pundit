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
#use PuNDIT::Central::Localization::TrReceiver::ParisTr; # not used right now. Agents will report traceroutes to the MySQL database

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
    my ( $class, $cfgHash, $siteName ) = @_;

    # Shared structure that will hold the trace queues
    my $trQueues = &share({});
    if (!defined($trQueues))
    {
        $logger->error("Couldn't initialize trQueues. Quitting");
        return undef;
    }
    
    # Start the backend-specific receiver thread here
    my $rcvThread = threads->create(sub { run($cfgHash, $siteName, $trQueues); });
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

# Top-level exit for event receiver
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
# $tr_matrix - Hash of Hashes pointing to arrays of traceroutes. Simulates adjacency list
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
    my ($cfgHash, $siteName, $trQueues) = @_;
    
    # Configuration Parameters
    my $sleepTime = 60; # interval between checks, in seconds. Configure this
    my $lastTime = time - 30*60; # check starting from 30 minutes in the past
    
    # init the sub-receiver based on the configuration settings
    my $subType = $cfgHash->{'pundit_central'}{$siteName}{'tr_receiver'}{'type'};
    
    my $trRcv;
    if ( $subType eq "mysql" )
    {
        $trRcv = new PuNDIT::Central::Localization::TrReceiver::MySQL( $cfgHash, $siteName );
    }
    elsif ( $subType eq "paristr" )
    {
#        $trRcv = new PuNDIT::Central::Localization::TrReceiver::ParisTr( $cfgHash, $siteName );
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

# runs the network map update algorithm based on a single path
sub _updateNetworkMapSinglePath
{
    my ($self, $currTs, $srcHost, $dstHost, $currTrace) = @_;
    
    # If is an existing path, remove the old entry
    if ((exists($self->{'_trMatrix'}{$srcHost})) &&
        (exists($self->{'_trMatrix'}{$srcHost}{$dstHost})))
    {
#        print "updateNMapSinglePath: Removing entry with timestamp " . $self->{'_trMatrix'}{$srcHost}{$dstHost}{'ts'} . "\n";
        _remove_tr_entry($srcHost, $dstHost, $self->{'_trMatrix'});
    }
    _insert_tr_entry($srcHost, $dstHost, $currTrace, $self->{'_trMatrix'});
}

# Static method
# removes a traceroute entry from the network map.
sub _remove_tr_entry
{
    my ($srcHost, $dstHost, $tr_matrix) = @_;
    
    if ((!exists($tr_matrix->{$srcHost})) ||
        (!exists($tr_matrix->{$srcHost}{$dstHost})))
    {
         return undef;
    }
    
#    print "remove_tr_entry: removing this trace\n";
#    print Dumper $remove_trace;
        
    delete($tr_matrix->{$srcHost}{$dstHost});
}

# Build tr matrix from a traceroute entry
# Param
# $in_tr_src - Source address
# $in_tr_dst - Destination address
# $in_tr_entry - The traceroute. An array of addresses
# $in_out_tr_matrix - Hash of traceroute paths. May be partially filled
# Returns
# The timestamp of the traceroute, or undef if skipped
sub _insert_tr_entry
{
    my ($in_tr_src, $in_tr_dst, $in_tr_entry, $in_out_tr_matrix) = @_;

#    print "inserting tr...\n";
#    print Dumper $in_tr_entry;

    # skip self traces
    if ($in_tr_src eq $in_tr_entry->{'path'}[0]->getHopId())
    {
        return undef;
    }

    # Add to the tr matrix
    $in_out_tr_matrix->{$in_tr_src}{$in_tr_dst} = $in_tr_entry;

    return $in_tr_entry->{'ts'};
}

1;

