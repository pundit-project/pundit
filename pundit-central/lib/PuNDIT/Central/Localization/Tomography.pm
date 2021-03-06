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

package PuNDIT::Central::Localization::Tomography;

use strict;
use Log::Log4perl qw(get_logger);
use Storable 'dclone';

# local modules
use PuNDIT::Central::Localization::Reporter; # for writing back to backend
use PuNDIT::Central::Localization::Tomography::Boolean; # Boolean Tomography
use PuNDIT::Central::Localization::Tomography::RangeSum; # Range Tomography - Sum
use PuNDIT::Utils::DetectionCode; # used for problem code to tomography mapping
use PuNDIT::Utils::TrHop; # used for extracting hop IDs

# debug
use Data::Dumper;

=pod

=head1 DESCRIPTION

This module handles the tomography processing for the event tables and the input traceroutes

=cut

my $logger = get_logger(__PACKAGE__);

sub new
{
	my ($class, $cfgHash, $fedName) = @_;
    
	# init the subcomponents
	my $loc_reporter = new PuNDIT::Central::Localization::Reporter($cfgHash, $fedName);
	return undef if (!$loc_reporter);
	
	my $sum_tomo = new PuNDIT::Central::Localization::Tomography::RangeSum($cfgHash, $fedName);
	return undef if (!$sum_tomo);
	
	my $bool_tomo = new PuNDIT::Central::Localization::Tomography::Boolean($cfgHash, $fedName);
    return undef if (!$bool_tomo);
	
	my $problem_types_string = $cfgHash->{'pundit_central'}{$fedName}{'localization'}{'problem_types'};
	chomp($problem_types_string);
	my @problem_types_list = split(/[\s|,]+/, $problem_types_string);
	if (!$problem_types_string || !@problem_types_list)
	{
        $logger->error("No problem types specified to localize. Quitting");
        return undef; 
	}
	
	my $self = {
        '_loc_reporter' => $loc_reporter,
        '_sum_tomo' => $sum_tomo,
        '_bool_tomo' => $bool_tomo,
                
        # params
        '_problem_types_list' => \@problem_types_list,
    };
    
    bless $self, $class;
    return $self;
}

sub DESTROY
{
	
}

# Filters events by problem type
sub _filterEvents
{
	my ($self, $problemName, $evTable) = @_;
	
	my $metric = PuNDIT::Utils::DetectionCode::getDetectionCodeMetric($problemName);
	
	# Filter the events based on detectionCode flag, also renaming the metric field
	my @filtered_events = ();
	foreach my $event (@{$evTable})
	{
	    next if (!defined($event));
	    
	    my $problemFlag = PuNDIT::Utils::DetectionCode::getDetectionCodeBitValid($event->{'detectionCode'}, $problemName);
	    
	    next if (!defined($problemFlag));
	    
#	    $logger->debug("detCode " . $event->{'detectionCode'} . " problem $problemName flag $problemFlag");
	    
	    if ($problemFlag == 1)
	    {
	        my $newEntry = {
                'srcHost' => $event->{'srcHost'}, 
                'dstHost' => $event->{'dstHost'}, 
                'metric' => $event->{$metric},
                'processed' => 0,
                'unknown' => 0,
            };
            push (@filtered_events, $newEntry);
	    }
	    elsif ($event->{'detectionCode'} == -1) # special case when unknown entry encountered
	    {
	        my $newEntry = {
                'srcHost' => $event->{'srcHost'}, 
                'dstHost' => $event->{'dstHost'}, 
                'metric' => -1,
                'processed' => 0,
                'unknown' => 1, 
            };
            push (@filtered_events, $newEntry);
	    }
	}
	
	return \@filtered_events;	
}


