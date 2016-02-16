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

use strict;

package LocalizationTraceroute::ParisTrParser;

my $debug = 0;

if ($debug == 1)
{
	use Data::Dumper;
}

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

1;

#my $out = `paris-traceroute www.google.com`;
#print Dumper parse($out);