#!perl -w

use strict;
use lib '.';
use GaussianKernelEstimate;

use myConfig;
require 'erfc.pl';

sub DoubleGT { # test if a > b
	my $a = shift;
	my $b = shift;

	my $DPRECISION = 1.0e-6;

	my $diff = $a - $b;
	return 0 if abs($diff) < $DPRECISION; #a == b
	return 1 if $diff > 0;
	return 0;
}

sub minimum {
	my $x = shift;
	my $y = shift;
	return ($x < $y) ? $x : $y;
};

sub getBW { # Silverman's rule of thumb
	my $IQR = shift;
	my $n = shift;

	return (0.79 * $IQR)/($n ** 0.2);
};

sub getKernelEstimate2 { #unused: replaced by native code
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


my $binwidth = $minBinWidth; #ms

sub getLowMode {
	my $ref = shift;
	my $h = shift;
	my $n = shift;

	my @arr = @$ref;
	my $min = $arr[0]; # assume in ms.
	my $max = $arr[$n-1];

	$binwidth = 0.1;
	my $nbkts = ($max - $min)/$binwidth; # buckets of 100us
	#ensure atleast 100 buckets
	$binwidth = ($max - $min)/100 if $nbkts < 50;

	#my $rden = getRangeDensity($ref, $h, $n);

	my $prev = -1;
	my $cur = -1;
	my $next = -1;
	my $curmax = -1;
	my $curdensity = 0;
	my $modeStart = $min;


#print STDERR "n $n nbkts $nbkts, min $min max $max bw $h binwidth $binwidth\n";
#my $sum = 0;
	my $x = 0;
	for($x = $min-$binwidth; $x <= $max+$binwidth; $x += $binwidth)
	{
		my $pdf = GaussianKernelEstimate::getKernelEstimate($x, $ref, $h, $n);
#print "estimate $x -> $pdf\n";
		$next = $pdf;

		if($prev != -1)
		{
			#minima
			#if($prev > $cur and $next > $cur)
			if(DoubleGT($prev, $cur) and DoubleGT($next, $cur))
			{
				#my $delta = 3 * $h;
				my $delta = 1.96 * $h;
				#my $rcurdensity = $curdensity/$rden;
#print STDERR "DENSITY: max $curmax delta $delta density $curdensity  rangeDensity $rden r-scaled $rcurdensity\n";
#print STDERR "DENSITY: max $curmax delta $delta density $curdensity\n";

				#XXX: consider ONLY lowest mode
				#last if $curdensity > 0.5;
				last;

				$curmax = $x;
				$curdensity = 0;
				$modeStart = $x;
			}
		}

		$curmax = $x if $pdf > $cur; #$curmax < $x;
		$curdensity += $binwidth * $next;

		$prev = $cur;
		$cur = $next;

#$sum += 0.1 * getKernelEstimate($x, $ref, $h, $n);
	}
#print "area $sum\n\n";

	#TODO: what should be this threshold during a problem?
	#return ($curdensity > $baseDensityThresh) ? ($curmax,$x, $modeStart) : (-1,-1,-1);
	return ($curmax,$x,$modeStart,$curdensity);
};


sub getHighMode {
	my $ref = shift;
	my $h = shift;
	my $n = shift;
	my $lowModeEnd = shift;

	return $minProbDelay if $lowModeEnd > $minProbDelay;

	my @arr = @$ref;
	my $min = $arr[0]; # assume in ms.
	my $max = $arr[$n-1];
	my $nbkts = ($max - $min)/$binwidth; # buckets of 100us

	my $prev = -1;
	my $cur = -1;
	my $next = -1;
	my $curmax = -1;
	my $curdensity = 0;

	return $max+$binwidth if minimum($minProbDelay, $max) < $lowModeEnd;

	for(my $x = minimum($minProbDelay, $max)+$binwidth; 
		$x >= $lowModeEnd+$binwidth; $x -= $binwidth)
	{
		my $pdf = getKernelEstimate($x, $ref, $h, $n);
		$next = $pdf;

		if($prev != -1)
		{
			#minima
			if($prev > $cur and $next > $cur)
			{
print STDERR "minima $curmax area $curdensity\n";
				last if $curdensity > 0.05;
				$curmax = $x;
				$curdensity = 0;
			}
		}

		$curmax = $x if $pdf > $cur; #$curmax < $x;
		$curdensity += $binwidth * $next;

		$prev = $cur;
		$cur = $next;
	}

print STDERR "right: $curmax  lowModeEnd $lowModeEnd\n\n";
	return $curmax;
};


sub getRangeDensity {
	my $ref = shift;
	my $h = shift;
	my $n = shift;

	my @arr = @$ref;
	my $min = $arr[0]; # assume in ms.
	my $max = $arr[$n-1];

	my $estmin = 0;
	my $estmax = 0;
	for(my $c = 0; $c < $n; $c++)
	{
		$estmin += normcdf($min, $arr[$c], $h);
		$estmax += normcdf($max, $arr[$c], $h);
	}

	return ($estmax - $estmin)/$n;
};


1;

