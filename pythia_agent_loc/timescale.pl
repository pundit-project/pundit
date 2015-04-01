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
use POSIX qw(floor);

my $tscale = $ARGV[0]; #30; #s

sub sum
{
	my ($arrayref) = @_;
	my $result;
	foreach(@$arrayref) { $result+= $_; }
	return $result;
}
my $mean = -1;
sub Mean {
	my ($arrayref) = @_;
	my $result;
	foreach (@$arrayref) { $result += $_ }
	return $result / @$arrayref;
}
sub variance
{
	return (sum [ map { ($_ - $mean)**2 } @{$_[0]}  ] ) / $#{$_[0]};
}


my $start = `cat planet1.cs.rochester.edu-planetlab1.di.fct.unl.pt | head -1 | cut -d ' ' -f 3`;
chomp $start;

open(IN, "planet1.cs.rochester.edu-planetlab1.di.fct.unl.pt") or die;
my @arr = ();
my @vararr = ();
my $oldb = -1;
while(my $line = <IN>)
{
	chomp $line;
	my @obj = split(/\s+/, $line);

	next if $obj[0] > 0.7;

	my $t = $obj[2] - $start;
	my $bkt = floor($t/$tscale);
	$oldb = $bkt if $oldb == -1;

	if($bkt != $oldb)
	{
		$mean = Mean(\@arr);
		#print "var ".variance(\@arr);
		push(@vararr, variance(\@arr));
		@arr = ();
		$oldb = $bkt;
	}
	push(@arr, $obj[1]);
}

my $idxMax = 0;
$vararr[$idxMax] > $vararr[$_] or $idxMax = $_ for 1 .. $#vararr;
my $st = $idxMax * $tscale; my $et = ($idxMax + 1) * $tscale;
print "interval $st $et\n";
`sh plottimescale.sh $st $et`;


close IN;

