#!perl -w

use strict;
use ExtUtils::testlib;
use GaussianKernelEstimate;

my @array = (1 .. 2000000);
my $n = @array;

my $s = GaussianKernelEstimate::getKernelEstimate(100.5, \@array, 10.12, $n);
my $t = 0; #getsum(100.5, \@array, 10.12, $n);

print "$s $t\n";  #  produces output: "210 210\n"


sub getsum {
	my $x = shift;
	my $ref = shift;
	my $h = shift;
	my $n = shift;

	my @arr = @$ref;
	my $est = 0;
	for(my $c = 0; $c < $n; $c++)
	{
		$est += 2.71828183 ** (-(($x - $arr[$c])**2) / (2*$h*$h));
	}
	$est /= sqrt(2*3.14159265);
	$est /= ($n * $h);

	return $est;
};

