#!perl -w
#
# Copyright 2015 Georgia Institute of Technology
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

# localization_traceroute_daemon.pl
#
# Periodically run to take traceroutes to the peers and store them in the central db
# This is a new multithreaded version

use strict;
use threads;
use Thread::Queue;
use Config::General;
use File::Basename;

use lib '../lib/';

# local modules
use PuNDIT::Agent::LocalizationTraceroute;
use PuNDIT::Utils::HostInfo;

# debug. remove this later
use Data::Dumper;

### tunable variables

# number of simultaneous threads
our $N //= 4;

### script variables

my $scriptPath = dirname(__FILE__);

my $cfg = $scriptPath . '/../etc/pundit-agent.conf';
my $fedName = '<federation-name-goes-here>'; # TODO: run this once per site

my %cfgHash = Config::General::ParseConfig($cfg);

# child process for threads to execute
# just creates the localizationTraceroute object and runs a trace for each element in the queue
sub child 
{
    my ($start_time, $host_id, $in_queue) = @_;
    
    my $tr_helper = new PuNDIT::Agent::LocalizationTraceroute(\%cfgHash, $fedName, $start_time, $host_id);
    while( my $peer = $in_queue->dequeue ) {
        $tr_helper->runTrace($peer);
    }
}

# Get the global vars
my $start_time = time();

# host id is fqdn or ip
my $host_id = PuNDIT::Utils::HostInfo::getHostId();

my $work_queue = new Thread::Queue;
my @child_threads = map threads->create( \&child, $start_time, $host_id, $work_queue ), 1 .. $N;

# grab the values from the config file, replace commas with spaces and split on spaces
my $peer_monitor_string = $cfgHash{"pundit-agent"}{$fedName}{"peers"};
$peer_monitor_string =~ s/,/ /g;
my @peer_monitors = split(/\s+/, $peer_monitor_string);

foreach my $peer (@peer_monitors) 
{
    $work_queue->enqueue( $peer );
}

## tell the kids to die
$work_queue->enqueue( ( undef ) x $N );

## And wait for kids to clean up
$_->join for @child_threads;

print "Finished at " . $start_time . "\n";
# singlethreaded version. NOT reliable
#foreach my $peer (@$myConfig::peer_monitors)
#{
#	print $peer;
#	my $tr_result = `paris-traceroute $peer`;
#    my $parse_result = paristr_parser::parse($tr_result);
#    print Dumper $parse_result;
#    store_trace_db($dbh, $parse_result);
#};
