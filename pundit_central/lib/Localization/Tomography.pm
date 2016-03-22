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

package Localization::Tomography;

use strict;

# local modules
use Localization::Reporter; # for writing back to backend
use Localization::Tomography::Boolean; # Boolean Tomography
use Localization::Tomography::RangeSum; # Range Tomography - Sum
use Utils::DetectionCode; # used for problem code to tomography mapping
use Utils::TrHop; # used for extracting hop IDs

# debug
#use POSIX qw(floor);

=pod

=head1 DESCRIPTION

This module handles the tomography processing for the event tables and the input traceroutes

=cut

sub new
{
	my ($class, $cfgHash, $fedName) = @_;
    
	# init the subcomponents
	my $loc_reporter = new Localization::Reporter($cfgHash, $fedName);
	return undef if (!$loc_reporter);
	
	my $sum_tomo = new Localization::Tomography::RangeSum($cfgHash, $fedName);
	return undef if (!$sum_tomo);
	
	my $bool_tomo = new Localization::Tomography::Boolean($cfgHash, $fedName);
    return undef if (!$bool_tomo);
	
	my $problem_types_string = $cfgHash->{'pundit_central'}{$fedName}{'localization'}('problem_types');
	my @problem_types_list = split(/[\s+|,]/, $problem_types_string);
	
	my $window_size = $cfgHash->{'pundit_central'}{$fedName}{'localization'}('window_size');
	
	my $self = {
        '_loc_reporter' => $loc_reporter,
        '_sum_tomo' => $sum_tomo,
        '_bool_tomo' => $bool_tomo,
                
        # params
        _window_size => $window_size,
        _problem_types_list => \@problem_types_list,
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
	my ($self, $problemName, $ev_table) = @_;
	
	# Filter the events based on detectionCode flag, also renaming the metric field
	my @filtered_events = map { 
		(Utils::DetectionCode::getDetectionCodeBitValid($_->{'detectionCode'}, $problemName) == 1) 
		? 
		{
			'srchost' => $_->{'srchost'}, 
			'dsthost' => $_->{'dsthost'}, 
			'metric' => $_->{Utils::DetectionCode::getDetectionCodeMetric($problemName)} 
		} 
		: 
		() 
	} @$ev_table;
	
	return \@filtered_events;	
}


# Builds a set of all paths and links from the traceroute table
# Params:
# $tr_table - Reference to the TraceRoute table, an hash of hashes where $tr_table{src}{dst} = pathInfo
# Returns:
# $path_set - A hash of hashes %path_set{$src}{$dst} = bad/good value
# $link_set - A flat hash of all %link_set{$node} = bad/good value
# $trNodePath - List of node id to paths. Used for tomography algorithms 
# $nodeIdTrHopList - List of node_id to TrHop mappings. Used for lookup during reporting
sub _buildPathLinkSet
{
    my ($tr_table) = @_;
    
    my %path_set = ();
    my %link_set = ();
    my %trNodePath = ();
    my %nodeIdTrHopList = ();
    
    print Dumper $tr_table;
    while (my ($src, $dest_details) = each(%$tr_table))
    {
        while (my ($dst, $pathInfo) = each(%$dest_details))
        {
            # this is an arrayref of TrHops
            my $path = $pathInfo->{'path'};
            
            # Skip host-only tr
            next if (($src eq $path->[0]->getHopId()));
            
            # add an entry to path set with 0 bad links
            # we don't care about auto vivifying here
            $path_set{$src}{$dst} = 0;
            
            # now loop over the hops to add them to the link_set
            foreach my $trHop (@$path)
            {
                my $hopId = $trHop->getHopId();
        
                # skip stars
                next if ($hopId eq '*');
                
#                print "Adding $hopId with $src $dst \n";
                if ( !exists( $link_set{$hopId} ) )
                {
                    $link_set{$hopId} = 0;
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

    return (\%path_set, \%link_set, \%trNodePath, \%nodeIdTrHopList);
}

# Public interface
# Starts the localisation algorithm on a specific time window, traceroute matrix and event table
sub processTimeWindow 
{
	my ($self, $refTime, $trMatrix, $evTable) = @_;
	
	my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = _buildPathLinkSet($trMatrix);
	
	# Run for each enabled problem 
	foreach my $problemName (@{$self->{'_problem_types_list'}})
	{
		print "$problemName:\t";
		
		# keep events relevant only for the specific metric
		my $filtered_events = $self->_filterEvents($problemName, $evTable);
				
		# Optimisation. Skip tomography if 1 or fewer paths
		if (scalar($filtered_events) <= 1 || !$filtered_events)
		{
			print "1 or 0 events to process. Not enough info to localise. Skipping.\n";
			next;
		}
		
		# make a copy of the path_set and link_set so this run of the algorithm can modify it
		# These are 1 layer hashes to a direct shallow copy should work. 
		# If the struct changes later, use Storable dclone
		my %tomoPathSet = %{$path_set};
		my %tomoLinkSet = %{$link_set};
		    
        # Determine which algo corresponds to which tomography and run it
        my $tomo;
        my $tomo_type = Utils::DetectionCode::getDetectionCodeTomography($problemName);
        if ($tomo_type eq "range_sum")
        {
            $tomo = $self->{'_sum_tomo'};
        }
        elsif ($tomo_type eq "boolean")
        {
            $tomo = $self->{'_bool_tomo'};
        }
        if (!defined($tomo))
        {
            print "Error: undefined tomography type $tomo_type\n";
        }
        my $loc_result_table = $tomo->runTomo($filtered_events, $trMatrix, $trNodePath, \%tomoPathSet, \%tomoLinkSet);
        
        #print Dumper $loc_result_table;
        
        if (scalar(@{$loc_result_table}) > 0)
        {
            # generate a detectionCode with a single bit set, used for reporting
            my $detectionCode = Utils::DetectionCode::setDetectionCodeBit(0, $problemName, 1);
            
            # Store the table of results to db
            $self->{'_loc_reporter'}->writeData($tomo, $detectionCode, $refTime, $loc_result_table, $nodeIdTrHopList);
        }
	}
}

1;