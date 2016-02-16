#!perl -w
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

use strict;

use POSIX qw(setsid);
use Config::General;
use FindBin qw( $RealBin );

use lib "$RealBin/lib";

use Detection::Detection;
use InfileScheduler::InfileScheduler;

# TODO: Take this on command line or use this as a default if not specified
my $configFile = $RealBin . "/etc/pundit_agent.conf";

umask 0;
open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
open(STDOUT, ">>run.log") or die;
open STDERR, '>>run.log' or die "Can't write to /dev/null: $!";
defined(my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";

# Get the list of sites
my %cfgHash = Config::General::ParseConfig($configFile);
my $sites_string = $cfgHash{"pundit_agent"}{"sites"};
$sites_string =~ s/,/ /g;
my @sites = split(/\s+/, $sites_string);

# Save the script path for libs to use
$cfgHash{"exePath"} = $RealBin;

# TODO: Init one per site
my $detectionModule = new Detection(\%cfgHash, $sites[0]);
my $infileScheduler = new InfileScheduler(\%cfgHash, $detectionModule);

print "Starting server..\n";

# run this only on startup
`perl cleanowamp.pl >> run.log 2>&1`;

while(1)
{
    $infileScheduler->runSchedule();
    sleep(1);
}
