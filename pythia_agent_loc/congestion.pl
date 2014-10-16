#!perl -w

use strict;
use POSIX qw(floor);
require 'utilization.pl';


my $highBuf = 500; #ms
my $lowBuf = 1; #ms
my $highutil = 0.5; #%
my $highdelay = 800; #ms


sub IQR {
	my $ref = shift;
	my $n = @$ref;
	my @sarr = sort {$a <=> $b} @$ref;
	return $sarr[floor($n*0.75)] - $sarr[floor($n*0.25)];
};
sub prctile {
	my $ref = shift;
	my $p = shift; # [0,1]
	my $n = @$ref;
	my @sarr = sort {$a <=> $b} @$ref;
	return $sarr[floor($n*$p)];
};
sub prctileArr {
	my $ref = shift;
	my $pref = shift; # [0,1]
	my $n = @$ref;
	my @sarr = sort {$a <=> $b} @$ref;
	my @ret = ();
	for(my $c = 0; $c < scalar(@$pref); $c++)
	{
		push(@ret, $sarr[floor($n*$pref->[$c])]);
	}
	return @ret;
};
sub mean {
	my $ref = shift;
	my $n = @$ref;
	my $sum = 0;
	for(my $c = 0; $c < $n; $c++)
	{
		$sum += $ref->[$c];
	}
	return $sum/$n;
};
sub indexDisp {
	my $ref = shift;
	my $n = @$ref;
	my $m = mean($ref);
	my $sum = 0;
	for(my $c = 0; $c < $n; $c++)
	{
		$sum += ($ref->[$c]-$m)**2;
	}
	my $var = $sum/($n-1);
	return $var/$m;
};
sub var {
	my $ref = shift;
	my $n = @$ref;
	my $m = mean($ref);
	my $sum = 0;
	for(my $c = 0; $c < $n; $c++)
	{
		$sum += ($ref->[$c]-$m)**2;
	}
	return ($sum/($n-1), $m);
};



sub incorrectbufsz {
	my $ref = shift;
	my $retcs = shift;
	my $retrloss = shift;

	# should not be a context switch of random loss
	return (-1,0) if ($retcs == 1 or $retrloss == 1);

	my $iqr = IQR($ref);
print STDERR "bufsz: iqr $iqr\n";

	if($iqr > $highBuf) #ms
	{
		return (1,1);
	}
	elsif($iqr < $lowBuf) #ms
	{
		return (1,2) if $retrloss != -1;
	}
	else
	{
		return (0,0);
	}
	return (-1,-1);
};


sub congBurstyOverload {
	my $ref = shift;
	my $tref = shift;
	my $baseline = shift;

	my ($util, $burstflag) = utilization($ref, $tref, $baseline);
	my $hdelay = prctile($ref, 0.95) - prctile($ref, 0.05);

	return ($util > $highutil and $hdelay < $highdelay) ?
		(1, $burstflag) : (0, $burstflag);
};


# older methods...
sub congoverload {
	my $ref = shift;
	my $tref = shift;
	my $baseline = shift;

	my ($util, $burstflag) = utilization($ref, $tref, $baseline);
	my $hdelay = prctile($ref, 0.95) - prctile($ref, 0.05);

	#XXX: how many of the $util points are consecutively high?
	# in other words, is the traffic bursty rather than overload?

	return ($util > $highutil and $hdelay < $highdelay) ?
		1 : 0;
};

sub congbursty {
	my $ref = shift;
	my $tref = shift;
	my $n = @$ref;
	my $t0 = $tref->[0];

	#my $i = indexDisp($ref);

	my @interarr = ();
	for(my $c = 0; $c < $n; $c++)
	{
		my $rts = $tref->[$c]-$t0 + $ref->[$c]*1e-3; #s
		push(@interarr, $rts);
	}
	my ($v,$m) = var(\@interarr);
	my $idi = $v/($m**2);

	return $idi;
};


1;

