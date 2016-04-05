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

package PuNDIT::Central::Localization::Tomography::RangeSum;

use strict;
use Log::Log4perl qw(get_logger);

use PuNDIT::Utils::TrHop;

# debug
#use Data::Dumper;

=pod

=head1 PuNDIT::Central::Localization::Tomography::RangeSum

This is the implementation of the Sum Tomography algorithm (Range tomography)
The inputs to this algorithm are the traceroute matrix, traceroute node list and event list
It returns a hash of suspect node to range mappings 

=cut

my $logger = get_logger(__PACKAGE__);

## FUNCTIONS

sub new
{
	my ($class, $cfgHash, $fedName) = @_;
    
	my $alpha = $cfgHash->{'pundit_central'}{$fedName}{'localization'}{"range_tomo_alpha"};
	if (!$alpha)
	{
		$alpha = 0.5;
		$logger->warn("Warning: config file doesn't specify range_tomo alpha value. Using default of $alpha");
	}
	
	my $self = {
        '_alpha' => $alpha,
    };
    
    bless $self, $class;
    return $self;
}

# Removes all good paths and links from the set of paths and links
# Params:
# $evTable - The event table
# $trMatrix - The traceroute matrix
# $pathSet - The set of paths. This will be modified
# $linkSet - The set of links. This will be modified
# Returns:
# $pathSetCount - The count of bad paths
# $linkSetCount - The count of bad links
# $newEvTable - This is a deduplicated table 
sub _removeGoodPathsLinks
{
	my ($evTable, $trMatrix, $pathSet, $linkSet) = @_;
	my $pathSetCount = 0;
	my $linkSetCount = 0;
	
	my @newEvTable = ();
		
	# loop over ev table, marking paths as bad
	foreach my $event (@$evTable)
	{
        my $srcHost = $event->{'srchost'};
        my $dstHost = $event->{'dsthost'};
        
		if (exists($trMatrix->{$srcHost}{$dstHost}))
		{
			# Mark path as bad
			if ($pathSet->{$srcHost}{$dstHost} == 0)
			{
				$pathSet->{$srcHost}{$dstHost} = 1;
				$pathSetCount++;
			}
			elsif ($pathSet->{$srcHost}{$dstHost} == 1)
			{
			    $logger->warn("Warning. Duplicated event from $srcHost to $dstHost. Ignoring");
			    next;
			}
			
			# Loop over links in path, marking them as bad
			my $pathref = $trMatrix->{$srcHost}{$dstHost}{'path'};
			foreach my $trHop (@$pathref)
			{
			    my $hopId = $trHop->getHopId();
				if (exists($linkSet->{$hopId}) && $linkSet->{$hopId} == 0)
				{
					$linkSet->{$hopId} = 1;
					$linkSetCount++;
				}
			}
			
			push (@newEvTable, $event);
		}
		else
		{
			$logger->warn("Warning: Couldn't find path from $srcHost to $dstHost in traceroute history. Skipping this entry");
			#print Dumper $event;
		}
	}
	
	# loop over path set, marking links as good
	while (my ($srcGood, $destInfo) = each(%$pathSet))
	{
		while (my ($dstGood, $badFlag) = each(%$destInfo))
		{
			# Skip bad links
			next if ($badFlag == 1);
			
			# mark each hop in this path as good
			my $pathref = $trMatrix->{$srcGood}{$dstGood}{'path'};
			foreach my $trHop (@$pathref)
			{
			    my $hopId = $trHop->getHopId();
				if (exists($linkSet->{$hopId}) && $linkSet->{$hopId} == 1)
				{
					$linkSet->{$hopId} = 0;
					$linkSetCount--;
				}
			}
		}
	}
	
	return ($pathSetCount, $linkSetCount, \@newEvTable);
}

# Adds a path to the incidence list
# Params:
# $src - Source address
# $dst - Destination address
# $trMatrix - Traceroute table
# $linkSet - Set of unjustified links
# $incidenceList - Hash of suspected problem links. May be partially filled
# Returns:
# nothing
sub _addToIncidenceList
{
	my ($src, $dst, $trMatrix, $linkSet, $incidenceList) = @_;
	
	# lookup pair in tr_table
	if (!exists($trMatrix->{$src}{$dst}))
	{
		$logger->warn("Path from '$src' to '$dst' couldn't be found in traceroute! Skipping");
		return;
	}
	my $trPath = $trMatrix->{$src}{$dst}{'path'};
	foreach my $trHop (@$trPath)
	{
	    my $hopId = $trHop->getHopId();

		# skip good links
		next if ($linkSet->{$hopId} == 0);
		
		if (!exists($incidenceList->{$hopId}))
		{
		    $incidenceList->{$hopId} = 0;
		}
		$incidenceList->{$hopId}++;
	}
	return;
}

