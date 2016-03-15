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

package Localization::Reporter;

use strict;
use Localization::Reporter::MySQL;

## debug. Remove this for production
#use Data::Dumper;

sub new
{
	my ($class, $cfgHash, $fedName) = @_;
    
	# init the sub-reporter
	my $subType = $cfgHash->{'pundit_central'}{$fedName}{'reporting'}{'type'};
    
    my $rpt;
    if ( $subType eq "mysql" )
    {
	   $rpt = new Localization::Reporter::MySQL($cfgHash, $fedName);
    }
	return undef if (!defined($rpt));
	
	my $self = {
        '_rpt' => $rpt,
    };
    
    bless $self, $class;
    return $self;
}

# Write to database
sub writeData
{
	my ($self, $start_time, $tomo, $detectionCode, $data_array) = @_;
	
    foreach my $event (@{$data_array})
    {
        $self->{"_rpt"}->writeData($start_time, $tomo, $detectionCode, $event);
	}
}

1;