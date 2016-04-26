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

package PuNDIT::Central::Localization::Tomography::Boolean;

use strict;
use Log::Log4perl qw(get_logger);

use PuNDIT::Utils::TrHop;

# debug
#use Data::Dumper;

=pod

=head1 PuNDIT::Central::Localization::Tomography::Boolean

This is the implementation of the boolean tomography algorithm
The inputs to this algorithm are the traceroute matrix, traceroute node list and event list
It returns a list of suspect nodes 

=cut

my $logger = get_logger(__PACKAGE__);

## FUNCTIONS

sub new
{
	my ($class, $cfgHash, $fedName) = @_;
    
    # Flag that indicates whether the conservative version of the algorithm should be run
    my $conservative = 0;
    
	my $self = {
	    '_conservative' => $conservative,
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
        my $srcHost = $event->{'srcHost'};
        my $dstHost = $event->{'dstHost'};
        
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
                $logger->warn("Warning. Duplicated event from $srcHost to $dstHost. Ignoring.");
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
            $logger->warn("Warning: Couldn't find path from $srcHost to $dstHost in traceroute history. Skipping this entry.");
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

# Adds a specified link and a set of failed paths containing that link to the failure set list
# Params:
# $unexplainedLink - The unexplained link to add
# $unexplainedPathSet - The set of explained/unexplained paths
# $trNodePath - The list of link to path mappings
# $failureSetList - The hash of element to list of failed paths
# $failureScoreList - The hash of link to score mappings
# Returns:
# nothing
sub _addToFailurePathSetList
{
	my ($unexplainedLink, $unexplainedPathSet, $trNodePath, $failureSetList, $failureScoreList) = @_;
	
	my @failurePathSet = ();
	my $failureScore = 0;
	
	if (!exists($trNodePath->{$unexplainedLink}))
	{
	    $logger->warn("Couldn't find $unexplainedLink in trNodePath. Quitting.");
	    return;
	}
	my $containingPaths = $trNodePath->{$unexplainedLink};
		
	# For each path that contains the problem link
	foreach my $pathInfo (@$containingPaths)
	{
		# If is recognised as an unexplained path
		if ($unexplainedPathSet->{$pathInfo->{'src'}}{$pathInfo->{'dst'}} == 1)
		{
			# Add to the list of failed paths
			push (@failurePathSet, $pathInfo);
			$failureScore++;
		}
	}
	
	# Add to failure set
	$failureSetList->{$unexplainedLink} = \@failurePathSet;
	$failureScoreList->{$unexplainedLink} = $failureScore;
	
	return;
}

# Returns the links belonging to the maximum number of failed paths
# Params:
# $failureScoreSet - The hash of hopId to failureScores (# of unexplained paths)
# Returns:
# $filureLinkSet - The hopIds of the links with highest incidence
sub _findMaxFailureLinks
{
	my ($failureScoreSet) = @_;

	my @failureLinkSet = ();
	my $maxVal;
	
	# Loop over a descending order sorted list
	foreach my $elem (sort { $failureScoreSet->{$b} <=> $failureScoreSet->{$a} }
           keys %$failureScoreSet)
    {
    	$maxVal = $failureScoreSet->{$elem} if (!defined($maxVal));
    	
	    # Quit loop if current value is less than max or not problematic    
	    last if ($failureScoreSet->{$elem} < $maxVal || $failureScoreSet->{$elem} == 0);
	    
	    # Else add to the failure set
	    push (@failureLinkSet, $elem) if $failureScoreSet->{$elem} > 0;
	}
	
	#print "failure link set";
	#print Dumper \@failureLinkSet;
	return (\@failureLinkSet, $maxVal);
}

# Marks paths and links as explained
# Called after the problem link is identified
# Params:
# $problemPaths - The set of failure paths that the problem link belongs to
# $pathSet - The set of all unexplained paths
# $pathSetCount - The number of unexplained paths in pathSet
# Returns:
# $pathSetCount - The number of unexplained paths after removal
sub _markExplainedPaths
{
	my ($problemPaths, $pathSet, $pathSetCount) = @_;
	
	# Loop over the problem paths and mark them in the path set as explained		
	foreach my $pathInfo (@$problemPaths)
	{
		# The current element is a pair (src, dst)
#		$logger->debug("Marking Problem Path from " . $pathInfo->{'src'} . " to " . $pathInfo->{'dst'} . " as explained");
		
		# We want the path set count to remain consistent, so need to check whether we are marking a unexplained path
		if ($pathSet->{$pathInfo->{'src'}}{$pathInfo->{'dst'}} == 1)
		{
			$pathSet->{$pathInfo->{'src'}}{$pathInfo->{'dst'}} = 0;
			$pathSetCount--;
		}
	}

	return ($pathSetCount);
}

# Marks all paths with problem link as explained
# Params:
# $problemLink - The problematic link
# $linkSet - The hash of hopIds to explained status flags
# $linkSetCount - The number of unexplained links in linkSet
# $trNodePath - The mappings of nodes to paths
# Returns:
# nothing
sub _markExplainedLinks
{
	my ($self, $problemLink, $linkSet, $linkSetCount) = @_;
	
	# Just set to 0
	$linkSet->{$problemLink} = 0;
	$linkSetCount -= 1;
		
	return ($linkSetCount);
}

# marks the paths as explained for a problem link
# if conservative flag is set, will not remove all links from all explained paths
sub _markExplainedPathsLinks
{
    my ($problemPaths, $problemLink, $pathSet, $pathSetCount, $linkSet, $linkSetCount, $trMatrix, $conservative) = @_;
    
    # Loop over the problem paths and mark them in the path set as explained        
    foreach my $pathInfo (@$problemPaths)
    {
        # The current element is a pair (src, dst)
#       $logger->debug("Marking Problem Path from " . $pathInfo->{'src'} . " to " . $pathInfo->{'dst'} . " as explained");
        
        # We want the path set count to remain consistent, so need to check whether we are marking a unexplained path
        if ($pathSet->{$pathInfo->{'src'}}{$pathInfo->{'dst'}} == 1)
        {
            $pathSet->{$pathInfo->{'src'}}{$pathInfo->{'dst'}} = 0;
            $pathSetCount--;
            
            # skip if this path doesn't exist in Trace (sanity check) or conservative flag is set
            next if ($conservative == 1 || !defined($trMatrix->{$pathInfo->{'src'}}{$pathInfo->{'dst'}}));
            
            my $trPath = $trMatrix->{$pathInfo->{'src'}}{$pathInfo->{'dst'}}->{'path'};
            
            foreach my $trHop (@{$trPath})
            {
                my $hopId = $trHop->getHopId();
                
                if ($linkSet->{$hopId} == 1)
                {
                    $linkSet->{$hopId} = 0;
                    $linkSetCount -= 1;
                }
            }
        }
    }
    
    # if conservative flag is set, the problem link will not be set to 0
    # handle that case here
    if ($linkSet->{$problemLink} == 1)
    {
        $linkSet->{$problemLink} = 0;
        $linkSetCount -= 1;
    }

    return ($pathSetCount, $linkSetCount);
}

# Runs the bool_tomo algorithm
# This is the public interface
# Params:
# $evTable - The set of reported problematic events
# $trMatrix - The traceroute paths
# $trNodePath - The set of link to path mappings
# $pathSet - A two level hash of source,destinations to problem flags 
# $linkSet - A hash of hopIds to problem
# Returns:
# @hypothesisSet - The array of suspected problem links
sub runTomo
{
	my ($self, $evTable, $trMatrix, $trNodePath, $pathSet, $linkSet) = @_;
	
	$logger->debug("Running Boolean Tomography");
	
	# The hypothesis set of defective links
	my @hypothesisSet = ();

	# remove all good paths and links, getting the count of unexplained paths and links.
	# This is equivalent to building the failure set and set of candidate links
	my ($pathSetCount, $linkSetCount, $newEvTable) = _removeGoodPathsLinks($evTable, $trMatrix, $pathSet, $linkSet);

#	print "pathSet ";
#	print Dumper($pathSet);
#	print "linkSet ";
#	print Dumper($linkSet);

    # loop while the sets aren't empty
	while (($pathSetCount != 0) && ($linkSetCount != 0))
	{
		my %failurePathSetList = (); # Failure paths for each link
		my %failureScoreList = (); # Scores for each link
		
		# loop over all elements in the link set, adding up their scores
		while (my ($hopId, $unexpFlag) = each(%{$linkSet}))
		{
			if ($unexpFlag == 1) # is an unexplained link
			{
				_addToFailurePathSetList($hopId, $pathSet, $trNodePath, \%failurePathSetList, \%failureScoreList);
			}
		}
		
#    	print "Failure path set list ";
#    	print Dumper \%failurePathSetList;	
#    	print "Failure score list ";
#    	print Dumper \%failureScoreList;
		
		# Get the set of failure link(s)
		my ($failureLinkSet, $failureScore) = _findMaxFailureLinks(\%failureScoreList);
		
		# Error check so we don't loop forever
		if (scalar(@{$failureLinkSet}) == 0 || $failureScore == 0)
		{
#			print "Error! no failure links generated but unexplained links remain.\n";
#			print "Debug: Set of paths:";
#			print Dumper $pathSet;
#			print "Debug: Set of links:";
#			print Dumper $linkSet;
			last;
		}
		
		#print "failure link set ";
		#print Dumper $failureLinkSet;
		
		# Loop over failure link set
		foreach my $problemLink (@{$failureLinkSet})
		{
#			$logger->debug("Found problem link $problemLink");
			
			my $problemPaths = $failurePathSetList{$problemLink}; 
			
			# add to hypothesis set
			push (@hypothesisSet, { 'hopId' => $problemLink, 'failureScore' => $failureScore });
			
			# mark as explained in path and link sets and update the counts
			
			($pathSetCount, $linkSetCount) = _markExplainedPathsLinks($problemPaths, $problemLink, $pathSet, $pathSetCount, $linkSet, $linkSetCount, $trMatrix, $self->{'_conservative'});
#			($pathSetCount) = _markExplainedPaths($problemPaths, $pathSet, $pathSetCount);
#			($linkSetCount) = _markExplainedLinks($problemLink, $linkSet, $linkSetCount);
		} 
	}
	
	$logger->debug("Produced a hypothesis set with " . scalar(@hypothesisSet) . " nodes");
	
	# Return result table
	return (\@hypothesisSet);
}

1;
