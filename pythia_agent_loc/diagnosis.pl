#!perl -w

use strict;

require 'localdiag.pl';
require 'ldcorr.pl';
require 'loss.pl';
require 'congestion.pl';

sub diagnose {
	my $ref = shift;
	my $tref = shift;
	my $seqref = shift;
	my $lseqrefall = shift;
	my $prevbaseline = shift;
	my $ret = "";

	my $lseqref = getLossHash($lseqrefall, $seqref);

	# context switch?
	my $retcs = contextSwitch($ref, $tref);
print "C-S: $retcs\n";

	# end-host noise (PL)
	my $reteh = hostNoise($ref, $tref, $prevbaseline);

	# NTP L-S
	#$ret = NTPshift($ref, $tref);
	#print "NTP L-S: $ret\n";

	# loss random?
	my ($retrloss, $ref_seq_d, $ref_seq_ts) = ldcorr($ref, $tref, $seqref, $lseqref, $prevbaseline);
print "Rnd-loss: $retrloss\n";

	# short outage
	my $retsoutage = shortoutage($ref, $tref, $seqref, $lseqref, $ref_seq_ts);
print "Short-out: $retsoutage\n";

	# very large/small buffers
	my ($retnbuf, $bufsz) = incorrectbufsz($ref, $retcs, $retrloss);
print "incorr-Buf: $retnbuf $bufsz\n";

	# right buffer: overload or bursty
	my ($retcong, $bursty) = congBurstyOverload($ref, $tref, $prevbaseline);
	my $retcload = $retcong & (~$bursty);
	my $retcburst = $retcong & $bursty;
print "congestion: ret $retcong bursty $bursty\n";

=pod
	# congestion overload; right buffer
	my $retcload = congoverload($ref, $tref, $prevbaseline);
print "cong-Overload: $retcload\n";

	# congestion bursty; right buffer
	my $retcburst = congbursty($ref, $tref);
	$retcburst  = int($retcburst*100)/100.0;
print "cong-Bursty: $retcburst\n";
=cut

	my $diag = getDiagnosis($retcs, $reteh, $retrloss, $retsoutage, $retnbuf, 
			$bufsz, $retcload, $retcburst);

	$ret = "C-S: $retcs  Host-Noise: $reteh  Rnd-loss: $retrloss  Short-out: $retsoutage\\nincorr-Buf: $retnbuf $bufsz  cong-Overload: $retcload  cong-Bursty: $retcburst\\ndiag: $diag";
	return $ret;
};


sub getDiagnosis {
	my $retcs = shift;
	my $reteh = shift;
	my $retrloss = shift;
	my $retsoutage = shift;
	my $retnbuf = shift;
	my $bufsz = shift;
	my $retcload = shift;
	my $retcburst = shift;

	my $diag = "";

	if($retcs == 1)
	{
		$diag = "Context switch";
	}
	elsif($reteh == 1)
	{
		$diag = "End-host noise";
	}
	else
	{
		if($retrloss != -1) #was there a loss?
		{
			if($retrloss == 0)
			{
				$diag = "Delay-correlated losses";
			}
			elsif($retrloss == 1)
			{
				$diag = "Random losses";
			}
			elsif($retrloss == 2)
			{
				$diag = "Level shift losses";
			}
			elsif($retrloss == 3)
			{
				$diag = "Random and level shift losses";
			}
		}

		if($retsoutage == 1)
		{
			$diag .= "<BR>Short outage";
		}

		if($retnbuf == 1)
		{
			if($bufsz == 1)
			{
				$diag .= "<BR>Buffer too large";
			}
			elsif($bufsz == 2)
			{
				$diag .= "<BR>Buffer too small";
			}
		}
		else
		{
			if($retcload == 1)
			{
				$diag .= "<BR>Congestion: overload";
			}
			if($retcburst == 1)
			{
				$diag .= "<BR>Congestion: bursty";
			}
		}
	}
	$diag = "Unknown" if $diag =~ /^$/;

	return $diag;
};


1;

