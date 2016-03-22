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

require Localization::Localization;

use POSIX qw(setsid);

=pod

=head1 DESCRIPTION

This is the main entry point for the central server code.
Run this to start all subcomponents

=cut


# TODO: Take this on command line or use this as a default if not specified
my $configFile = $RealBin . "/../etc/pundit_central.conf";
my $fedName = "federation1"; # TODO: change this to support multiple federations

my %cfgHash = Config::General::ParseConfig($configFile);
my $logFile = $cfgHash{"pundit_central"}{"log"}{"filename"};

# Save the script path for libs to use
$cfgHash{"exePath"} = $RealBin;

umask 0;
open(STDIN, '/dev/null') or die "Can't read /dev/null: $!";
open(STDOUT, ">>", $logFile) or die "Can't write to $logFile: $!";
open(STDERR, ">>", $logFile) or die "Can't write to $logFile: $!";
defined(my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";

print "Starting server..\n";

# create the main class and run it
# TODO: We will should have 1 per federation
my $loc = new Localization(\%cfgHash, $fedName);
$loc->run;
