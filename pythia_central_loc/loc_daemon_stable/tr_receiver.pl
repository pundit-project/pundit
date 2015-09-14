#!/usr/bin/perl
#
# Copyright 2012 Georgia Institute of Technology
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

package Loc::TrReceiver;

use strict;

require "tr_receiver_mysql.pl";
require "tr_receiver_paristr.pl";

=pod

=head1 DESCRIPTION

tr_receiver.pl

This script reads the events from the database and processes it into a data structure that the loc_processor can use.

=cut

# Top-level init for trace receiver
sub new
{
    my $class = shift;
    my $cfg = shift;
    
    # init the sub-receiver (mysql)
    my $tr_rcv;
    my $rcv_type = $cfg->get_param("tr_receiver", "subtype");
    if ($rcv_type eq "mysql")
    {
        $tr_rcv = new Loc::TrReceiver::Mysql($cfg);    
    }
    elsif ($rcv_type eq "paristr")
    {
        $tr_rcv = new Loc::TrReceiver::Paristr($cfg);
    }
    if (!$tr_rcv)
    {
        print "Warning. Couldn't init traceroute receiver $rcv_type\n";
        return undef;
    }
    
    my $tr_freq = $cfg->get_param("traceroute", "tr_frequency");
    
    my $self = {
        _config => $cfg,
        _rcv => $tr_rcv,
        _last_tr_ts => undef,
        _first_tr_ts => undef,
        _tr_matrix => undef,
        _tr_freq => $tr_freq,
        _node_list  => undef,
    };
    
    bless $self, $class;
    return $self;
}

# Top-level exit for event receiver
sub DESTROY
{
    # Do nothing?
}

# Returns the matrix built from traceroutes
# Parameters: 
# $in_first_tr_ts - timestamp of the first traceroute to get. Leave as 0 if you want all
# $in_last_tr_ts - timestamp of the last traceroute to get. Leave as 0 if you want all
# Returns an array containing:
# $out_first_tr_ts - timestamp of the returned first traceroute
# $out_last_tr_ts - timestamp of the returned last traceroute
# $out_tr_matrix - Hash of Hashes pointing to arrays of traceroutes. Simulates adjacency list
# $out_node_list - Hash of Nodes to Src/Dst pairs. This is to faciliate reverse lookup from a node to path
sub get_tr_matrix
{
	# Get the range from the function call
	my ($self, $in_first_tr_ts, $in_last_tr_ts) = @_;
	
	# this is for live requests. Use cached matrices if possible
	if ($in_first_tr_ts == 0 && $in_last_tr_ts == 0)
	{
	    # if either not set or out of date, update the cached version
        if (!{$self->{'_tr_matrix'}} || ((time() - $self->{'_first_tr_ts'}) > $self->{'tr_freq'}))
        {
            ($self->{'_first_tr_ts'}, $self->{'_last_tr_ts'}, $self->{'_tr_matrix'}, $self->{'_node_list'}) = $self->build_tr_matrix();
        }
        return ($self->{'_first_tr_ts'}, $self->{'_last_tr_ts'}, $self->{'_tr_matrix'}, $self->{'_node_list'});
	}
	
	# else make a request with the provided timestamps (not enabled yet)
	return ($self->{'_first_tr_ts'}, $self->{'_last_tr_ts'}, $self->{'_tr_matrix'}, $self->{'_node_list'});
}

# Generates the tr matrix based on the last X seconds
sub build_tr_matrix
{
    my ($self) = @_;
    
    my $tr_list = $self->get_tr_list();
       
    # Build the structs from the traceroutes
    my ($out_first_tr_ts, $out_last_tr_ts, $out_tr_matrix, $out_node_list) = process_tr_all($tr_list);  
    
    return ($out_first_tr_ts, $out_last_tr_ts, $out_tr_matrix, $out_node_list);
}

# Builds tr matrix from entire tr list
# Calls process_tr_host
# Params:
# $in_tr_tree - Array of hashes containing mapping of src address and traceroute list for that host
# Returns:
# $out_tr_matrix - Hash of traceroute paths {src}{dest}
# $out_node_list - Hash of node to src/dst pairs. For reverse lookup
sub process_tr_all
{
	my ($in_tr_tree) = @_;
	
	# init the new hashes
	my %out_tr_matrix = ();
	my %out_node_list = ();
	my $first_ts;
	my $last_ts;
	
	foreach (@$in_tr_tree)
	{
		my ($first_tr_ts, $last_tr_ts) = process_tr_host($_->{'src'}, $_->{'tr_list'}, \%out_tr_matrix, \%out_node_list);
		
		# Skip if undefined
		next if (!$first_tr_ts || !$last_tr_ts);
		$first_ts = $first_tr_ts if (!$first_ts || ($first_ts > $first_tr_ts));
		$last_ts = $last_tr_ts if (!$last_ts || ($last_ts < $last_tr_ts));
	}
	return ($first_ts, $last_ts, \%out_tr_matrix, \%out_node_list);
}