# Builds a set of all paths and links from the traceroute table
# Params:
# $trMatrix - Reference to the TraceRoute table, an hash of hashes where $trMatrix{src}{dst} = pathInfo
# Returns:
# $pathSet - A hash of hashes %path_set{$src}{$dst} = bad/good value
# $linkSet - A flat hash of all %link_set{$node} = bad/good value
# $trNodePath - List of node id to paths. Used for tomography algorithms 
# $nodeIdTrHopList - List of node_id to TrHop mappings. Used for lookup during reporting
sub _buildPathLinkSet
{
    my ($trMatrix) = @_;
    
    my %pathSet = ();
    my %linkSet = ();
    my %trNodePath = ();
    my %nodeIdTrHopList = ();
    
    while (my ($src, $destDetails) = each(%$trMatrix))
    {
        while (my ($dst, $pathInfo) = each(%$destDetails))
        {
            # this is an arrayref of TrHops
            my $path = $pathInfo->{'path'};
            
            # Skip host-only tr
            next if (($src eq $path->[0]->getHopId()));
            
            # add an entry to path set with 0 bad links
            # we don't care about auto vivifying here
            $pathSet{$src}{$dst} = 0;
            
            # now loop over the hops to add them to the link_set
            foreach my $trHop (@$path)
            {
                my $hopId = $trHop->getHopId();
        
                # skip stars
                next if ($hopId eq '*');
                
#                print "Adding $hopId with $src $dst \n";
                if ( !exists( $linkSet{$hopId} ) )
                {
                    $linkSet{$hopId} = 0;
                }
                
                # we put these in a separate structs because link_set will be copied/modified later
                # and the trNodePath and nodeIdTrHopList hashes should be immutable data
                if (!exists($trNodePath{$hopId}))
                {
                    $trNodePath{$hopId} = [];
                }
                push(@{$trNodePath{$hopId}}, $pathInfo);
                
                if (!exists($nodeIdTrHopList{$hopId}))
                {
                    $nodeIdTrHopList{$hopId} = $trHop;
                }
            }
        }
    }

    return (\%pathSet, \%linkSet, \%trNodePath, \%nodeIdTrHopList);
}

# Public interface
# Starts the localisation algorithm on a specific time window, traceroute matrix and event table
sub processTimeWindow 
{
	my ($self, $refTime, $trMatrix, $evTable) = @_;
	
	my ($pathSet, $linkSet, $trNodePath, $nodeIdTrHopList) = _buildPathLinkSet($trMatrix);
	
#	$logger->debug("event table");
#	$logger->debug(sub { Data::Dumper::Dumper($evTable) });
	
	# Run for each enabled problem 
	foreach my $problemName (@{$self->{'_problem_types_list'}})
	{	
		# keep events relevant only for the specific metric
		my $filteredEvents = $self->_filterEvents($problemName, $evTable);
		
		# Optimisation. Skip tomography if 1 or fewer paths
		if (scalar(@{$filteredEvents}) <= 1 || !$filteredEvents)
		{
			$logger->debug($problemName . ": Not enough events to localise. Skipping.");
			next;
		}
		
		$logger->debug($problemName . ": " . scalar(@{$filteredEvents}) . " events to process. ");
		
		# make a copy of the path_set and link_set so this run of the algorithm can modify it
		my $tomoPathSet = dclone($pathSet);
		my $tomoLinkSet = dclone($linkSet);
		
        # Determine which algo corresponds to which tomography and run it
        my $tomoObj;
        my $tomoType = PuNDIT::Utils::DetectionCode::getDetectionCodeTomography($problemName);
        if ($tomoType eq "range_sum")
        {
            $tomoObj = $self->{'_sum_tomo'};
        }
        elsif ($tomoType eq "boolean")
        {
            $tomoObj = $self->{'_bool_tomo'};
        }
        if (!defined($tomoObj))
        {
            $logger->error("Error: undefined tomography type $tomoType for problem $problemName. Skipping");
            next;
        }
        my $locResultTable = $tomoObj->runTomo($filteredEvents, $trMatrix, $trNodePath, $tomoPathSet, $tomoLinkSet);
        
        if (scalar(@{$locResultTable}) > 0)
        {
            # generate a detectionCode with a single bit set, used for reporting
            my $detectionCode = PuNDIT::Utils::DetectionCode::setDetectionCodeBit(0, $problemName, 1);
            
            $logger->debug("Inserting records with detCode $detectionCode");
            
            # Store the table of results to db
            $self->{'_loc_reporter'}->writeData($refTime, $tomoType, $detectionCode, $locResultTable, $nodeIdTrHopList);
        }
	}
}

1;