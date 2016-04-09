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

package Utils::DetectionCode;

=pod

Helper functions for encoding/decoding the Detection Code

This is needed to create and decode the DetectionCode bitfield. 
e.g., some problems should be ignored if the contextSwtich flag is set  

=cut

# hash that maps problem codes to bits
# note the indexes start from 0 # need to fix this
my $bitMapping = {
    "delayProblem" => 1,
    "lossProblem" => 2,
    "contextSwitch" => 7,
};

# Map the problem code to associated tomography and metric. Also defines whether another condition invalidates the result
my $metricMapping = {
    "delayProblem" => {"tomography" => "range_sum", "metric" => "queueingDelay", "invalidatedBy" => "contextSwitch"},
    "lossProblem" => {"tomography" => "boolean", "metric" => "lossCount", "invalidatedBy" => undef},
};

# This is the function that sets the bits in the detection code bitfield
# Call this once per problem code
sub setDetectionCodeBit
{
    my ($detCode, $problemName, $value) = @_;

    return undef if (!exists($bitMapping->{$problemName}));

    # problem codes map to specific bits
    my $bitOffset = $bitMapping->{$problemName};
    
    if ($value > 0)
    {
#        print "Setting bit $bitOffset to 1\n";
        $detCode |= 1 << $bitOffset;
    }
    else
    {
#        print "Unsetting bit $bitOffset to 0\n";
        $detCode &= 0 << $bitOffset;
    }
    return $detCode;
}

# This is the function that gets the exact bit
sub getDetectionCodeBitRaw
{
    my ($detCode, $problemName) = @_;
    
    return undef if (!exists($bitMapping->{$problemName}));
    
    return ($detCode >> $bitMapping->{$problemName}) & 1;
}

# This gets you the bit if it is not invalidated by another 
sub getDetectionCodeBitValid
{
    my ($detCode, $problemName) = @_;
    
    return undef if (!exists($bitMapping->{$problemName}));
    
    return 0 if ($detCode == -1);
    
    my $rawProblemBit = ($detCode >> $bitMapping->{$problemName}) & 1;
    
    my $invalidBit = 0;
    if (exists($metricMapping->{$problemName}) && exists($metricMapping->{$problemName}{"invalidatedBy"}) && defined($metricMapping->{$problemName}{"invalidatedBy"}) )
    {
        $invalidBit = getDetectionCodeBitRaw($detCode, $metricMapping->{$problemName}{"invalidatedBy"});
        $invalidBit = 0 if (!defined($invalidBit));
    }
    return ($rawProblemBit & ($invalidBit == 0));
}

# This function gets the metric value corresponding to a problem
sub getDetectionCodeMetric
{
    my ($problemName) = @_;
    
    return undef if (!exists($metricMapping->{$problemName}));
    return $metricMapping->{$problemName}{"metric"};
}

sub getDetectionCodeTomography
{
    my ($problemName) = @_;
    
    return undef if (!exists($metricMapping->{$problemName}));
    return $metricMapping->{$problemName}{"tomography"};
}

1;