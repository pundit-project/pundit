#!perl -w

use strict;
require 'sinsert.pl';

my $csDIncreaseThresh = 300; #ms
sub contextSwitch {
	my $ref = shift;
	my $tref = shift;
	my $baseline = shift;
	my $n = @$ref;

	return -1 if $n == 0;

	#TODO: account for lost packets
	my $ncs = 0;
	my $oldd = $ref->[0];
	my $startT = -1; my $endT = -1; my $npackets = 0;
	my $endc = -1;
	for(my $c = 1; $c < $n; $c++)
	{
		my $d = $ref->[$c];
		if($d - $oldd > $csDIncreaseThresh) #ms
		{
			$ncs++;
			$startT = $tref->[$c]+$d*1e-3; $npackets = 0;
		}
		if($startT != -1 and $endT == -1 and $d < $baseline*1.2)
		{
			$endT = $tref->[$c-1]+$oldd*1e-3; $endc = $c-1;
		}
		$oldd = $d;
		$npackets++ if $startT != -1 and $endT == -1;
	}

	my $recvrate = ($endT != $startT and $endT != -1) ? 
			floor($npackets * (14+28) * 0.008 / ($endT - $startT)) : -1;
	$npackets--; $endT = $tref->[$endc-1]+$ref->[$endc-1]*1e-3;
	my $recvrate2 = ($endT != $startT and $endT != -1 and $npackets > 2) ? 
			floor($npackets * (14+28) * 0.008 / ($endT - $startT)) : -1;
	$recvrate = $recvrate2 if $recvrate2 > $recvrate;

	return ($ncs == 0 or $ncs/$n > 0.1) ? (0, $recvrate) 
				: (1, $recvrate);
};


sub hostNoise {
	my $ref = shift;
	my $tref = shift;
	my $baseline = shift;
	my $n = @$ref;

	my $diff = 0;
	my $d = 0; my $nd = 0;
	my $mind = 0xFFFFFFF;
	for(my $c = 1; $c < $n; $c++)
	{
		my $od = $ref->[$c-1];
		next if $od < $baseline + 1;
		$diff += abs($od - abs($ref->[$c] - $od));
		$d += $od; $nd++;
		$mind = $od if $mind > $od;
	}

	return -1 if $nd == 0; #not diagnosable

	$diff /= ($nd);
	$d -= $mind; $d /= ($nd);
	print STDERR "ENDHOST-noise: diff $diff d $d\n";

	return ($d > 2 * $diff) ? 1 : 0; # 1: endhost; 0: otherwise
};


my $ntpDiffThresh = 3; #ms
sub NTPshift {
	my $ref = shift;
	my $tref = shift;
	my $n = @$ref;

	# we assume very few NTP syncs in event
	# we do not assume skew compensation - we compute
	#   skew below
	my @slopes = ();
	my $startt = $tref->[0];
	my $oldsnd = 1e3*($tref->[0]-$startt);
	my $oldrcv = $ref->[0] + $oldsnd;
	for(my $c = 1; $c < $n; $c++)
	{
		my $snd = 1e3*($tref->[$c]-$startt);
		my $rcv = $ref->[$c] + $snd;
		if($snd - $oldsnd != 0)
		{
			my $slope = ($rcv - $oldrcv)/($snd - $oldsnd);
			push(@slopes, $slope);
		}
		$oldsnd = $snd;
		$oldrcv = $rcv;
	}
	my $medslope = median(\@slopes);

	# assume boundaries do not contain delay anomalies
	my $sine = sin(atan2($medslope,1));
	my $csin = cos(atan2($medslope,1));
	my @left = (); my @right = ();
	for(my $c = 0; $c < $n*0.2; $c++)
	{
		my $snd = 1e3*($tref->[$c]-$startt);
		my $rcv = $ref->[$c] + $snd;
		push(@left, -$snd*$sine + $rcv*$csin);
		$snd = 1e3*($tref->[$n-1-$c]-$startt);
		$rcv = $ref->[$n-1-$c] + $snd;
		push(@right, -$snd*$sine + $rcv*$csin);
	}
	my $ml = median(\@left);
	my $mr = median(\@right);
print "medslope: $medslope medl $ml medr $mr\n";

	#XXX: add conditions for NTP: should be long and persistent enough

	return ($mr > $ml+$ntpDiffThresh or $mr < $ml-$ntpDiffThresh) ? 1 : 0;
};


1;

