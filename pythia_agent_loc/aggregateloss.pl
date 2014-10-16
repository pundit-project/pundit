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


sub addLossPts {
	my $ref = shift;
	my $tref = shift;
	my $sortref = shift;
	my $seqref = shift;
	my $n = shift;
	my $starttime = shift;
	my $endtime = shift;
	my $range = shift;
	my $exptbegin = shift;
	my $sref = shift;
	my $nloss = shift;

	my $nS = @$sref;
	my @ret = (0,-1,-1,-1,-1, \@preveventW, \@preveventWts, \@preveventWseq);

	if($nloss > 0)
	{
#print "PROBLEM!: last $lasteventstart to $lasteventend start $starttime\n";
		if($starttime - $lasteventend <= $maxInterProbGap)
		{
			$lasteventThresh = 1 if $nloss > 0;
			#print STDERR YELLOW,"\nloss: adding window $starttime to $endtime [".(floor($starttime-$exptbegin)).",".(floor($endtime-$exptbegin))."] e-thresh $lasteventThresh  range $range\n",RESET;
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
				$lasteventNLarge > 1) #XXX
			{
				my $probstart = floor($lasteventstart - $exptbegin);
			print RED, "\n$probstart: loss problem: $lasteventstart to $lasteventend  dur ".($lasteventend-$lasteventstart)." #large $lasteventNLarge\n", RESET;
				@ret = (1,$lasteventstart,$lasteventend, 
					$lasteventstartS, $lasteventendS, 
					\@preveventW, \@preveventWts, \@preveventWseq);
			}

			#start new event
			$lasteventstart = $starttime;
			$lasteventend = $endtime;
			$lasteventstartS = $sref->[0];
			$lasteventendS = $sref->[$nS-1];
			$lasteventThresh = ($nloss > 0) ? 1 : 0;
			$lasteventNLarge = 0;
			@preveventW = @eventW; @preveventWts = @eventWts; @preveventWseq = @eventWseq;
			@eventW = (); push(@eventW, @bgeventW); push(@eventW, @$ref);
			@eventWts = (); push(@eventWts, @bgeventWts); push(@eventWts, @$tref);
			@eventWseq = (); push(@eventWseq, @bgeventWseq); push(@eventWseq, @$seqref);

			#print STDERR YELLOW,"\nloss: starting window $starttime to $endtime e-thresh $lasteventThresh\n",RESET;
		}

		#count # large pts
		for(my $c = 0; $c < $n; $c++)
		{
			$lasteventNLarge++ if $nloss > 0;
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
	}

	return @ret;
};

sub residualLossEvent {
	my $exptbegin = shift;

	my @ret = (0,-1,-1,-1,-1, \@eventW, \@eventWts, \@eventWseq);
	#print last event
	if($lasteventend - $lasteventstart >= $minProbDuration and
		$lasteventThresh == 1 and 
		$lasteventNLarge > 1)
	{
		my $probstart = floor($lasteventstart - $exptbegin);
		print RED, "\n$probstart: problem: $lasteventstart to $lasteventend  dur ".($lasteventend-$lasteventstart)."\n", RESET; $| = 1;
		@ret = (1,$lasteventstart,$lasteventend, $lasteventstartS, $lasteventendS,
				\@eventW, \@eventWts, \@eventWseq);
	}

	return @ret;
};


1;

