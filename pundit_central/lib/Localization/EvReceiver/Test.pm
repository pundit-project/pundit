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

package Localization::EvReceiver::Test;

use strict;
use Data::Dumper;

my $windowSize = 5;
my $testHash = {
    'a' => {
        'd' => [{ 'startTime' => time, 'endTime' => time + $windowSize, 'srchost' => 'a', 'dsthost' => 'd', 'baselineDelay' => 10, 'detectionCode' => 0, 'queueingDelay' => 1, 'lossRatio' => 0, 'reorderMetric' => 0.0 },],
    },
    'b' => {
        'd' => [{ 'startTime' => time, 'endTime' => time + $windowSize, 'srchost' => 'b', 'dsthost' => 'd', 'baselineDelay' => 10, 'detectionCode' => 0, 'queueingDelay' => 1, 'lossRatio' => 0, 'reorderMetric' => 0.0 },],
    },
    'c' => {
        'd' => [{ 'startTime' => time, 'endTime' => time + $windowSize, 'srchost' => 'c', 'dsthost' => 'd', 'baselineDelay' => 10, 'detectionCode' => 0, 'queueingDelay' => 1, 'lossRatio' => 0, 'reorderMetric' => 0.0 },],
    },
};

sub new
{
    my ($class) = @_;
        
    my $self = {
        '_ret' => 0,
    };
    
    bless $self, $class;
    return $self;
}

# retrieves the latest values from the db
# formatted to match output format
sub getLatestEvents
{
    my ($self, $lastTS) = @_;
    
    
    
    # return the testarray on the first request
    if ($self->{'_ret'} != 1)
    {
        $self->{'_ret'} = 1;
        return $testHash;
    }
    else
    {
        return {};
    }
}
