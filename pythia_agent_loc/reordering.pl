#!perl -w

use strict;
require 'sinsert.pl'; #for median()

my $minWndSize = 20; # 20 * 5s duration

my @reorderWnd = ();
my @reorderWndT = ();
my $reorderSum = 0;

sub addReorderWindow {
	my $rmetric = shift;
	my $twnd = shift;

	push(@reorderWnd, $rmetric);
	push(@reorderWndT, $twnd);
	$reorderSum += $rmetric;

	my $n = @reorderWnd;
	return (-1, -1) if $n <= 1;
	return ($reorderWndT[0], $reorderWndT[$n-1]);
};

sub printReorderArr {
	print "@reorderWnd\n";
};

sub checkReordering {
	return -1 if $reorderSum == 0; # NO reordering

	my $n = @reorderWnd;
	return -2 if $n == 0 or $n < $minWndSize;

	my @leftarr = @reorderWnd[0..floor(@reorderWnd/2)-1];
	my $nleft = @leftarr;
	my $med = median(\@leftarr);

	my $nGT = 0;
	for(my $c = $nleft; $c < $n; $c++)
	{
		$nGT++ if $reorderWnd[$c] > $med;
	}

	# test whether median of left half holds for the right half
	# one-sample proportion test: H0: no stationarity (p=0.5)
	# H1: non-stationarity (p!=0.5)
	# assumption: reordering samples are independent; reasonable sample size
	my $nright = $n - $nleft;
	my $p = $nGT/$nright;
	my $z = ($p-0.5) / sqrt( 0.5*(1-0.5)/$nright );

	@reorderWnd = ();
	@reorderWndT = ();
	$reorderSum = 0;

	return (abs($z) > 1.96) ? # 95% significance
		1 : 0; # 1: reordering instability; 0: reordering persistence
};

sub reorderExist {
	return -1 if $reorderSum == 0; # NO reordering
	my $n = @reorderWnd;
	return -2 if $n == 0 or $n < $minWndSize;
	return 1;
};


1;

