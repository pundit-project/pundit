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

sub sinsert {
	my ( $ary, $val ) = @_;
	my ( $min, $max, $last, $i ) = ( 0, scalar @{$ary}, 0, 0 );
	my $n = $max;
	while(1) 
	{
		$i = floor(($min+$max)/2);
		last if $last == $i;
		$last = $i;
		if ( $ary->[$i] < $val ) {
			$min = $i;
		}
		elsif ( $ary->[$i] > $val ) {
			$max = $i;
		}
		else {
			# values are equal so we have a valid index
			last;
		}
	}
	$i++ if $i;   # for index 0 we want that, otherwise we want next position   
	$i++ if $n != 0 and $i != $n and $ary->[$i] < $val;
	splice @$ary, $i, 0, $val;
	return (
		$ary->[floor($n*0.75)]-$ary->[floor($n*0.25)], 
		$n+1,
		$ary->[$n]-$ary->[0]);
}

sub median {
	my $ref = shift;
	my $n = @$ref;
	return -1 if $n == 0;

	my @sarr = sort {$a <=> $b} @$ref;
	return ($n % 2 == 0) ? ($sarr[$n/2-1] + $sarr[$n/2])/2 : $sarr[($n-1)/2];
};

1;

