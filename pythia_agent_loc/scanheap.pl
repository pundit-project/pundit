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


sub LEFT {
	my $i = shift;
	my $heapsize = shift;
	return (($i+1)<<1 > $heapsize) ? -1 : (($i+1)<<1)-1;
};
sub RIGHT {
	my $i = shift;
	my $heapsize = shift;
	return ((($i+1)<<1)+1 > $heapsize) ? -1 : ($i+1)<<1;
};

### heap element is a hash:
### TS: timestamp; FILE: filename

sub mincmp {
	my $a = shift;
	my $b = shift;
	return ($a->{TS} < $b->{TS}) ? 1 : 0;
};

sub heapify
{
	my $ref = shift;
	my $i = shift;
	my $heapsize = shift;
	my $cmpfunc = shift;

	my @arr = @$ref;
	my $largestindex = $i;

	my $l = LEFT($i, $heapsize);
	my $r = RIGHT($i, $heapsize);

	if($l != -1 and &$cmpfunc($arr[$l], $arr[$i]))
	{
		$largestindex = $l;
	}
	if($r != -1 and &$cmpfunc($arr[$r], $arr[$largestindex]))
	{
		$largestindex = $r;
	}

	if($largestindex != $i)
	{
		my $t = $arr[$largestindex];
		$ref->[$largestindex] = $ref->[$i];
		$ref->[$i] = $t;
#print "replaced in heapify: comparing $arr[$largestindex]->{TS} $arr[$i]->{TS}\n";
		heapify($ref, $largestindex, $heapsize, $cmpfunc);
	}
};

sub buildheap
{
	my $ref = shift;
	my $n = shift;
	my $heapsize = shift;
	my $cmpfunc = shift;

	for(my $c = ($n>>1)-1; $c >= 0; $c--)
	{
#print "heapify: $c\n";
		heapify($ref, $c, $heapsize, $cmpfunc);
	}
}

sub addElem
{
	my $ref = shift;
	my $eref = shift;

	my $n = push(@$ref, $eref);
	buildheap($ref, $n, $n, \&mincmp);
#print "heap 3 elem: $ref->[0]->{TS}  $ref->[1]->{TS}  $ref->[2]->{TS} \n" if $n >2;

	return $n;
};

sub popElem
{
	my $ref = shift;

	my $elem = shift(@$ref);
	my $n = @$ref;
	buildheap($ref, $n, $n, \&mincmp);

	return $elem;
};


1;

