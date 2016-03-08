#!/usr/bin/perl
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

package paristr_parser;

# Parses the output of paris traceroute into a path
sub parse
{
	# helper functions
	sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }; # Trim leading and trailing spaces
	
	my $firstline = 0;
	my ($tr_text) = @_;
	my @path = ();
	
	my @lines = split /^/, $tr_text;
	foreach my $line (@lines) 
	{
		# skip the first line
		if ($firstline == 0) 
		{
			$firstline = 1;
			next;	
		}
		$line = trim $line;
		
		#print $line;
		
		# loop over each hop in the traceroute 
		# and choose the most likely hop for each
		my @elems = split /\s+/, $line;
		my $hop = undef;
		my %tmp_hash = ();
		my $curr_hop = undef;
		foreach my $elem (@elems)
		{
			# skip stars and hop numbers
			if ($elem =~ /^\*$/)
			{
				$curr_hop = '*';
				next;
			} 
			elsif ($elem =~ /^\d*$/)
			{
				next;
			}
			elsif ($elem =~ /^\d.*ms$/)
			{
				if (exists $tmp_hash{$curr_hop}) 
				{
					$tmp_hash{$curr_hop}++;
				}
				else
				{
					$tmp_hash{$curr_hop} = 1;
				}
			}
			elsif ($elem =~ /^\(.*\)$/)
			{
				# ip address. Separated as we might want to use this later
				#print "IP address $elem\n";
				next;
			}
			else
			{
				$curr_hop = $elem;
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
			#print "pushing " . $hop . "on path\n";
			push(@path, $hop);
		}
		#print "\n";
	}
	return \@path;
}

1;

#require Data::Dumper;
#my $out = `paris-traceroute www.google.com`;
#print Dumper parse($out);