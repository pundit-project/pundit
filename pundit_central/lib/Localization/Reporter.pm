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

package Loc::Reporter;

use strict;
require "loc_reporter_range.pl";
require "loc_reporter_bool.pl";

## debug. Remove this for production
#use Data::Dumper;
#require "loc_config.pl";
#my $cfg = new Loc::Config("localization.conf");

sub new
{
	my $class = shift;
    my $cfg = shift;
    
	# init the sub-receiver
	my $delay_rpt = new Loc::Reporter::Range($cfg, 'delayMetric');
	return undef if (!$delay_rpt);
	
	my $loss_rpt = new Loc::Reporter::Bool($cfg, 'lossMetric');
	return undef if (!$loss_rpt);
	
	my $reorder_rpt = new Loc::Reporter::Bool($cfg, 'reorderMetric');
	return undef if (!$reorder_rpt);
	
	my $self = {
        _config => $cfg,
        _delay_rpt => $delay_rpt,
        _loss_rpt => $loss_rpt,
        _reorder_rpt => $reorder_rpt,
    };
    
    bless $self, $class;
    return $self;
}

# Write to database
sub write_data
{
	my ($self, $metric, $start_time, $data_array) = @_;
	
	if ($metric eq 'delayMetric')
	{
		$self->{'_delay_rpt'}->write_data($start_time, $data_array);
	}
	elsif ($metric eq 'lossMetric')
	{
		$self->{'_loss_rpt'}->write_data($start_time, $data_array);
	}
	elsif ($metric eq 'reorderMetric')
	{
		$self->{'_reorder_rpt'}->write_data($start_time, $data_array);
	}  
}

1;

=pod
my $rpt = new Loc::Reporter($cfg);
my @data_array = (
	{
		'link' => "1.1.3.1",
		'range' => [2.5, 9.75],
	},
	{
		'link' => "1.1.4.2",
		'range' => [2.5, 6.75],
	}
);
$rpt->write_data(100, \@data_array);
=cut