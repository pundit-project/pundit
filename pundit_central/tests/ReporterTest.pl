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

use PuNDIT::Central::Localization::Reporter;
use PuNDIT::Utils::TrHop;

# debug. Remove this for production
use Data::Dumper;

=pod

=head1 DESCRIPTION

This is a test library for verifying Reporter behaviour

=cut

my $configFile = $RealBin . "/../etc/pundit_central.conf";
my %cfgHash = Config::General::ParseConfig($configFile);
my $fedName = 'federation1';

my $reporter = new PuNDIT::Central::Localization::Reporter(\%cfgHash, $fedName);

my $eventsList =
[
    {
        'hopId' => "x",
        'range' => [2.5, 2.75],
    },    
    {
        'hopId' => "y_z",
        'range' => [2.5, 3.75],
    }
];

my $trHop1 = new PuNDIT::Utils::TrHop();
$trHop1->addHopEntry("x","1.1.2.1");
my $trHop2 = new Utils::TrHop();
$trHop2->addHopEntry("y","1.1.2.2");
$trHop2->addHopEntry("z","1.1.2.3");
my $nodeIdTrHopList = {
    "x" => $trHop1,
    "y_z" => $trHop2,
};

$reporter->writeData(time - 100, "boolean", 2, $eventsList, $nodeIdTrHopList);
$reporter->writeData(time - 50, "range_sum", 1, $eventsList, $nodeIdTrHopList);
