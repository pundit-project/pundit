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

use strict;
use Config::General;

use FindBin qw( $RealBin );

use lib "$RealBin/../lib";

use Localization::Tomography;
use Utils::TrHop;
use Utils::DetectionCode;

# debug. Remove this for production
use Data::Dumper;

=pod

=head1 DESCRIPTION

This is a test library for verifying Tomography behaviour

=cut

my $configFile = $RealBin . "/../etc/pundit_central.conf";
my %cfgHash = Config::General::ParseConfig($configFile);
my $fedName = 'federation1';

my $tomo = new Localization::Tomography(\%cfgHash, $fedName);

# Y shaped topology
# Endpoints are A1 B1 C1
sub build_y_topology
{
    my $a1 = new Utils::TrHop('A1','1.1.1.1');
    my $b1 = new Utils::TrHop('B1','1.1.1.2');
    my $c1 = new Utils::TrHop('C1','1.1.1.3');
    my $da = new Utils::TrHop('D.A','1.1.1.4');
    my $db = new Utils::TrHop('D.B','1.1.1.5');
    my $dc = new Utils::TrHop('D.C','1.1.1.6');
    return {
        'A1' => {
                    'A1' => { 'src' => 'A1', 'dst' => 'A1', 'path' => [$a1,]},
                    'B1' => { 'src' => 'A1', 'dst' => 'B1', 'path' => [$da, $b1,]},
                    'C1' => { 'src' => 'A1', 'dst' => 'C1', 'path' => [$da, $c1,]},
        },
        'B1' => {
                    'A1' => { 'src' => 'B1', 'dst' => 'A1', 'path' => [$db,$a1,]},
                    'B1' => { 'src' => 'B1', 'dst' => 'B1', 'path' => [$b1,]},
                    'C1' => { 'src' => 'B1', 'dst' => 'C1', 'path' => [$db, $c1,]},
        },
        'C1' => {
                    'A1' => { 'src' => 'C1', 'dst' => 'A1', 'path' => [$dc, $a1,]},
                    'B1' => { 'src' => 'C1', 'dst' => 'B1', 'path' => [$dc, $b1,]},
                    'C1' => { 'src' => 'C1', 'dst' => 'C1', 'path' => [$c1,]},
        },
    };
}

my @evTable = (
    { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'queueingDelay' => 50, 'lossCount' => 1, 'detectionCode' => 3,},
    { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'queueingDelay' => 55, 'lossCount' => 1, 'detectionCode' => 3,},
);

my $refTime = time - 15;

my $trMatrix = build_y_topology();

$tomo->processTimeWindow($refTime, $trMatrix, \@evTable);