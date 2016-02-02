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
use DBI qw(:sql_types);

# local modules
use dbConfig;
use myConfig;
use paristr_parser;

# debug. remove this later
use Data::Dumper;

# tunable variables

# number of simultaneous threads
our $N //= 4;

# This idea was stolen from Net::Address::IP::Local::connected_to()
sub get_local_ip_address {
    use IO::Socket::INET;
    
    my $socket = IO::Socket::INET->new(
        Proto       => 'udp',
        PeerAddr    => '198.41.0.4', # a.root-servers.net
        PeerPort    => '53', # DNS
    );

    # A side-effect of making a socket connection is that our IP address
    # is available from the 'sockhost' method
    my $local_ip_address = $socket->sockhost;

    return $local_ip_address;
}

sub get_hostname
{
#    use Net::Domain qw(hostfqdn);
#      
#    return hostfqdn();    
    
    use Sys::Hostname;
    
    return hostname();
}

# child process for threads to execute
# currently does the traceroute, and then inserts into db
sub child {
    my ($start_time, $host_id, $in_queue) = @_;

    # perl's DBI is NOT thread-safe. As a result just inefficiently use 1 session per thread
    my $dbh = DBI->connect("DBI:mysql:$dbConfig::database:$dbConfig::host:$dbConfig::port", $dbConfig::user, $dbConfig::pw) or die
                "cannot connect to DB";
    while( my $peer = $in_queue->dequeue ) {
        my $tr_result = `paris-traceroute $peer`;
        my $parse_result = paristr_parser::parse($tr_result);
        store_trace_db($dbh, $start_time, $host_id, $parse_result);
    }
    $dbh->disconnect;
}

# formats the parsed traceroute into the db format and stores it
sub store_trace_db
{
    my ($dbh, $start_time, $host_id, $trace_hash) = @_;
    print "storing...\n";
    my $sth = $dbh->prepare("INSERT INTO traceroutes ( ts, src, dst, hop_no, hop_ip, hop_name ) VALUES (?, ?, ?, ?, ?, ?)");
    $sth->bind_param(1, $start_time, SQL_INTEGER);
    $sth->bind_param(2, $host_id, SQL_VARCHAR);
    $sth->bind_param(3, $trace_hash->{'dest_name'}, SQL_VARCHAR);
    foreach my $hop (@{$trace_hash->{'path'}})
    {
        #$dbh->execute([$start_time, $local_ip, $trace_hash->{'dest_ip'}, $hop->{'hop_count'}, $hop->{'hop_ip'}, $hop->{'hop_name'}]);
        $sth->bind_param(4, $hop->{'hop_count'}, SQL_INTEGER);
        $sth->bind_param(5, $hop->{'hop_ip'}, SQL_VARCHAR);
        $sth->bind_param(6, $hop->{'hop_name'}, SQL_VARCHAR);
        $sth->execute;
    }
}



# Get the global vars
my $start_time = time();

# host id is fqdn or ip
my $host_id = get_hostname();
if (!$host_id)
{
    $host_id = get_local_ip_address();    
}

my $work_queue = new Thread::Queue;
my @child_threads = map threads->create( \&child, $start_time, $host_id, $work_queue ), 1 .. $N;

foreach my $peer (@$myConfig::peer_monitors) 
{
    $work_queue->enqueue( $peer );
}

## tell the kids to die
$work_queue->enqueue( ( undef ) x $N );

## And wait for kids to clean up
$_->join for @child_threads;

# singlethreaded version. NOT reliable
#foreach my $peer (@$myConfig::peer_monitors)
#{
#	print $peer;
#	my $tr_result = `paris-traceroute $peer`;
#    my $parse_result = paristr_parser::parse($tr_result);
#    print Dumper $parse_result;
#    store_trace_db($dbh, $parse_result);
#};
