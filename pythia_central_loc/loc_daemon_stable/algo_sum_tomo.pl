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

package Loc::Tomo::Range::Sum;

use strict;

#use Clone qw(clone);

# debug
#use Data::Dumper;

=pod

=head1 DESCRIPTION

This is the implementation of the sum_tomo algorithm
The inputs to this algorithm are the traceroute matrix, traceroute node list and event list
It returns a hash of suspect node to range mappings 

=cut


## FUNCTIONS

sub new
{
	my $class = shift;
    my $cfg = shift;
    
	my $alpha = $cfg->get_param('range_tomo', 'alpha');
	if (!$alpha)
	{
		$alpha = 0.5;
		print "Warning: config file doesn't specify range_tomo:alpha value. Using default of $alpha\n";	
	}
	
	my $self = {
        _config => $cfg,
        _alpha => $alpha,
    };
    
    bless $self, $class;
    return $self;
}

# Builds a set of all paths from the traceroute table
# Params:
# $tr_table - Reference to the TraceRoute table, an array of hashes
# Returns:
# %path_set - A hash of hashes %path_set{$src}{$dst} = bad/good value
# The convention is 0 - good, 1 - bad
sub build_path_set
{
	my ($tr_table) = @_;
	
	my %path_set = ();
	
	while (my ($src, $dest_details) = each(%$tr_table))
	{
		while (my ($dst, $path) = each(%$dest_details))
		{
			# Skip host-only tr
			if (($src eq @$path[0]))
			{
				next;
			}
			
			# mark it as good
			$path_set{$src}{$dst} = 0;
		}
	}

	return (\%path_set);
}

# Builds the hash of links from the node set
# Params:
# $tr_node_set - Reference to the node set. A hash of link to endpoint mappings
# Returns:
# %link_set - A flat hash of all %link_set{$node} = bad/good value
# The convention is 0 - good, 1 - bad
sub build_link_set
{
	my ($tr_node_set) = @_;
	
	my %link_set = ();
	
	while (my ($node, $paths) = each(%$tr_node_set))
	{
		$link_set{$node} = 0;
	}
	
	return (\%link_set);
}

# Removes all good paths and links from the set of paths and links
# Params:
# $ev_table - The event table
# $tr_matrix - The traceroute matrix
# $path_set - The set of paths. This will be changed
# $link_set - The set of links. This will be changed
# Returns:
# $path_set_count - The count of bad paths
# $link_set_count - The count of bad links
sub remove_good_paths_links
{
	my ($ev_table, $tr_matrix, $path_set, $link_set) = @_;
	my $path_set_count = 0;
	my $link_set_count = 0;
	
	my @new_ev_table = ();
	
	# loop over ev table, marking paths as bad
	foreach my $event (@$ev_table)
	{
		if (exists($tr_matrix->{$event->{'srchost'}}->{$event->{'dsthost'}}))
		{
			# Mark path as bad
			if ($path_set->{$event->{'srchost'}}->{$event->{'dsthost'}} == 0)
			{
				$path_set->{$event->{'srchost'}}->{$event->{'dsthost'}} = 1;
				$path_set_count++;
			}
			
			# Loop over links in path, marking them as bad
			my $pathref = $tr_matrix->{$event->{'srchost'}}->{$event->{'dsthost'}};
			foreach my $link (@$pathref)
			{
				if ($link_set->{$link} == 0)
				{
					$link_set->{$link} = 1;
					$link_set_count++;
				}
			}
			
			push (@new_ev_table, $event);
		}
		else
		{
			print "Warning: Couldn't find path from $event->{'srchost'} to $event->{'dsthost'} in traceroute history. Skipping this entry\n";
			#print Dumper $event;
		}
	}
	
	# loop over path set, marking links as good
	while (my ($src, $dest_bad) = each(%$path_set))
	{
		while (my ($dst, $bad) = each(%$dest_bad))
		{
			# Skip bad links
			if ($bad)
			{
				next;
			}
			
			# mark it as good
			my $pathref = $tr_matrix->{$src}->{$dst};
			foreach my $link (@$pathref)
			{
				if ($link_set->{$link} == 1)
				{
					$link_set->{$link} = 0;
					$link_set_count--;
				}
			}
		}
	}
	
	return ($path_set_count, $link_set_count, \@new_ev_table);
}

# Adds a path to the incidence list
# Params:
# $src - Source address
# $dst - Destination address
# $tr_table - Traceroute table
# $link_set - Set of unjustified links
# $incidence_list - Hash of suspected problem links. May be partially filled
# Returns:
# nothing
sub add_to_incidence_list
{
	my ($src, $dst, $tr_table, $link_set, $incidence_list) = @_;
	
	# lookup pair in tr_table
	if (!exists($tr_table->{$src}->{$dst}))
	{
		print "Path from '$src' to '$dst' couldn't be found in traceroute!! Skipping\n";
		return;
	}
	my $tr_path = $tr_table->{$src}->{$dst};
	for my $link (@$tr_path)
	{
		# skip good links
		if ($link_set->{$link} == 0)
		{
			next;
		}
		
		$incidence_list->{$link}++;
	}
	return;
}

