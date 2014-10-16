#!perl -w

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

