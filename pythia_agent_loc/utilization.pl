#!perl -w

use strict;

my $minBurstDuration = 0.5; #s
my $burstinessDurRatio = 0.7;


sub utilization {
	my $dref = shift;
	my $tref = shift;
	my $baseline = shift;

	my $dthresh = $baseline + 1; #ms

	#TODO: return largest time window of high-util points

	my $n = @$dref;
	my $un = 0;
	my $congstart = -1;
	my $congend = -1;
	my @congdurations = ();
	my $congmax = -1;
	my $congsum = 0;
	for(my $c = 0; $c < $n; $c++)
	{
		my $d = $dref->[$c]; #ms
		my $t = $tref->[$c]; #ms
		if($d > $dthresh)
		{
			$un++;
			$congstart = $t if $congstart == -1;
			$congend = $t;
		}
		else
		{
			my $dur = $congend-$congstart;
			if($congstart != -1 and $dur > $minBurstDuration) #s
			{
				push(@congdurations, $dur);
				$congmax = $dur if $congmax < $dur;
				$congsum += $dur;
			}
			$congstart = -1;
		}
	}

print STDERR "UTIL-episodes: @congdurations congmax $congmax congsum $congsum\n";
	my $bursty = ($congmax < $burstinessDurRatio*$congsum) ? 1 : 0;

	return ($n != 0) ? ($un/$n, $bursty) : (-1,-1);
};

1;

