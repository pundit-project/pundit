#!perl -w

use strict;
use POSIX qw(floor);
use Term::ANSIColor qw(:constants);

use myConfig;


my $lasteventstart = -1;
my $lasteventend = -1;
my $lasteventstartS = -1;
my $lasteventendS = -1;
my $lasteventThresh = 0;
my $lasteventNLarge = 0;
my @eventW = ();
my @eventWts = ();
my @eventWseq = ();
my @preveventW = ();
my @preveventWts = ();
my @preveventWseq = ();
my @bgeventW = ();
my @bgeventWts = ();
my @bgeventWseq = ();

my @modewidths = ();


sub getPercentile {
	my $ref = shift;
	my $p = shift;

	return -1 if @$ref < 10;

	my @arr = @$ref;
	my @sarr = sort {$a <=> $b} @arr;

	return $sarr[floor(@arr * $p)];
};

sub addDensityPts {
	my $ref = shift;
	my $tref = shift;
	my $sortref = shift;
	my $seqref = shift;
	my $n = shift;
	my $modeStart = shift;
	my $modeEnd = shift;
	my $density = shift;
	my $starttime = shift;
	my $endtime = shift;
	my $range = shift;
	my $exptbegin = shift;
	my $sref = shift;

	my $nS = @$sref;
	my @ret = (0,-1,-1,-1,-1, \@preveventW, \@preveventWts, \@preveventWseq);

#	if($range < $minProbDelay)
#	{
#		#queue
#		unshift(@modewidths, $modeEnd-$modeStart);
#		pop(@modewidths) if @modewidths > 30;
#		return (0,-1-1);
#	}

	my $widththresh = getPercentile(\@modewidths, 0.9);
	$widththresh = 5 if $widththresh == -1;
	$widththresh = 2; #XXX
	#print STDERR BLUE,"widththresh $widththresh  range $range\n",RESET;

	if($density < 0.4 or $modeEnd-$modeStart > $widththresh) #ms
	{
#print "PROBLEM!: last $lasteventstart to $lasteventend start $starttime\n";
		if($starttime - $lasteventend <= $maxInterProbGap)
		{
			$lasteventThresh = 1 if $range > $minProbDelay;
#			print STDERR YELLOW,"\nadding window $starttime to $endtime [".(floor($starttime-$exptbegin)).",".(floor($endtime-$exptbegin))."] e-thresh $lasteventThresh  range $range\n",RESET;
			$lasteventend = $endtime;
			$lasteventendS = $sref->[$nS-1];

			push(@eventW, @$ref);
			push(@eventWts, @$tref);
			push(@eventWseq, @$seqref);
		}
		else
		{
			#print last event
			if($lasteventend - $lasteventstart >= $minProbDuration and
				$lasteventThresh == 1 and
				$lasteventNLarge > 5) #XXX
			{
				my $probstart = floor($lasteventstart - $exptbegin);
				print RED, "\n$probstart: problem: $lasteventstart to $lasteventend  dur ".($lasteventend-$lasteventstart)." #large $lasteventNLarge\n", RESET;
				@ret = (1,$lasteventstart,$lasteventend, 
					$lasteventstartS, $lasteventendS, 
					\@preveventW, \@preveventWts, \@preveventWseq);
			}

			#start new event
			$lasteventstart = $starttime;
			$lasteventend = $endtime;
			$lasteventstartS = $sref->[0];
			$lasteventendS = $sref->[$nS-1];
			$lasteventThresh = ($range > $minProbDelay) ? 1 : 0;
			$lasteventNLarge = 0;
			@preveventW = @eventW; @preveventWts = @eventWts; @preveventWseq = @eventWseq;
			@eventW = (); push(@eventW, @bgeventW); push(@eventW, @$ref);
			@eventWts = (); push(@eventWts, @bgeventWts); push(@eventWts, @$tref);
			@eventWseq = (); push(@eventWseq, @bgeventWseq); push(@eventWseq, @$seqref);

#			print STDERR YELLOW,"\nstarting window $starttime to $endtime e-thresh $lasteventThresh\n",RESET;
		}

		#count # large pts
		for(my $c = 0; $c < $n; $c++)
		{
			$lasteventNLarge++ if $sortref->[$c]-$sortref->[0] > $minProbDelay;
		}
	}
	else
	{
		# add pts between anomaly windows, or just after an event
		if($starttime - $lasteventend <= $maxInterProbGap)
		{
			push(@eventW, @$ref); push(@eventWts, @$tref); push(@eventWseq, @$seqref);
		}
		else
		{
			@bgeventW = (); push(@bgeventW, @$ref);
			@bgeventWts = (); push(@bgeventWts, @$tref);
			@bgeventWseq = (); push(@bgeventWseq, @$seqref);
		}

#		#queue
#		unshift(@modewidths, $modeEnd-$modeStart);
#		pop(@modewidths) if @modewidths > 30;
	}

	return @ret;
};

sub residualEvent {
	my $exptbegin = shift;

	my @ret = (0,-1,-1,-1,-1, \@eventW, \@eventWts, \@eventWseq);
	#print last event
	if($lasteventend - $lasteventstart >= $minProbDuration and
		$lasteventThresh == 1 and 
		$lasteventNLarge > 5)
	{
		my $probstart = floor($lasteventstart - $exptbegin);
		print RED, "\n$probstart: problem: $lasteventstart to $lasteventend  dur ".($lasteventend-$lasteventstart)."\n", RESET; $| = 1;
		@ret = (1,$lasteventstart,$lasteventend, $lasteventstartS, $lasteventendS,
				\@eventW, \@eventWts, \@eventWseq);
	}

	return @ret;
};


# since last event ended:
my $nPtsOverLow = 0;
my $nPts = 0;

sub addProbPoints {
	my $ref = shift;
	my $tref = shift;
	my $n = shift;
	my $thresh = shift;
	my $lowthresh = shift;

	return -1 if $thresh == -1;

	my @W = @$ref;
	my @Wts = @$tref;

	for(my $c = 0; $c < $n; $c++)
	{
		if($W[$c] >= $thresh)
		{
			if($Wts[$c] - $lasteventend <= $maxInterProbGap)
			{
				$lasteventend = $Wts[$c];
			}
			else
			{
				print STDERR "[ $lasteventend , $Wts[$c] ] : proportion $nPtsOverLow/$nPts\n";

				#reset event only if proportion low
				if($nPts == 0 or $nPtsOverLow/$nPts < $minLowModeFrac)
				{
					#print last event
					if($lasteventend - $lasteventstart >= $minProbDuration)
					{
						print "[ $lasteventend , $Wts[$c] ] : proportion $nPtsOverLow/$nPts\n";
						print "\nproblem: $lasteventstart to $lasteventend  dur ".($lasteventend-$lasteventstart)." npts $nPts\n";
					}

					#start new event
					$lasteventstart = $lasteventend = $Wts[$c];
				}
				else
				{
					$lasteventend = $Wts[$c];
				}
			}
			$nPtsOverLow = $nPts = 0;
		}

		$nPtsOverLow++ if $W[$c] > $lowthresh;
		$nPts++;
	}

	#print last event
	#if($lasteventend - $lasteventstart >= $minProbDuration)
	#{
	#	print "\nproblem: $lasteventstart to $lasteventend  dur "
	#		.($lasteventend-$lasteventstart)."\n";
	#}


};


1;

