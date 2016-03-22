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
use Utils::TrHop;

=pod

Localization::Reporter

Handles the writing back of localization events to the appropriate backend

=cut


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

# Uses the backend submodule to write events, one per link, per event 
sub writeData
{
	my ($self, $startTime, $tomo, $detectionCode, $resultArray, $nodeIdTrHopList) = @_;
	
	my $val1;
	my $val2;
    foreach my $event (@{$resultArray})
    {
        if ($tomo eq "range_sum")
        {
            $val1 = int($event->{'range'}[0] * 10);
            $val2 = int($event->{'range'}[1] * 10);
        }
        
        if (!exists($nodeIdTrHopList->{$event->{'link'}}))
        {
            warn "Couldn't find $event->{'link'} in nodeIdTrHopList. Skipping ";
            next;
        }
        my $trHop = $nodeIdTrHopList->{$event->{'link'}};
        foreach my $hopInfo (@{$trHop->getRawList()})
        {
            $self->{"_rpt"}->writeData($startTime, $hopInfo->{'hopIp'}, $hopInfo->{'hopName'}, $detectionCode, $val1, $val2);
        }
    }
}

1;