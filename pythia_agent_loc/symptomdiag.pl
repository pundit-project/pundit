#!perl -w

use strict;

require 'localdiag.pl';
require 'ldcorr.pl';
require 'loss.pl';
require 'congestion.pl';
require 'utilization.pl';
require 'reordering.pl';
require 'levelshift.pl';

# wrapper around diagnosis logic; provides an interface to D-Tree code
# all methods return one of: 1 (TRUE) or 2 (FALSE)
use constant TRUE => 1;
use constant FALSE => 2;

#event timeseries..
my $ref; #delay
my $tref; #time
my $seqref; #seq
my $lseqref; #loss
my $prevbaseline;
my $eventType; #1: delay, 2: loss, 3: reordering

my %seq_d = ();
my %seq_ts = ();
my %cache = ();
my $supportVarKey = "";
my $supportVarVal = "";

sub setEventVars #set from diagnose() in diagnosis.pl
{
	my $startTime = shift;
	my $endTime = shift;
	$ref = shift;
	$tref = shift;
	$seqref = shift;
	my $lseqrefall = shift;
	$prevbaseline = shift;
	$eventType = shift;

	return if !defined $ref;

	my $n = @$ref;
	for(my $c = $n-1; $c >= 0; $c--)
	{
		my $t = $tref->[$c];
		next if $t >= $startTime and $t <= $endTime;
		splice(@$ref, $c, 1);
		splice(@$tref, $c, 1);
		splice(@$seqref, $c, 1);
	}

	$lseqref = getLossHash($lseqrefall, $seqref);
	%cache = ();
	%seq_d = ();
	%seq_ts = ();
	$supportVarKey = "";
	$supportVarVal = "";

	$n = @$ref;
	for(my $c = 0; $c < $n; $c++)
	{
		$seq_d{$seqref->[$c]} = $ref->[$c];
		$seq_ts{$seqref->[$c]} = $tref->[$c];
	}
};

sub DelayExist
{
	return (defined $ref and $eventType == 1) ? TRUE : FALSE; #DTree currently triggered ONLY on delay-events
};

sub LossExist
{
	return FALSE if !defined $ref;

	return $cache{LossExist} if exists $cache{LossExist};

	my $nloss = scalar(keys %$lseqref);
print "nloss $nloss\n";
	if($nloss == 0)
	{
		$cache{LossExist} = FALSE;
	}
	else
	{
		$cache{LossExist} = TRUE;
	}
	return $cache{LossExist};
};

sub ReorderExist
{
	my $ret = reorderExist();
	if($ret == 1)
	{
		return TRUE;
	}
	return FALSE; #this check is also inside ReorderShift
};

sub LargeTriangle
{
	return $cache{LargeTriangle} if exists $cache{LargeTriangle};

	my ($ret, $rate) = contextSwitch($ref, $tref, $prevbaseline);
	if($ret == 1)
	{
		$cache{LargeTriangle} = TRUE;
		$supportVarKey = "CSRate";
		$supportVarVal = $rate;
	}
	else #0 or -1
	{
		$cache{LargeTriangle} = FALSE;
	}
	return $cache{LargeTriangle};
};

sub UnipointPeaks
{
	return $cache{UnipointPeaks} if exists $cache{UnipointPeaks};

	my $ret = hostNoise($ref, $tref, $prevbaseline);
	if($ret == 1)
	{
		$cache{UnipointPeaks} = TRUE;
	}
	else #0 or -1
	{
		$cache{UnipointPeaks} = FALSE;
	}
	return $cache{UnipointPeaks};
};

sub LossEventSmallDur
{
	return $cache{LossEventSmallDur} if exists $cache{LossEventSmallDur};

	my $ret = shortoutage($ref, $tref, $seqref, $lseqref, \%seq_ts);
	if($ret == 1)
	{
		$cache{LossEventSmallDur} = TRUE;
	}
	else
	{
		$cache{LossEventSmallDur} = FALSE;
	}
	return $cache{LossEventSmallDur};
};

sub DelayLossCorr
{
	return $cache{DelayLossCorr} if exists $cache{DelayLossCorr};

	#XXX: note two new parameters at the end
	my ($ret, $u1, $u2) = 
		ldcorr($ref, $tref, $seqref, $lseqref, $prevbaseline, \%seq_d, \%seq_ts);
	if($ret == 1 or $ret == 3) # note: includes rand+LS loss events
	{
		$cache{DelayLossCorr} = FALSE;
	}
	else #0 or 2: includes LS losses too
	{
		$cache{DelayLossCorr} = TRUE; # correlated; case of no-loss is handled by DTree
	}
	return $cache{DelayLossCorr};
};

### constants
my $highBuf = 500; #ms
my $lowBuf = 1; #ms
my $highutil = 0.5; #%

sub HighUtil
{
	return $cache{HighUtil} if exists $cache{HighUtil};

	my ($util, $burstflag) = utilization($ref, $tref, $prevbaseline);
	if($util > $highutil)
	{
		$cache{HighUtil} = TRUE;
	}
	else
	{
		$cache{HighUtil} = FALSE;
	}
	if($burstflag != -1)
	{
		$cache{BurstyDelays} = (($burstflag == 1) ? TRUE : FALSE);
	}
	return $cache{HighUtil};
};

sub BurstyDelays
{
	return $cache{BurstyDelays} if exists $cache{BurstyDelays};

	HighUtil();
	return $cache{BurstyDelays};
};

sub HighDelayIQR
{
	return $cache{HighDelayIQR} if exists $cache{HighDelayIQR};

	$cache{HighDelayIQR} = FALSE;
	$cache{LowDelayIQR} = FALSE;

	my @parr = (0.05, 0.95);
	my ($lowd, $highd) = prctileArr($ref, \@parr); #IQR($ref);
	my $iqr = $highd - $lowd;
	if($iqr > $highBuf)
	{
		$cache{HighDelayIQR} = TRUE;
	}
	elsif($iqr < $lowBuf)
	{
		$cache{LowDelayIQR} = TRUE;
	}
	return $cache{HighDelayIQR};
};

sub LowDelayIQR
{
	return $cache{LowDelayIQR} if exists $cache{LowDelayIQR};

	HighDelayIQR();
	return $cache{LowDelayIQR};
};

sub ReorderShift
{
	# we do not use the cache for this method
	my $ret = checkReordering();
	if($ret < 0) # zero reordering or not enough data
	{
		return FALSE;
	}
	elsif($ret == 0) #persistent
	{
		return FALSE;
	}
	else #1: unstable
	{
		return TRUE;
	}
	return FALSE;
};

sub DelayLevelShift
{
	return $cache{DelayLevelShift} if exists $cache{DelayLevelShift};

	my $ret = levelShift($ref, $prevbaseline);
	if($ret == 1)
	{
		$cache{DelayLevelShift} = TRUE;
	}
	else
	{
		$cache{DelayLevelShift} = FALSE;
	}
	return $cache{DelayLevelShift};
};

sub getSupportVar
{
	return ($supportVarKey, $supportVarVal);
};


1;

