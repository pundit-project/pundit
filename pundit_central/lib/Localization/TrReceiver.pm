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

package Localization::TrReceiver;

use strict;
use threads;
use threads::shared;

# debug
use Data::Dumper;

use Localization::TrReceiver::MySQL;
#use Localization::TrReceiver::ParisTr; # not used right now. Agents will report traceroutes to the MySQL database

=pod

=head1 DESCRIPTION

TrReceiver.pl

This class reads the events from the database and processes it into a data structure that the Processor can use.

=cut

# Top-level init for trace receiver
sub new
{
    my ( $class, $cfgHash, $siteName ) = @_;

    # Shared structure that will hold the trace queues
    my $trQueues = &share({});
    return undef if (!$trQueues);
    
    # Start the backend-specific receiver thread here
    my $rcvThread = threads->create(sub { run($cfgHash, $siteName, $trQueues); });
    return undef if (!$rcvThread);
    
    my $self = {
        '_rcvThr' => $rcvThread,
        '_trQueues' => $trQueues,
        '_netMap' => { 
            'tr_matrix' => {},
            'node_list' => {},
        }, # blank cached network map
    };

    bless $self, $class;
    return $self;
}

# Top-level exit for event receiver
sub DESTROY
{

    # Do nothing?
}

# Public function
# Returns the matrix built from traceroutes
# Parameters:
# $refStart - timestamp of the first traceroute to get. Leave as 0 if you want all
# $refEnd - timestamp of the last traceroute to get. Leave as 0 if you want all
# Returns an array containing:
# $tr_matrix - Hash of Hashes pointing to arrays of traceroutes. Simulates adjacency list
# $node_list - Hash of Nodes to Src/Dst pairs. This is to faciliate reverse lookup from a node to path
sub getTrMatrix
{
    # Get the range from the function call
    my ( $self, $refStart, $refEnd ) = @_;

    $self->_updateNetworkMap($refStart, $refEnd);
    return ($self->{'_netMap'}{'tr_matrix'}, $self->{'_netMap'}{'node_list'});
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
        $trRcv = new Localization::TrReceiver::MySQL( $cfgHash, $siteName );
    }
    elsif ( $subType eq "paristr" )
    {
#        $trRcv = new Localization::TrReceiver::ParisTr( $cfgHash, $siteName );
    }
    # Failsafe if failed to initialise
    if ( !$trRcv )
    {
        print "Warning. Couldn't init traceroute receiver $subType\n";
        thread_exit(-1);
    }
    
    my $runLoop = 1;
    while ($runLoop == 1)
    {
        print "TrRcv thread woke at " . time . " querying for traces later than $lastTime\n";
        # Get the events from the sub-receiver
        my $trHash = $trRcv->getLatestTraces($lastTime);
        
        # Add it to the EvQueues
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
    
    # Loop over srchost and dsthost, creating hashes where needed
    while (my ($srchost, $dstHash) = each %$inHash) 
    {
        # Don't auto vivify. Manually create shared hashes
        if (!exists($trQueues->{$srchost}))
        {
            $trQueues->{$srchost} = &share({});
        }
        
        while (my ($dsthost, $trArray) = each %$dstHash) 
        {
            # Don't auto vivify. Manually create shared hashes
            if (!exists($trQueues->{$srchost}{$dsthost}))
            {
                $trQueues->{$srchost}{$dsthost} = &share({});
                my @newArr :shared = ();
                $trQueues->{$srchost}{$dsthost}{'queue'} = \@newArr;
                my $firstTime :shared = 0;
                $trQueues->{$srchost}{$dsthost}{'firstTime'} = $firstTime;
                my $lastTime :shared = 0;
                $trQueues->{$srchost}{$dsthost}{'lastTime'} = $lastTime;
            }
            
            # Once the queue is found or created, add it to the list
            my $trQueue = $trQueues->{$srchost}{$dsthost};
            my $currLast = _addArrayToTrQueue($trQueue, $srchost, $dsthost, $trArray);
            
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
    my ($trQueue, $srchost, $dsthost, $trArray) = @_;
    
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
#    print $currTime . "\tstart add: $srchost to $dsthost\t" . $trQueue->{'firstTime'} . "-" . $trQueue->{'lastTime'} . "\t";
    
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
    while (my ($srchost, $dstHash) = each %{$trQueues}) 
    {
        while (my ($dsthost, $trArray) = each %$dstHash) 
        {
            # Extract from this queue, returning whether the window changed 
            my $currTrace = _selectNextTrace($trQueues->{$srchost}{$dsthost}, $srchost, $dsthost, $refStart, $refEnd);
            
            # skip this pair if no returned value
            next unless defined($currTrace);
            
            # Update cached network map if current path doesn't exist or head is newer
            if ((!exists($self->{'_netMap'}{'tr_matrix'}{$srchost})) ||
                (!exists($self->{'_netMap'}{'tr_matrix'}{$srchost}{$dsthost})) || 
                ($self->{'_netMap'}{'tr_matrix'}{$srchost}{$dsthost}{'ts'} < $currTrace->{'ts'}))
            {
                $self->_updateNetworkMapSinglePath($currTrace->{'ts'}, $srchost, $dsthost, $currTrace);
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
    my ($trQueue, $srchost, $dsthost, $refStart, $refEnd) = @_;
    
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
    my ($self, $currTs, $srchost, $dsthost, $currTrace) = @_;
    
    # If is an existing path, remove the old entry
    # TODO: Change this to a new version that only removes the difference
    if ((exists($self->{'_netMap'}{'tr_matrix'}{$srchost})) &&
        (exists($self->{'_netMap'}{'tr_matrix'}{$srchost}{$dsthost})))
    {
#        print "updateNMapSinglePath: Removing entry with timestamp " . $self->{'_netMap'}{'tr_matrix'}{$srchost}{$dsthost}{'ts'} . "\n";
        _remove_tr_entry($srchost, $dsthost, $self->{'_netMap'}{'tr_matrix'}, $self->{'_netMap'}{'node_list'});
    }
    _insert_tr_entry($srchost, $dsthost, $currTrace, $self->{'_netMap'}{'tr_matrix'}, $self->{'_netMap'}{'node_list'});
}

# Static method
# removes a traceroute entry from the network map.
sub _remove_tr_entry
{
    my ($srchost, $dsthost, $tr_matrix, $node_list) = @_;
    
    if ((!exists($tr_matrix->{$srchost})) ||
        (!exists($tr_matrix->{$srchost}{$dsthost})))
    {
         return undef;
    }
    
    my $remove_trace = $tr_matrix->{$srchost}{$dsthost};
    
#    print "remove_tr_entry: removing this trace\n";
#    print Dumper $remove_trace;
    
    # loop over each hop number, an array of hops
    foreach my $nodeArray (@{$remove_trace->{'path'}})
    {
#        print Dumper $nodeArray;
        
        # skip stars
        next if ( scalar(@{$nodeArray}) == 1 && $nodeArray->[0]{'hop_name'} eq '*' );
        
        # Generate node_id from all names in array
        my $node_name = _generate_node_name($nodeArray);

        next if (!exists($node_list->{$node_name}));
        
#        print "Removing $srchost $dsthost from $node_name\n";

        my @new_entry = ( $srchost, $dsthost );
        my $maxIdx = scalar(@{$node_list->{$node_name}}) - 1;
        my @del_list = grep {@{$node_list->{$node_name}[$_]} eq @new_entry} 0..$maxIdx;
#        print Dumper \@del_list;
        foreach my $idx (reverse(@del_list)) # Reverse the list to avoid index renumbering  
        {
            splice( @{ $node_list->{$node_name} }, $idx, 1); # delete one at $idx
        }
    }
}

# Build tr matrix from a traceroute entry
# Param
# $in_tr_src - Source address
# $in_tr_dst - Destination address
# $in_tr_entry - The traceroute. An array of addresses
# $in_out_tr_matrix - Hash of traceroute paths. May be partially filled
# $in_out_node_list - Hash of Node to Src/Dst pairs. For Reverse lookup later. May be partially-filled
# Returns
# The timestamp of the traceroute, or undef if skipped
sub _insert_tr_entry
{
    my ( $in_tr_src, $in_tr_dst, $in_tr_entry, $in_out_tr_matrix, $in_out_node_list ) = @_;

#    print "inserting tr...\n";
#    print Dumper $in_tr_entry;

    # skip self traces
    if ((scalar(@{$in_tr_entry->{'path'}}) == 1) &&
        ($in_tr_src eq $in_tr_entry->{'path'}[0][0]{'hop_name'}) )
    {
        return undef;
    }

    # Add to the tr matrix
    $in_out_tr_matrix->{$in_tr_src}{$in_tr_dst} = $in_tr_entry;

    # Add the source node to the node list
    if ( !exists( $in_out_node_list->{$in_tr_src} ) )
    {
        my @new_array = ();
        $in_out_node_list->{$in_tr_src} = \@new_array;
    }

    # Add the path nodes to the node list
    foreach my $nodeArray (@{$in_tr_entry->{'path'}})
    {
        # skip stars
        next if (scalar(@{$nodeArray}) == 1 && $nodeArray->[0]{'hop_name'} eq '*' );
        
        # Generate node_id from all names in array
        my $node_name = _generate_node_name($nodeArray);
        
#        print "Adding $node with $in_tr_src $in_tr_dst \n";
        if ( !exists( $in_out_node_list->{$node_name} ) )
        {
            my @new_array = ();
            $in_out_node_list->{$node_name} = \@new_array;
        }

        # avoid repeats when inserting
        my @new_entry = ( $in_tr_src, $in_tr_dst );
        unless (grep {@$_ eq @new_entry} @{$in_out_node_list->{$node_name}}) {
            push( @{ $in_out_node_list->{$node_name} }, \@new_entry ); # mapping from node to src/dst pair
        }
    }
    return $in_tr_entry->{'ts'};
}

# generates nodes from all the nodes
sub _generate_node_name
{
    my ($nodeArray) = @_;
    
    # optimisation for 1 node
    if (scalar(@{$nodeArray}) == 1)
    {
        return $nodeArray->[0]{'hop_name'};
    }
    # sort to make sure the order is predictable
    my @nameArray = map { $_->{'hop_name'} } @{$nodeArray}; 
    my @snameArray = sort {lc $a cmp lc $b} @nameArray;
    return join("_", @snameArray); # node name is just a concatenation
}

sub build_node_idx
{
    my ($in_tr_list) = @_;

    my %node_list  = ();
    my %edge_list  = ();
    my @path_list  = ();
    my $node_count = 0;

    foreach my $entry (@$in_tr_list)
    {
        my $tr_list = $entry->{'tr_list'};
        my $src_str = $entry->{'src'};

        # Do mapping to src_id
        if ( !exists( $node_list{$src_str} ) )
        {
            $node_list{$src_str} = $node_count++;
        }
        my $src_id = $node_list{$src_str};

        foreach my $tr_entry (@$tr_list)
        {
            my $i;
            my $path = $tr_entry->{'path'};

            my $count = scalar(@$path);

            for ( $i = 0 ; $i < $count ; $i++ )
            {
                my $node_str = $$path[$i];
                if ( !exists( $node_list{$node_str} ) )
                {
                    $node_list{$node_str} = $node_count++;
                }
            }
        }
    }

    return \%node_list;
}

1;

