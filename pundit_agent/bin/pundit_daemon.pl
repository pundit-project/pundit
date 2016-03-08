#!perl -w
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

use Log::Log4perl qw(:easy);
use POSIX qw(setsid);
use Config::General;
use FindBin qw( $RealBin );

use lib "$RealBin/../lib";

use Detection::Detection;
use InfileScheduler::InfileScheduler;
use Utils::CleanOwamp;

# TODO: Take this on command line or use this as a default if not specified
my $configFile = $RealBin . "/../etc/pundit_agent.conf";

# do sanity check that the config file exists
if ( ! -e "$configFile" ) {
    warn " Configuration file $configFile doesn't exist. Refusing to run.\n";
    exit;
}

my %cfgHash = Config::General::ParseConfig($configFile);
my $logFile = $cfgHash{"pundit_agent"}{"log"}{"filename"};

umask 0;
open(STDIN, '/dev/null') or die "Can't read /dev/null: $!";
open(STDOUT, ">>", $logFile) or die;
open(STDERR, ">>", $logFile) or die "Can't write to logfile: $!";
defined(my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";

# Get the list of measurement federations
my $feds_string = $cfgHash{"pundit_agent"}{"measurement_federations"};
$feds_string =~ s/,/ /g;
my @federations = split(/\s+/, $feds_string);

# Save the script path for libs to use
$cfgHash{"exePath"} = $RealBin;

# TODO: Init one detection module per federation. Needs some way of differentiating the owamp files
my $detectionModule = new Detection(\%cfgHash, $federations[0]);
my $infileScheduler = new InfileScheduler(\%cfgHash, $detectionModule);

print "Starting server..\n";

# Clean old owamp files
my $cleanupThreshold = $cfgHash{"pundit_agent"}{"owamp_data"}{"cleanup_threshold"};
my $owampPath = $cfgHash{"pundit_agent"}{"owamp_data"}{"path"};  
Utils::CleanOwamp::cleanOldFiles($cleanupThreshold, $owampPath);

my $runLoop = 1;

while($runLoop)
{
    $infileScheduler->runSchedule();
    sleep(10);
}
