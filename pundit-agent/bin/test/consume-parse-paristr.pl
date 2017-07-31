#!/usr/bin/perl -w
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

package PuNDIT::Agent::LocalizationTraceroute::ParisTrParser;

use strict;
use FindBin qw( $RealBin );
use lib "$RealBin/../../lib";
use Config::General;
use JSON qw (decode_json); 
use Data::Dumper;
use PuNDIT::Agent::Messaging::Topics;
use Socket;

# Parses the output of paris traceroute into a path
sub parse
{
	# helper functions
	sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }; # Trim leading and trailing spaces
	
	my $firstline = 0;
	
	# output variables
	my $dest_hn; 
	my $dest_ip;
	my $reached_flag = 0;
	my @path = ();
	
	my ($tr_text) = @_;
	my @lines = split /^/, $tr_text;
	
	foreach my $line (@lines) 
	{
		$line = trim $line;
		
		# parse the first line. Format:
		# traceroute to psum09.cc.gt.atl.ga.us (143.215.129.69), 30 hops max, 30 bytes packets
		if ($firstline == 0) 
        {
            if ($line =~ /^traceroute to (.*) \(([\d|\.]*)\), .* hops max, .* bytes packets$/)
            {
                $firstline = 1;
                $dest_hn = $1;
                $dest_ip = $2;
                
                next;
            }
            else
            {
                print "Error: Didn't get the first line in traceroute. Got \'$line\'\n";
                return undef;
            }
        }
		
		#print $line;
		
		# loop over each hop in the traceroute 
		# and choose the most likely hop for each
		my @elems = split /\s+/, $line;
		my $hop = undef;
		my $hop_count = undef;
		my %tmp_hash = ();
		my $hop_ip;
		my $hop_hn;
		my $curr_hop = undef;
		my $stars_flag = 0;
		foreach my $elem (@elems)
		{
			# skip stars and hop numbers
			if ($elem =~ /^\*$/)
			{
				$stars_flag = 1;
				next;
			}
			elsif ($elem =~ /^\d*$/)
			{
				$hop_count = $elem;
				next;
			}
			elsif ($elem =~ /^\d.*ms$/)
			{
				$curr_hop = $hop_hn . "_" . $hop_ip;
				if (exists $tmp_hash{$curr_hop}) 
				{
					$tmp_hash{$curr_hop}++;
				}
				else
				{
					$tmp_hash{$curr_hop} = 1;
				}
			}
			elsif ($elem =~ /^\((.*)\)$/)
			{
				# ip address. Separated as we might want to use this later
				#print "IP address $elem\n";
				$hop_ip = $1;
				next;
			}
			else
			{
				$hop_hn = $elem;
				#print "curr_hop = $elem\n";
			}			
		}
		# voting for the most likely hop
		if (keys %tmp_hash)
		{
			my $max_key;
			my $max_value = -1;
			while ((my $key, my $value) = each %tmp_hash) {
			  if ($value > $max_value) {
			    $max_value = $value;
			    $max_key = $key;
			  }
			}
			#print "max_key = $max_key\n";
			$hop = $max_key;
		}
		if ($hop)
		{
			my ($h_name, $h_ip) = split("_", $hop); 
			push @path, { 'hop_count' => $hop_count, 'hop_name' => $h_name, 'hop_ip' => $h_ip };
		}
		elsif ($stars_flag)
		{
			push @path, { 'hop_count' => $hop_count, 'hop_name' => '*', 'hop_ip' => '*'};
		}
		#print "\n";
	}
	$reached_flag = 1 if ($path[-1]{'hop_ip'} eq $dest_ip);
	return { 'dest_name' => $dest_hn, 'dest_ip' => $dest_ip, 'reached' => $reached_flag, 'path' => \@path };
}

