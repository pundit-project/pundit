#!perl -w

use strict;

require 'congestion.pl';

my $LSDelayThreshold = 10; #ms
my $LSPtsFrac = 0.1;
my $prctileThresh = 2; #ms

sub searchRight
{
	my $ref = shift;
	my $baseline = shift;
	my $n = @$ref;

	my $rmin = $ref->[$n-1];
	#check high delay diff and min/max #pts
	my $c = 0;
	my $rightsch = 1;
	for($c = $n-2; $c >= 0; $c--)
	{
		my $d = $ref->[$c];
		$rmin = $d if $rmin > $d;
		last if ($rmin - $baseline) < $LSDelayThreshold;
	}
	my $nright1 = $n - ($c+1);
	$rightsch = 0 if $nright1 < $LSPtsFrac * $n or $nright1 > (1-$LSPtsFrac) * $n;

	#check if the other half is ok
	my $nok = 0;
	for($c = 0; $c < $n - $nright1; $c++)
	{
		$nok++ if $ref->[$c] - $baseline > $LSDelayThreshold;
	}
	$rightsch = 0 if $nok > $LSPtsFrac * ($n - $nright1);

	return ($rightsch, $nright1);
};

sub searchLeft
{
	my $ref = shift;
	my $baseline = shift;
	my $n = @$ref;

	my $rmin = $ref->[0];
	my $c = 0;
	my $leftsch = 1;
	for($c = 1; $c < $n; $c++)
	{
		my $d = $ref->[$c];
		$rmin = $d if $rmin > $d;
		last if ($baseline - $rmin) > $LSDelayThreshold;
	}
	my $nright2 = $n - ($c+1);
	$leftsch = 0 if $nright2 < $LSPtsFrac * $n or $nright2 > (1-$LSPtsFrac) * $n;

	#check if the other half is ok
	my $nok = 0;
	for($c = $n-1; $c >= $n - $nright2; $c--)
	{
		$nok++ if $ref->[$c] - $baseline > $LSDelayThreshold;
	}
	$leftsch = 0 if $nok > $LSPtsFrac * ($n - $nright2);

	return ($leftsch, $nright2);
};

sub levelShift
{
	my $ref = shift;
	my $baseline = shift;
	my $n = @$ref;

	my ($rightsch, $nright1) = searchRight($ref, $baseline);
	my ($leftsch, $nright2) = searchLeft($ref, $baseline);
#print "LS: $nright1 $nright2 $n\n";

	return 0 if $leftsch == 0 and $rightsch == 0;

	my $nright = ($leftsch == 1) ? $nright2 : $nright1;
	my @rightarr = @$ref[($n-$nright)..$n-1];
	my @leftarr = @$ref[0..($n-$nright-1)];

	#check low variance
	my @parr = (0.05, 0.90); #0.9 since the #pts is small
	my ($lowd, $highd) = prctileArr(\@rightarr, \@parr);
#print "LS: leftdiff: ".($highd-$lowd)."\n";
	return 0 if ($highd - $lowd) > $prctileThresh;

	#check low variance
	my ($lowd, $highd) = prctileArr(\@leftarr, \@parr);
#print "LS: rtdiff: ".($highd-$lowd)."\n";
	return 0 if ($highd - $lowd) > $prctileThresh;

	return 1;
};


1;

