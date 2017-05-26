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

use PuNDIT::Central::Localization::Reporter::MySQL;
use PuNDIT::Utils::TrHop;

# debug. Remove this for production
use Data::Dumper;

=pod

=head1 DESCRIPTION

This is a test library for verifying Reporter::MySQL behaviour

=cut

my $configFile = $RealBin . "/../etc/pundit_central.conf";
my %cfgHash = Config::General::ParseConfig($configFile);
my $fedName = 'federation1';

my $reporter = new PuNDIT::Central::Localization::Reporter::MySQL(\%cfgHash, $fedName);

$reporter->writeData(time - 100, "1.1.1.1", "a", 1, undef, undef);
$reporter->writeData(time - 50, "1.1.1.2", "b", 1, 25, 27.5);