# Returns the max link from the incidence list
# Params:
# $incidence_list - The hash of node addresses to counts
# $tr_node_list - The mapping of nodes to paths
# $path_set - The set of unjustified paths 
# Returns:
# $max_link - The address of the highest incidence link
sub find_max_link
{
	my ($incidence_list, $tr_node_list, $path_set) = @_;
	my $max_incidence;
	my $max_unj_paths = 0;
	my $max_link;
	
	while (my ($elem, $val) = each(%$incidence_list)) 
	{
		if ($max_incidence eq '') {
    		$max_incidence = $val;
		}
	    if ($max_link eq '') {
    		$max_link = $elem;
		}
	    	    
	    if ($val >= $max_incidence)
	    {
	    	my $candidate_problem_paths = $tr_node_list->{$elem};
	    	my $unj_count = 0;
	    	
	    	#print Dumper $path_set;
	    	
	    	foreach my $path (@$candidate_problem_paths)
	    	{
	    		#say "src: @$path[0], dst: @$path[0]";
	    		$unj_count++ if ($path_set->{@$path[0]}->{@$path[1]} == 1);
			}
			
			if ($unj_count > $max_unj_paths)
			{
				$max_unj_paths = $unj_count;
	    		$max_incidence = $val;
	    		$max_link = $elem;
			}
	    }
	}
	
	#print "Selected problem link $max_link with $max_unj_paths unj paths and $max_incidence incidence\n" if ($max_link);
	return $max_link;
}

# Calculates the average metric from the set of paths containing the problem node
# Also marks the path as processed
# Params:
# $problem_paths - The set of paths containing the problem node
# $ev_set - The set containing all events
# $limit - The last element to consider
# Returns:
# $avg_metric - The average metric
sub calc_avg_metric
{
	my ($problem_paths, $ev_set, $limit) = @_;
	
	my $total_metric = 0;
	my $path_count = 0;
	my $idx = 0;
	
	# Loop over the event table looking for these paths	
	foreach my $curr_ev (@$ev_set)
	{
		# Stop once we exceed the limit
		if ($idx > $limit)
		{
			last;
		}

		foreach my $path (@$problem_paths)
		{
			# Match. Mark as processed and add to list
			if ((@$path[0] eq $curr_ev->{'srchost'}) && (@$path[1] eq $curr_ev->{'dsthost'}))
			{
				$curr_ev->{'processed'} = 1;
				$total_metric += $curr_ev->{'metric'};
				$path_count++;
			}
		}
		$idx++;
	}
	return ($total_metric/$path_count);
}

# Marks all paths with problem node as justified
# Params:
# $problem_paths - The set of paths that the problem node belongs to
# $ev_set - The set of events
# $limit - The last event to consider
# $path_set - The set of paths
# Returns:
# nothing
sub mark_justified_paths
{
	my ($problem_paths, $ev_set, $limit, $path_set, $path_set_count) = @_;
	my $idx = 0;
	
	# Loop over the event table looking for paths that fall in the problem set	
	foreach my $curr_ev (@$ev_set)
	{
		# Stop once we exceed the limit
		if ($idx > $limit)
		{
			last;
		}
		
		foreach my $path (@$problem_paths)
		{
			if ((@$path[0] eq $curr_ev->{'src'}) && (@$path[1] eq $curr_ev->{'dst'}))
			{
				$path_set->{$curr_ev->{'src'}}->{$curr_ev->{'dst'}} = 0;
				$path_set_count--;
			}
		}
		$idx++;
	}
	
	return ($path_set_count);
}

# Marks all paths with problem link as justified
# Params:
# $problem_link - The problematic link
# $link_set - The set of links
# Returns:
# nothing
sub mark_justified_links
{
	my ($problem_link, $link_set, $link_set_count) = @_;
	
	# Just set to 0
	$link_set->{$problem_link} = 0;
	
	return ($link_set_count - 1);
}

# Removes all elements with the flag 'processed' set
# Params:
# $ev_set - The set of all events
sub remove_processed
{
	my ($ev_set) = @_;
	
	# Filter all with the processed flag set
	@$ev_set = map { $_->{'processed'} ? ( ) : $_ } @$ev_set;
	
	return;
}

