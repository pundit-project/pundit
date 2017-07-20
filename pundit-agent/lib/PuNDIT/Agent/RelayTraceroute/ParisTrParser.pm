#!perl -w
#
# Copyright 2017 University of Michigan
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

package PuNDIT::Agent::RelayTraceroute::ParisTrParser;

use strict;
use Socket;
use Time::Local;
use Log::Log4perl qw(get_logger);

my $logger = get_logger(__PACKAGE__);
my $debug = 0;

if ($debug == 1)
{
        use Data::Dumper;
}

# Parses the output of paris traceroute (from pscheduler) into a path
sub parse
{

        my ($msg) = @_;

        # output variables
        my $dest_hn = $msg->{'measurement'}{'test'}{'spec'}{'dest'};
        my $dest_ip;
        my $reached_flag = 0;
        my @path = ();
        my @path_extract = $msg->{'measurement'}{'result'}{'paths'};
        my $start_time = $msg->{'measurement'}{'schedule'}{'start'};

        my @addresses = gethostbyname($dest_hn);
        my @ips = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
        $dest_ip = @ips[0];

        my $hop_count = 0;
        # $path_extract[0][0] is an array of hashes
        # each hash contains the info about each hop
        # pscheduler sends an {} for a hop with no reply (*)
        foreach my $each_hash (@{$path_extract[0][0]}) {
        #ip
                $hop_count++;
                my $h_ip = undef;
                my $h_name = undef;
	        if (!!%{$each_hash}){
	            $logger->debug("no reply for the hop");
	            $h_ip = '*';
	            $h_name = '*';
	        }
		else {
			$h_ip = ${\%{$each_hash}}{'ip'};

	                if (${\%{$each_hash}}{'hostname'} eq undef) {
        	                $h_name = $h_ip;
	                }
	                else {
	                        $h_name = ${\%{$each_hash}}{'hostname'};
	                }
		}

                push @path, { 'hop_count' => $hop_count, 'hop_name' => $h_name, 'hop_ip' => $h_ip };
                #print ("$hop_count $h_name $h_ip \n");
        }
        # pscheduler determines whether the traceroute test was successful or not
        # includes this info in the json.
        my $success = $msg->{'measurement'}{'result'}{'succeeded'};
        if ($success eq 'true') {
                $reached_flag = 1;
        }

        return {'ts' => $start_time, 'dest_name' => $dest_hn, 'dest_ip' => $dest_ip, 'reached' => $reached_flag, 'path' => \@path };
}

1;

#my $out = `paris-traceroute www.google.com`;
#print Dumper($out);
#print Dumper(parse($out));
