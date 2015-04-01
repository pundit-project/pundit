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

my $binwidth = $ARGV[0];
chomp $binwidth;

open(IN, "ts.pdf") or die;

my $prev = -1;
my $cur = -1;
my $next = -1;

my $curmax = -1;
my $curdensity = 0;

while(my $line = <IN>)
{
	next if $line =~ /^"x" /;
	chomp $line;
	my @obj = split(/\s+/, $line);

	$next = $obj[2];

	if($prev != -1)
	{
		#minima
		if($prev > $cur and $next > $cur)
		{
			print "max $curmax density $curdensity\n";
			$curmax = $obj[1];
			$curdensity = 0;
		}
	}

	$curmax = $obj[1] if $curmax < $obj[1];
	$curdensity += $binwidth * $next;


	$prev = $cur;
	$cur = $next;
}

print "max $curmax density $curdensity\n";

close IN;