# Builds tr matrix from all tr entries for a single host
# Calls process_tr_entry
# Params
# $in_tr_src - Source address. 
# $in_tr_list - Traceroute info. Array of arrays that hold the addresses
# $in_out_tr_matrix - Hash of traceroute paths. May be partially filled
# $in_out_node_list - Hash of Node to Src/Dst pairs. For Reverse lookup later. May be partially-filled 
# Returns
# ($first_ts, $last_ts) - Pair of timestamps of the first/last traceroute
sub process_tr_host
{
	my ($in_tr_src, $in_tr_list, $in_out_tr_matrix, $in_out_node_list) = @_;
	my $first_ts;
	my $last_ts;
	
	# Process each traceroute path using the helper function
	foreach (@$in_tr_list)
	{
		#print "calling process with src $in_tr_src and dst $_->{'path'}[-1]\n";
		my $ts = process_tr_entry($in_tr_src, $_, $in_out_tr_matrix, $in_out_node_list);
		
		# Skip to the next entry if TS not valid
		next if (!$ts);
		
		# Update the timestamps
		$first_ts = $ts if ((!$first_ts) || ($ts < $first_ts));
		$last_ts = $ts if ((!$last_ts) || ($ts > $last_ts));	
	}
	return ($first_ts, $last_ts);
}

# Build tr matrix from a traceroute entry
# Param
# $in_tr_src - Source address
# $in_tr_entry - The traceroute. An array of addresses
# $in_out_tr_matrix - Hash of traceroute paths. May be partially filled
# $in_out_node_list - Hash of Node to Src/Dst pairs. For Reverse lookup later. May be partially-filled
# Returns
# The timestamp of the traceroute, or undef if skipped
sub process_tr_entry
{
	my ($in_tr_src, $in_tr_entry, $in_out_tr_matrix, $in_out_node_list) = @_;
	my $new_tr_entry = $in_tr_entry->{'path'};
	
	#print Dumper $new_tr_entry;
	
	# skip self traces
	if ($in_tr_src eq $$new_tr_entry[0])
	{
		return undef;
	}
	
	# Add to the tr matrix
	$in_out_tr_matrix->{$in_tr_src}->{$in_tr_entry->{'dst'}} = $new_tr_entry;
	
	# Add the source node to the node list
	if (!exists($in_out_node_list->{$in_tr_src}))
	{
		my @new_array = ();
		$in_out_node_list->{$in_tr_src} = \@new_array;
	}
=pod
	my @new_entry = ($in_tr_src, $new_tr_entry[-1]);
	say "Src: $in_tr_src adding";
	print Dumper \@new_entry;
	push ($in_out_node_list->{$in_tr_src}, \@new_entry);
=cut	
	# Add the path nodes to the node list
	foreach my $node (@$new_tr_entry)
	{
	    next if ($node eq '*');
		my @new_entry = ($in_tr_src, $in_tr_entry->{'dst'});
		print "Adding $node with $in_tr_src $in_tr_entry->{'dst'} \n";
		if (!exists($in_out_node_list->{$node}))
		{
			my @new_array = ();
			$in_out_node_list->{$node} = \@new_array;
		}

		# We assume we don't have repeats, otherwise check here before pushing
		push(@{$in_out_node_list->{$node}}, \@new_entry);
	}
	return $in_tr_entry->{'ts'};
}

sub build_node_idx
{
	my ($in_tr_list) = @_;
	
	my %node_list = ();
	my %edge_list = ();
	my @path_list = ();
	my $node_count = 0;
	
	foreach my $entry (@$in_tr_list)
	{
		my $tr_list = $entry->{'tr_list'};
		my $src_str = $entry->{'src'};
		
		# Do mapping to src_id
		if (!exists($node_list{$src_str}))
		{
			$node_list{$src_str} = $node_count++;
		}
		my $src_id = $node_list{$src_str};
				
		foreach my $tr_entry (@$tr_list)
		{
			my $i;
			my $path = $tr_entry->{'path'};
			
			my $count = scalar(@$path);
						
			for ($i = 0; $i < $count; $i++)
			{
				my $node_str = $$path[$i];
				if (!exists($node_list{$node_str}))
				{
					$node_list{$node_str} = $node_count++;
				}
			}
		}
	}
	
	return \%node_list;
}

# retrieves the tr_list from the tr_receiver
sub get_tr_list
{
    my ($self) = @_;

    return $self->{'_rcv'}->get_tr_hosts_all();
}

=pod
CREATE TABLE loc_graph_nodes
(
	host varchar(255) NOT NULL,
	id int,
	PRIMARY KEY (id)
);

CREATE TABLE loc_graph_edges
(
	src_id int,
	dst_id int
);

CREATE TABLE loc_graph_paths
(
	node_id int,
	src_id int,
	dst_id int
);
=cut

1;

