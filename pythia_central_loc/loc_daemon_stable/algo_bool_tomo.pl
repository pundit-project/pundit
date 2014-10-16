#!/usr/bin/perl
package Loc::Tomo::Bool;

use strict;

#use Data::Dumper;

=pod

=head1 DESCRIPTION

This is the implementation of the boolean tomography algorithm
The inputs to this algorithm are the traceroute matrix, traceroute node list and event list
It returns a list of suspect nodes 

=cut


## GLOBALS


## FUNCTIONS

sub new
{
	my $class = shift;
    my $cfg = shift;
    
	my $self = {
        _config => $cfg,
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
			print "Warning: Couldn't find path from $event->{'srchost'} to $event->{'dsthost'} in traceroute history. Skipping this entry\n"
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
	
	return (\@new_ev_table, $path_set_count, $link_set_count);
}

# Adds a specified link and a set of failed paths containing that link to the failure set list
# Params:
# $unexplained_link - The unexplained link to add
# $unexplained_path_set - The set of explained/unexplained paths
# $tr_node_list - The list of link to path mappings
# $failure_set_list - The hash of element to list of failed paths
# $failure_score_list - The hash of link to score mappings
# Returns:
# nothing
sub add_to_failure_path_set_list
{
	my ($unexplained_link, $unexplained_path_set, $tr_node_list, $failure_set_list, $failure_score_list) = @_;
	
	my @failure_path_set = ();
	my $failure_score = 0;
	
	my $containing_paths = $tr_node_list->{$unexplained_link};
		
	# For each path that contains the problem link
	foreach my $elem (@$containing_paths)
	{
		# If is recognised as an unexplained path
		if ($unexplained_path_set->{@$elem[0]}->{@$elem[1]} == 1)
		{
			# Add to the list
			my @failure_path = (@$elem[0], @$elem[1]);
			push (@failure_path_set, \@failure_path);
			$failure_score++;
		}
	}
	
	# Add to failure set
	$failure_set_list->{$unexplained_link} = \@failure_path_set;
	$failure_score_list->{$unexplained_link} = $failure_score;
	
	return;
}

# Returns the max link from the incidence list
# Params:
# $incidence_list - The hash of node addresses to counts
# $tr_node_list - The mapping of nodes to paths
# $path_set - The set of unjustified paths 
# Returns:
# $max_link - The address of the highest incidence link
sub find_max_failure_links
{
	my ($failure_score_set) = @_;

	my @failure_link_set = ();
	my $max_val;
	
	# Loop over a descending order sorted list
	foreach my $elem (sort { $failure_score_set->{$b} <=> $failure_score_set->{$a} }
           keys %$failure_score_set)
    {
    	$max_val |= $failure_score_set->{$elem};
    	
	    # Quit loop if current value is less than max	    
	    last if ($failure_score_set->{$elem} < $max_val);
	    
	    # Else add to the failure set
	    push (@failure_link_set, $elem);
	}
	
	#print "failure link set";
	#print Dumper \@failure_link_set;
	return \@failure_link_set;
}

# Marks paths as explained
# Params:
# $problem_paths - The set of failure paths that the problem node belongs to
# $path_set - The set of all unexplained paths
# $path_set_count - The number of unexplained paths in path_set
# Returns:
# $path_set_count - The number of unexplained paths after removal
sub mark_explained_paths
{
	my ($problem_paths, $path_set, $path_set_count) = @_;
	my $idx = 0;
	
	# Loop over the problem paths and mark them in the path set as explained		
	foreach my $curr_path (@$problem_paths)
	{
		# The current element is a pair (src, dst)
		#print Dumper $curr_path;
		
		# We want the path set count to remain consistent, so need to check whether we are marking a unexplained path
		if ($path_set->{@$curr_path[0]}->{@$curr_path[1]} == 1)
		{
			$path_set->{@$curr_path[0]}->{@$curr_path[1]} = 0;
			$path_set_count--;
		}
	}

	return ($path_set_count);
}

# Marks all paths with problem link as explained
# Params:
# $problem_link - The problematic link
# $link_set - The set of unexplained links
# $link_set_count - The number of links in link_set
# Returns:
# nothing
sub mark_explained_links
{
	my ($problem_link, $link_set, $link_set_count) = @_;
	
	# Just set to 0
	$link_set->{$problem_link} = 0;
	
	return ($link_set_count - 1);
}

# bool_tomo algorithm
# Params:
# $ev_table - The set of reported problematic events
# $tr_table - The traceroute paths
# $tr_node_list - The set of link to path mappings
# Returns:
# @hypothesis_set - The array of suspected problem links
sub bool_tomo
{
	my ($self, $ev_table, $tr_table, $tr_node_list) = @_;
	
	# The hypothesis set of defective links
	my @hypothesis_set = ();
	
	# build set of all paths
	my $path_set = build_path_set($tr_table);
	
	# build set of all links
	my $link_set = build_link_set($tr_node_list);
	
	# remove all good paths and links, getting the count of unexplained paths and links.
	# This is equivalent to building the failure set and set of candidate links
	my ($path_set_count, $link_set_count, $new_ev_table) = remove_good_paths_links($ev_table, $tr_table, $path_set, $link_set);
		
	# loop while the sets aren't empty
	while (($path_set_count != 0) && ($link_set_count != 0))
	{
		# Failure paths for each link
		my %failure_path_set_list = ();
		
		# Scores for each link
		my %failure_score_list = ();
		
		# loop over all elements in the link set, adding up their scores
		while (my ($elem, $val) = each(%$link_set))
		{
			if ($val == 1) # is an unexplained link
			{
				add_to_failure_path_set_list($elem, $path_set, $tr_node_list, \%failure_path_set_list, \%failure_score_list);
			}
		}
		
#	print "Failure path set list";
#	print Dumper \%failure_path_set_list;	
#	print "Failure score list";
#	print Dumper \%failure_score_list;
		
		# Get the set of failure link(s)
		my $failure_links = find_max_failure_links(\%failure_score_list);
		
		# Error check so we don't loop forever
		if (scalar(@$failure_links) == 0)
		{
			print "Error! no failure links generated but unexplained links remain.\n";
#			print "Debug: Set of paths:";
#			print Dumper $path_set;
#			print "Debug: Set of links:";
#			print Dumper $link_set;
			last;
		}
		
		#print "failure links";
		#print Dumper $failure_links;
		
		# Loop over failure link set
		foreach my $problem_link (@$failure_links)
		{
			#print "$problem_link";
			my $problem_paths = $failure_path_set_list{$problem_link}; 
			
			# add to hypothesis set
			push (@hypothesis_set, $problem_link);
			
			# mark as explained in path and link sets
			($path_set_count) = mark_explained_paths($problem_paths, $path_set, $path_set_count);
			($link_set_count) = mark_explained_links($problem_link, $link_set, $link_set_count);
		} 
	}
	
	# Return result table
	return (\@hypothesis_set);
}

1;