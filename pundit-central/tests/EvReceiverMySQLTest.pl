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

use PuNDIT::Central::Localization::EvReceiver::MySQL;

# debug. Remove this for production
use Data::Dumper;

=pod

=head1 DESCRIPTION

This is a test library for verifying EvReceiverMySQL behaviour

=cut

my $configFile = $RealBin . "/../etc/pundit_central.conf";
my %cfgHash = Config::General::ParseConfig($configFile);
my $fedName = 'federation1';

my $evRcv = new PuNDIT::Central::Localization::EvReceiver::MySQL(\%cfgHash, $fedName);

my $evHash = $evRcv->getLatestEvents(time - 60);
print Dumper($evHash);