# Returns the max link from the incidence list
# Params:
# $incidenceList - The hash of node addresses to counts
# $trNodePath - The mapping of nodes to paths
# $pathSet - The set of unjustified paths 
# Returns:
# $maxLink - The address of the highest incidence link
sub _findMaxLink
{
	my ($incidenceList, $trNodePath, $pathSet) = @_;
	my $maxIncidence;
	my $maxUnjPaths = 0;
	my $maxLink;
	
	while (my ($elem, $val) = each(%$incidenceList)) 
	{
	    # On first loop, assign max incidence and link
		if (!defined($maxIncidence)) 
		{
    		$maxIncidence = $val;
		}
	    if (!defined($maxLink)) 
	    {
    		$maxLink = $elem;
		}
	    
	    # found a new max incidence.
	    # check if it appears in more unjustified paths than the last one
	    if ($val >= $maxIncidence)
	    {
	    	my $candidateProblemPaths = $trNodePath->{$elem};
	    	my $unjCount = 0;
	    	
	    	#print Dumper $pathSet;
	    	
	    	foreach my $pathInfo (@{$candidateProblemPaths})
	    	{
	    		#say "src: @$path[0], dst: @$path[0]";
	    		$unjCount++ if ($pathSet->{$pathInfo->{'src'}}{$pathInfo->{'dst'}} == 1);
			}
			
			if ($unjCount > $maxUnjPaths)
			{
				$maxUnjPaths = $unjCount;
	    		$maxIncidence = $val;
	    		$maxLink = $elem;
			}
	    }
	}
	
	#print "Selected problem link $maxLink with $maxUnjPaths unj paths and $maxIncidence incidence\n" if ($maxLink);
	return $maxLink;
}

# Calculates the average metric from the set of paths containing the problem node
# Also marks the path as processed
# Params:
# $problemPaths - The set of paths containing the problem node
# $evSet - The set containing all events
# $limit - The last element to consider
# Returns:
# $avgMetric - The average metric
sub _calcAvgMetric
{
	my ($problemPaths, $evSet, $limit) = @_;
	
	my $totalMetric = 0;
	my $pathCount = 0;
	my $idx = 0;
	
	# Loop over the event table looking for these paths	
	foreach my $currEv (@$evSet)
	{
		# Stop once we exceed the limit
		if ($idx > $limit)
		{
			last;
		}

		foreach my $pathInfo (@$problemPaths)
		{    
			# Match. Mark as processed and add to list
			if (($pathInfo->{'src'} eq $currEv->{'srchost'}) && 
			    ($pathInfo->{'dst'} eq $currEv->{'dsthost'}))
			{
				$currEv->{'processed'} = 1;
				$totalMetric += $currEv->{'metric'};
				$pathCount++;
			}
		}
		$idx++;
	}
	return ($totalMetric/$pathCount);
}

# Marks all paths with problem link as justified
# Params:
# $problemPaths - The set of paths that the problem node belongs to
# $evSet - The set of events
# $limit - The last event to consider
# $pathSet - The set of paths
# Returns:
# nothing
sub _markJustifiedPaths
{
	my ($problemPaths, $evSet, $limit, $pathSet, $pathSetCount) = @_;
	my $idx = 0;
	
	# Loop over the event table looking for paths that fall in the problem set	
	foreach my $currEv (@$evSet)
	{
		# Stop once we exceed the limit
		if ($idx > $limit)
		{
			last;
		}
		
		# Would be faster to store the problem paths in a hash and just do a match
		foreach my $pathInfo (@$problemPaths)
		{
			if (($pathInfo->{'src'} eq $currEv->{'src'}) && 
			    ($pathInfo->{'dst'} eq $currEv->{'dst'}))
			{
			    # 0 means justified, will not be used for future calculations
				$pathSet->{$currEv->{'src'}}{$currEv->{'dst'}} = 0;
				$pathSetCount--;
			}
		}
		$idx++;
	}
	
	return ($pathSetCount);
}

# Marks all problem links as justified
# Params:
# $problemLink - The problematic link
# $linkSet - The set of links
# Returns:
# nothing
sub _markJustifiedLinks
{
	my ($problemLink, $linkSet, $linkSetCount) = @_;
	
	# Just set to 0
	$linkSet->{$problemLink} = 0;
	
	return ($linkSetCount - 1);
}

# Removes all elements with the flag 'processed' set
# Params:
# $evSet - The set of all events
sub _removeProcessed
{
	my ($evSet) = @_;
	
	# Filter all with the processed flag set
	@$evSet = map { $_->{'processed'} ? ( ) : $_ } @$evSet;
	
	return;
}