# Updates the metrics of outstanding events
# Params:
# $problem_link - The node identified as the problem
# $avg_metric - The metric calculated from the set of alpha-similar events
# $ev_table - The set of remaining events
# $tr_table - The traceroute table
# $tr_node_list - The set of node to path mappings
# Returns:
# nothing 
sub update_metric
{
	my ($problem_link, $avg_metric, $ev_table, $tr_table, $tr_node_list) = @_;
	
	if (!exists($tr_node_list->{$problem_link}))
	{
		print "Warning: No paths for this node. No metrics to update.\n";
		return;
	}
	
	# Store the ref to the problem paths
	my $problem_paths = $tr_node_list->{$problem_link};
	my $idx = 0;
	
	# Loop over the event table looking for these paths	
	foreach my $element (@$ev_table)
	{
		# TODO: Optimise this loop
		foreach my $path (@$problem_paths)
		{
			if ((@$path[0] eq $element->{'src'}) && (@$path[1] eq $element->{'dst'}))
			{
				#say "src: @$path[0] dst: @$path[1] metric: $element->{'metric'}";
				$element->{'metric'} -= $avg_metric;
				#say "Metric is now: $element->{'metric'}";
				if ($element->{'metric'} < 0)
				{
					$element->{'metric'} = 0;
				}
			}
		}
		$idx++;
	}
	return;
}

# sum-tomo algorithm
# Params:
# $ev_table - The set of events to run the algo on
# $tr_table - The traceroute paths
# $tr_node_list - The set of node to path mappings
# Returns:
# @result table - The list of mappings from problem nodes to problem ranges
sub sum_tomo
{
	my ($self, $ev_table, $tr_table, $tr_node_list) = @_;
		
	my $alpha = $self->{'_alpha'};
	
	# New table to hold the results
	my @result_table = ();
	
	# Make a copy of the ev table to mess with
	#my $ev_set = clone($ev_table);
	my $ev_set = $ev_table;
	
	# build set of all paths
	my $path_set = build_path_set($tr_table);
	
	# build set of all links
	my $link_set = build_link_set($tr_node_list);
	
	# remove all good paths and links, getting the count of unjustified paths and links
	my ($path_set_count, $link_set_count, $ev_set) = remove_good_paths_links($ev_set, $tr_table, $path_set, $link_set);
	
	my $problem_count = scalar(@$ev_set);
	
	while (($path_set_count != 0) && ($link_set_count != 0) && (scalar(@$ev_set) > 1))
	{
		# sort table by performance metric.
		@$ev_set = sort { $a->{'metric'} <=> $b->{'metric'} } @$ev_set;
		
		# select smallest
		my $curr_ev = @$ev_set[0];
		
#		print "selected event: ";
#		print Dumper $curr_ev;
#		print Dumper $ev_set;
		
		# also select all alpha-similar ones that are unique
		# for each src, dest in tr_table, build an incidence list of each node
		my $alpha_max = (1 + $alpha) * $curr_ev->{metric};
		my $alpha_count = $problem_count;
		my $metric_sum = 0;
		my %incidence_list = ();
		my $idx = 0;
		#say "Alpha max: $alpha_max";
		foreach my $element (@$ev_set)
		{
			if ($element->{'metric'} <= $alpha_max)
			{
				#print "Selected event: ";
				#print Dumper $element;
				add_to_incidence_list($element->{srchost}, $element->{dsthost}, $tr_table, $link_set, \%incidence_list);
			}
			else # hit the first node that is outside the metric: quit searching
			{
				$alpha_count = $idx;
				last;
			}
			$idx++;
		}
		
		#print Dumper \%incidence_list;
		# highest incidence, max unjustified paths is the problem node
		my $problem_link = find_max_link(\%incidence_list, $tr_node_list, $path_set);
		
		# If somehow we didn't get a problem node from the set, exclude it
		if (!$problem_link)
		{
			print "Warning. Got paths without possible problem links\n";
			#print Dumper \%incidence_list; 
			#print Dumper $link_set;
			
			# TODO: remove these paths or keep them for the next sum_tomo call? 
			splice(@$ev_set, 0, $alpha_count);
			$problem_count = scalar(@$ev_set);
			
			# skip to the end
			#next;
			last;
		}
		
		#print "Problem link: $problem_link\n";
		
		# Store the ref to the problem paths
		if (!exists($tr_node_list->{$problem_link}))
		{
			print "Error. Couldn't find paths in node_list\n";
		}
		
		my $problem_paths = $tr_node_list->{$problem_link};
		
		# calc the average
		my $avg_metric = calc_avg_metric($problem_paths, $ev_set, $alpha_count - 1);
		
		# mark the containing paths as done
		($path_set_count) = mark_justified_paths($problem_paths, $ev_set, ($alpha_count - 1), $path_set, $path_set_count);
		($link_set_count) = mark_justified_links($problem_link, $link_set, $link_set_count);
		
		#print "link set count $link_set_count path_set_count $path_set_count\n";
		
		# Remove only the processed entries
		remove_processed($ev_set);
				
		# update loss rate for the rest of the paths that contain problem node
		update_metric($problem_link, $avg_metric, $ev_set, $tr_table, $tr_node_list);
				
		# Store the link and range metric in the result table
		my %new_result = ();
		my @problem_range = ($avg_metric * (1 / (1 + $alpha)), $avg_metric * (1 + $alpha));
		$new_result{'link'} = $problem_link;
		$new_result{'range'} = \@problem_range;
		push (@result_table, \%new_result); 
	}
	
	# Return result table
	return (\@result_table);
}

1;
