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

package Loc::Processor;

use strict;

require "tr_receiver.pl";
require "ev_receiver.pl";
require "loc_reporter.pl";
#require Loc::EvReceiver;

# put these into the config file later
require "algo_sum_tomo.pl";
require "algo_bool_tomo.pl";

# debug
use Data::Dumper;
#require Loc::Config;
#use POSIX qw(floor);

=pod

=head1 DESCRIPTION

This is the main entry point for the localisation processor.
This will take the output from the event and traceroute receivers and process them 

=cut

sub new
{
	my $class = shift;
    my $cfg = shift;
    
	# init the subcomponents
	my $ev_rcv = new Loc::EvReceiver($cfg);
	return undef if (!$ev_rcv);
#	my $tr_rcv = new Loc::EvReceiver($cfg);
#	return undef if (!$tr_rcv);
	my $loc_reporter = new Loc::Reporter($cfg);
	return undef if (!$loc_reporter);
	
	my $sum_tomo = new Loc::Tomo::Range::Sum($cfg);
	return undef if (!$sum_tomo);
	my $bool_tomo = new Loc::Tomo::Bool($cfg);
	return undef if (!$bool_tomo);
	
	my $metrics = $cfg->get_param('loc', 'metrics');
	my @metric_list = split(/[\s+|,]/, $metrics);
	
	my $window_size = $cfg->get_param('loc', 'window_size');
	my $tomography = $cfg->get_param('loc', 'tomography');
	
	my $self = {
        _config => $cfg,
        _ev_rcv => $ev_rcv,
        _loc_reporter => $loc_reporter,
        _sum_tomo => $sum_tomo,
        _bool_tomo => $bool_tomo,
                
        # params
        _window_size => $window_size,
        _tomography => $tomography,
        _metric_list => \@metric_list,
    };
    
    bless $self, $class;
    return $self;
}

sub DESTROY
{
	
}

sub filter_events
{
	my ($self, $metric, $ev_table) = @_;
	
	my $cfg = $self->{'_config'};
	my $threshold = $cfg->get_param($metric, 'threshold');
	
	# Filter the events based on metric and threshold, renaming the metric field
	my @filtered_events = map { 
		$_->{$metric} >= $threshold ? 
		{ 
			#'startTime' => $_->{'startTime'}, 
			'srchost' => $_->{'srchost'}, 
			'dsthost' => $_->{'dsthost'}, 
			'metric' => $_->{$metric} 
		} : 
		() 
	} @$ev_table;
	my $filtered_events_size = scalar(@filtered_events);
	
	return (\@filtered_events, $filtered_events_size);	
}

sub run_loc
{
	my ($self, $metric, $in_time, $event_table, $tr_matrix, $tr_node_list) = @_;
	
	my $cfg = $self->{'_config'};
	
	my $loc_result_table;
	
	# Just run the algo on the events
	if ($metric eq "delayMetric")
	{
		($loc_result_table) = $self->{'_sum_tomo'}->sum_tomo($event_table, $tr_matrix, $tr_node_list);
	}
	elsif  (($metric eq "lossMetric") || ($metric eq "reorderMetric"))
	{
		($loc_result_table) = $self->{'_bool_tomo'}->bool_tomo($event_table, $tr_matrix, $tr_node_list);
	}
	
	#print Dumper $loc_result_table;
	# Store the table of results to db
	$self->{'_loc_reporter'}->write_data($metric, $in_time, $loc_result_table);
	
	my $loc_result_count = scalar(@$loc_result_table);
	print "Wrote $loc_result_count events to db.\n";
	return;
}

# Starts the localisation algorithm on a specific time window
sub process_time 
{
	# input parameter is the time
	my ($self, $in_time) = @_;
		
	my $window_size = $self->{'_window_size'};
	my $tomography = $self->{'_tomography'};
	
	# Get the current updated traceroute matrix
	my ($tr_first, $tr_last, $tr_new_matrix, $tr_new_node_list) = get_tr_matrix($in_time - 60*15, 0);
#	if ($tr_first < $in_time) {
#		print "Traceroute matrix is too old. Doing nothing...\n";
#		return;
#	} 

	# grab the event table from db
	my ($ev_first, $ev_last, $ev_new_table) = $self->{'_ev_rcv'}->get_event_table($in_time, $in_time + $window_size);
	my $ev_table_size = scalar(@$ev_new_table);
	
	# Run for each enabled metric
	foreach my $metric (@{$self->{'_metric_list'}})
	{
		print "$metric:\t";
		
		my ($filtered_events, $filtered_events_size) = $self->filter_events($metric, $ev_new_table);
				
		# Optimisation. Skip if 1 or fewer paths
		if ($filtered_events_size <= 1 || !$filtered_events)
		{
			print "1 or 0 events to process. Not enough info to localise. Skipping.\n";
			next;
		}
		
		# Run the localisation
		$self->run_loc($metric, $in_time, $filtered_events, $tr_new_matrix, $tr_new_node_list);
	}
}

1;