# Updates the metrics of outstanding events
# Params:
# $problemLink - The node identified as the problem
# $avgMetric - The metric calculated from the set of alpha-similar events
# $evTable - The set of remaining events
# $trMatrix - The traceroute table
# $trNodePath - The set of node to path mappings
# Returns:
# nothing 
sub _updateMetric
{
	my ($problemLink, $avgMetric, $evTable, $trMatrix, $trNodePath) = @_;
	
	if (!exists($trNodePath->{$problemLink}))
	{
		$logger->warn("No paths for this node $problemLink. Possible inconsistent traceroute. No metrics updated.");
		return;
	}
	
	# Store the ref to the problem paths
	my $problemPaths = $trNodePath->{$problemLink};
	my $idx = 0;
	
	# Loop over the event table looking for these paths	
	foreach my $element (@$evTable)
	{
		# TODO: Optimise this loop
		foreach my $pathInfo (@$problemPaths)
		{
			if (($pathInfo->{'src'} eq $element->{'src'}) && 
			    ($pathInfo->{'dst'} eq $element->{'dst'}))
			{
				#say "src: @$path[0] dst: @$path[1] metric: $element->{'metric'}";
				$element->{'metric'} -= $avgMetric;
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

# Runs the sum-tomo algorithm
# This is the public interface
# Params:
# $evTable - The set of events to analyse
# $trMatrix - The traceroute paths, a two level hash of src,dst to path info
# $trNodePath - The hash of node to path mappings
# $pathSet - A two level hash of source,destinations to problem flags 
# $linkSet - A hash of hopIds to problem
# Returns:
# @resultTable - The list of problematic hopIds and their associated problem ranges
sub runTomo
{
	my ($self, $evTable, $trMatrix, $trNodePath, $pathSet, $linkSet) = @_;

    $logger->debug("Running Range Tomography (Sum)");
    
	my $alpha = $self->{'_alpha'};
	
	# New table to hold the results
	my @resultTable = ();
	
	# remove all good paths and links, getting the count of unjustified paths and links
	# also deduplicates the evTable to a smaller $evSet
	my ($pathSetCount, $linkSetCount, $evSet) = _removeGoodPathsLinks($evTable, $trMatrix, $pathSet, $linkSet);
	
	# loop while unexplained paths, links and problems exist 
	while (($pathSetCount != 0) && ($linkSetCount != 0) && (scalar(@$evSet) > 1))
	{
		# sort event table by performance metric
		@$evSet = sort { $a->{'metric'} <=> $b->{'metric'} } @$evSet;
		
		# select smallest value
		my $currEv = @$evSet[0];
		
#		print "selected event: ";
#		print Dumper $currEv;
#		print Dumper $evSet;
		
		# Now select all alpha-similar ones that are unique
		# for each path within the alpha similar threshold, build an incidence list
		my $alpha_max = (1 + $alpha) * $currEv->{'metric'}; # this is the threshold
		my $alphaCount = scalar(@$evSet); # index of the last entry in this threshold, initialised to size of list 
		my %incidenceList = (); # the hash of hopIds to number of appearances in problematic paths
		my $idx = 0; # index for the loop
		#say "Alpha max: $alpha_max";
		foreach my $element (@$evSet)
		{
			if ($element->{'metric'} <= $alpha_max)
			{
				#print "Selected event: ";
				#print Dumper $element;
				_addToIncidenceList($element->{'srchost'}, $element->{'dsthost'}, $trMatrix, $linkSet, \%incidenceList);
			}
			else # hit the first node that is outside the metric: quit searching
			{
				$alphaCount = $idx;
				last;
			}
			$idx++;
		}
		
		#print Dumper \%incidenceList;
		
		# Node with the highest incidence and max unjustified paths is the problem node
		my $problemLink = _findMaxLink(\%incidenceList, $trNodePath, $pathSet);
		
		# If somehow we didn't get a problem node from the set, exclude it
		if (!$problemLink)
		{
			$logger->warn("Got problematic paths without possible problem links");
			#print Dumper \%incidenceList; 
			#print Dumper $linkSet;
			
			# Decide whether to remove these paths or keep them for the next sum_tomo call?
			# Keeping them will just result in the same result, so remove
			splice(@$evSet, 0, $alphaCount);
			
			# skip to the end. There isn't a link to be found
			last;
		}
		
		#print "Problem link: $problemLink\n";
		
		# Store the ref to the problem paths
		if (!exists($trNodePath->{$problemLink}))
		{
			$logger->warn("Couldn't find $problemLink in trNodePath. Possible inconsistent traceroute");
		}
		
		my $problemPaths = $trNodePath->{$problemLink};
		
		# calc the average
		my $avgMetric = _calcAvgMetric($problemPaths, $evSet, $alphaCount - 1);
		
		# mark the containing paths as done
		($pathSetCount) = _markJustifiedPaths($problemPaths, $evSet, ($alphaCount - 1), $pathSet, $pathSetCount);
		($linkSetCount) = _markJustifiedLinks($problemLink, $linkSet, $linkSetCount);
		
		#print "link set count $linkSetCount path_set_count $pathSetCount\n";
		
		# Remove only the processed entries
		_removeProcessed($evSet);
				
		# update loss rate for the rest of the paths that contain problem node
		_updateMetric($problemLink, $avgMetric, $evSet, $trMatrix, $trNodePath);
				
		# Store the link and range metric in the result table
		my @problemRange = ($avgMetric * (1 / (1 + $alpha)), $avgMetric * (1 + $alpha));
		my $new_result = {
            'hopId' => $problemLink,
            'range' => \@problemRange,
	    };
		push (@resultTable, $new_result); 
	}

    $logger->debug("Produced a hypothesis set with " . scalar(@resultTable) . " nodes");
	
	# Return result table
	return (\@resultTable);
}

1;