# Parses the output of paris traceroute (from pscheduler) into a path
sub parse_for_pscheduler
{

	my ($msg) = @_;

        # output variables
        my $dest_hn;
        my $dest_ip;
        my $reached_flag = 0;
        my @path = ();
	my @path_extract = $msg->{'measurement'}{'result'}{'paths'};

	$dest_hn = $msg->{'measurement'}{'test'}{'spec'}{'dest'};
	my @addresses = gethostbyname($dest_hn);
	my @ips = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
	$dest_ip = @ips[0];

        my $hop_count = 0;
	foreach my $each_hash (@{$path_extract[0][0]}) {
        #ip
        	$hop_count++;	
        	my $h_ip = ${\%{$each_hash}}{'ip'};
		my $h_name = undef;
		if (${\%{$each_hash}}{'hostname'} eq undef) {
			$h_name = "null";
		}
		else {
			$h_name = ${\%{$each_hash}}{'hostname'}; 
		}
        	push @path, { 'hop_count' => $hop_count, 'hop_name' => $h_name, 'hop_ip' => $h_ip };
		print ("$hop_count $h_name $h_ip \n");
        }
        # pscheduler determines whether the traceroute test was successful or not
        # includes this info in the json.
        my $success = $msg->{'measurement'}{'result'}{'succeeded'};
        if ($success eq 'true') {
                $reached_flag = 1;
        }

        return { 'dest_name' => $dest_hn, 'dest_ip' => $dest_ip, 'reached' => $reached_flag, 'path' => \@path };
}

=head2 parseConfig($cfgPath);
Simple configuration parser
=cut
sub parseConfig
{
    my ($configFile) = @_;
    my %cfgHash = Config::General::ParseConfig($configFile);

    # do sanity check that the config file exists
    if ( ! -e "$configFile" || !%cfgHash) {
        return (-1, undef);
    }
    
    return (0, \%cfgHash);    
}
1;


my $CONFIG_FILE = "/opt/pundit-agent/etc/pundit-agent.conf";
my ($status, $cfgHash) = parseConfig($CONFIG_FILE);
if ($status != 0) {
    print "Problem parsing configuration file: $CONFIG_FILE. Quitting.\n";
    exit(-1);
}
# Incoming data flow through RabbitMQ from pscheduler
my $user = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"user"};  
my $password = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"password"};
my $host = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"queue_host"};
my $exchange = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"exchange"};
my $routing_key = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"routing_key"};
my $channel = 1;
my $queue = "";
my $mq = set_bindings( $user, $password, $channel, $exchange, $queue, $routing_key ); 
print ("set_bindings to pscheduler successful");

my $sampleParisTrDatum = '{"measurement": {"schedule": {"duration": "PT25S", "start": "2017-07-12T11:18:48-04:00"}, "tool": {"version": "1.0", "name": "paris-traceroute"}, "participants": ["punditdev3.aglt2.org"], "result": {"paths": [[{"ip": "192.41.230.1", "as": {"owner": "MERIT-AS-6 - Merit Network Inc., US", "number": 229}, "hostname": null, "rtt": "PT0.003811S"}, {"ip": "198.124.80.53", "as": {"owner": "ESNET-EAST - ESnet, US", "number": 291}, "hostname": "esnet-lhc1-a-aglt2.es.net", "rtt": "PT0.006385S"}, {"ip": "198.124.80.85", "as": {"owner": "ESNET-EAST - ESnet, US", "number": 291}, "hostname": "esnet-lhc1-uiuc.es.net", "rtt": "PT0.005999S"}, {"ip": "198.124.80.86", "as": {"owner": "ESNET-EAST - ESnet, US", "number": 291}, "hostname": "uiuc-lhc1-esnet.es.net", "rtt": "PT0.008701S"}, {"ip": "130.126.1.110", "as": {"owner": "UIUC - University of Illinois, US", "number": 38}, "hostname": null, "rtt": "PT0.017606S"}, {"ip": "72.36.96.16", "as": {"owner": "UIUC - University of Illinois, US", "number": 38}, "hostname": "mwt2-ps04.campuscluster.illinois.edu", "rtt": "PT0.008725S"}]], "succeeded": true, "schema": 1}, "test": {"type": "trace", "spec": {"dest": "mwt2-ps04.campuscluster.illinois.edu", "source": "punditdev3.aglt2.org", "ip-version": 4, "schema": 1}}, "id": "d6378eae-ef4d-4879-9528-73384706ff9f"}}';

# Consume loop
while ( my $payload = $mq->recv() ) {
        my $msg = decode_json($payload->{body});
 	my $toolname = $msg->{'measurement'}{'tool'}{'name'};
	if ($toolname eq "paris-traceroute"){
		print(Dumper(parse_for_pscheduler($msg))); 
	}
}


#my $out = `paris-traceroute www.google.com`;
#print Dumper($out);
#print Dumper(parse($out));

# close connection
$mq->disconnect();

