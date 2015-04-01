#!/usr/bin/perl
#
# Copyright 2012 Georgia Institute of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

use strict;

require 'sinsert.pl';
require 'mode.pl';
require 'aggregate.pl';
require 'printfunc.pl';
require 'saturation.pl';
require 'utilization.pl';
require 'reordering.pl';
require 'diagnosis.pl';
require 'preprocess.pl';
require 'symptomdiag.pl';
require 'dtreerun.pl';
require 'aggregateloss.pl';
require 'localization.pl';

use myConfig;


my $inputFile = $ARGV[0];
my $fileStartTime = $ARGV[1];
my $fileEndTime = $ARGV[2];


my $curWlen = $minWlen;

my @timeseries = (); #array of hashes
my %lostseqs = ();


# ESnet, I2

my ($min, $max, $nout) = 
	preprocess($inputFile, $fileStartTime, $fileEndTime, \@timeseries, \%lostseqs);

# Init the localization module
localizationInit();

# exit if delays don't have sufficient variance
if($max-$min < $minProbDelay or $nout < 4) 
{ 
	print STDERR "skipping: no problem\n";
	
	# Adds good entries to the localization table 
	localizationBuildGoodEntries($fileStartTime, $fileEndTime, $max, $min);
	# Write it to db
	localizationCommitData($inputFile);
	
	exit 0; 
}

my $starttime = $timeseries[0]->{sendTS};
my $startseq = $timeseries[0]->{seq};
my $exptbegin = $starttime;

my @W = ();
my @sortW = ();
my @Wts = ();
my @Wseq = ();
my $IQR = -1;
my $range = -1;
my $n = 0;
my @sortS = ();
my $oldseq = -1;

my $reordersum = 0;
my $nreordered = 0;
my $nexporderseq = $startseq-1;
my $ntot = 0;
my $loseq = 0xFFFFFFFF;
my $hiseq = -1;
my $oldmode = -1;
my $ntimearrseq = @timeseries;

# set the start sequence number 
localization_set_startseq($startseq);

for(my $timearrseq = 0; $timearrseq < $ntimearrseq; $timearrseq++)
{
	my $d = $timeseries[$timearrseq]->{delay};
	my $t = $timeseries[$timearrseq]->{sendTS};
	my $s = $timeseries[$timearrseq]->{seq};
	my $s_recvorder = $timeseries[$timearrseq]->{seqorg};

	# data structure for losses
	$oldseq = $s if $oldseq == -1;
	if($inputFile !~ /\.owp$/)
	{
		delete $lostseqs{$s} if exists $lostseqs{$s}; #reordering
		for(my $seq = $oldseq+1; $seq < $s; $seq++)
		{
			$lostseqs{$seq} = $t;
		}
	}
	else
	{
		my $nseq = $s+1;
		while(exists $lostseqs{$nseq})
		{
			$lostseqs{$nseq++} = $t;
		}
	}

	# reordering
	$nexporderseq++;
	while(exists $lostseqs{$nexporderseq}) { $nexporderseq++; }

	if($t - $starttime > $curWlen)
	{
		my $mode = -1;
		my $h = getBW($IQR, $n);
		if($h != 0)
		{
			($mode, my $modeEnd, my $modeStart, my $density) = 
						getLowMode(\@sortW, $h, $n);
			$oldmode = $mode if $oldmode == -1;

		#print STDERR "baseline: $mode range $modeStart to $modeEnd (".
		#	($modeEnd-$modeStart).") d $density iqr $IQR\n";
		#print STDERR "reordering: ".(($nreordered == 0) ? 0 : $reordersum/$nreordered).
		#	" lostfrac: ".($nlost/($hiseq-$loseq+1))." $t\n\n";

			#my $rightCI = getHighMode(\@sortW, $h, $n, $modeEnd);

			my ($ret,$estart,$eend,$estartS,$eendS, $eventWref, 
				$eventWtsref, $eventWseqref) = 
			addDensityPts(\@W, \@Wts, \@sortW, \@Wseq, $n, $modeStart, $modeEnd, 
					$density, $starttime, $t, $range, $exptbegin, \@sortS);
			if($ret == 1)
			{
				#saturation($eventWref, $eventWtsref);
				#my $ul = utilization($eventWref, $oldmode);
				#print "UTIL $ul\n";

				#my $ret = diagnose($eventWref, $eventWtsref, $eventWseqref, 
				#\%lostseqs, $oldmode); #XXX: change mode to last non-event mode
				setEventVars($estart-5, $eend+5, $eventWref, $eventWtsref, 
					$eventWseqref, \%lostseqs, $oldmode, 1);
				my $ret = diagnosisTree();

				printTS($estart, $eend, $starttime, 5, \%lostseqs, 
						$estartS, $eendS, $inputFile, $ret,
						$eventWref, $eventWtsref);
				#printTSarr($eventWref, $eventWtsref, $starttime, 5);
			}
		}

		### Loss
		my $nlost = 0;
		for(my $seq = $loseq; $seq < $hiseq + 1; $seq++) 
		{ if(exists $lostseqs{$seq}) {$nlost++;} } #print STDERR "LOST $seq\n";} }
		my ($ret,$estart,$eend,$estartS,$eendS, $eventWref, 
				$eventWtsref, $eventWseqref) = 
		addLossPts(\@W, \@Wts, \@sortW, \@Wseq, $n,
				$starttime, $t, $range, $exptbegin, \@sortS, $nlost);
				
		if($ret == 1)
		{
			setEventVars($estart-5, $eend+5, $eventWref, $eventWtsref, $eventWseqref,
					\%lostseqs, $oldmode, 2);
			my $ret = diagnosisTree();
			printTS($estart, $eend, $starttime, 5, \%lostseqs, 
					$estartS, $eendS, $inputFile, $ret,
					$eventWref, $eventWtsref);
		}

		### Reordering
		my $rmetric = ($nreordered == 0) ? 0 : $reordersum/$nreordered;
		my ($reorderStart, $reorderEnd) = addReorderWindow($rmetric, $t);
		#only for reordering
		setEventVars(undef, undef, undef, undef, undef, undef, undef, 3);
		my $ret = diagnosisTree();
		if($ret =~ /Reorder/)
		{
			printReorderEvent($reorderStart, $reorderEnd, $inputFile, $ret);
			print "REORDERING: $reorderStart $reorderEnd diag $ret\n";
		}
		#my $reorderRet = checkReordering();
		#my $str = ($reorderRet == -1) ? "none" : 
		#		(($reorderRet == 0) ? "persistent" : "unstable");
		#print "REORDERING: $str $reorderRet\n" if $reorderRet != -2;

		localizationAddEntry(\@W, \@Wseq, \@Wts, \%lostseqs, $oldmode);

		$starttime = $t;
		@W = ();
		@sortW = ();
		@Wts = ();
		@Wseq = ();
		@sortS = ();

		$ntot = 0;
		$loseq = $hiseq = $s;
		$reordersum = $nreordered = 0;
		$oldmode = $mode if $mode != -1;

	#print STDERR "#"; $|=1;
	}

	push(@W, $d);
	($IQR, $n, $range) = sinsert(\@sortW, $d);
	push(@Wts, $t);
	sinsert(\@sortS, $s);
	push(@Wseq, $s);
	$oldseq = $s;

	$ntot++;
	$loseq = $s if $loseq >= $s;
	$hiseq = $s if $hiseq <= $s;
	$reordersum += abs($s_recvorder-$nexporderseq);
	$nreordered++ if $s_recvorder-$nexporderseq != 0;
}

my ($ret, $estart, $eend, $estartS, $eendS, $eventWref, $eventWtsref, $eventWseqref) 
	= residualEvent($exptbegin);
if($ret == 1) 
{
	#my $ret = diagnose($eventWref, $eventWtsref, $eventWseqref, \%lostseqs, $oldmode);
	setEventVars($estart-5, $eend+5, $eventWref, $eventWtsref, $eventWseqref,
			\%lostseqs, $oldmode, 1);
	my $ret = diagnosisTree();

	#saturation($eventWref, $eventWtsref);
	#my $ul = utilization($eventWref, $oldmode);
	#print "UTIL $ul\n";
	printTS($estart, $eend, $starttime, 5, \%lostseqs, $estartS, $eendS, 
			$inputFile, $ret, 
			$eventWref, $eventWtsref);
	#printTSarr($eventWref, $eventWtsref, $starttime, 5);
}

my ($ret, $estart, $eend, $estartS, $eendS, $eventWref, $eventWtsref, $eventWseqref) 
	= residualLossEvent($exptbegin);
if($ret == 1)
{
	setEventVars($estart-5, $eend+5, $eventWref, $eventWtsref, $eventWseqref,
		\%lostseqs, $oldmode, 2);
	my $ret = diagnosisTree();
	
	printTS($estart, $eend, $starttime, 5, \%lostseqs, 
		$estartS, $eendS, $inputFile, $ret,
		$eventWref, $eventWtsref);
}


### Reordering test
#my $rmetric = ($nreordered == 0) ? 0 : $reordersum/$nreordered;
#my ($reorderStart, $reorderEnd) = addReorderWindow($rmetric, $t);
#setEventVars(undef, undef, undef, undef, undef, undef, undef); #only for reordering
#my $ret = diagnosisTree();
#if($ret =~ /Reorder/)
#{
#	printReorderEvent($reorderStart, $reorderEnd, $inputFile, $ret);
#	print "REORDERING: $reorderStart $reorderEnd diag $ret\n";
#}
#addReorderWindow($rmetric, $t);
#my $reorderRet = checkReordering();
#my $str = ($reorderRet == -1) ? "none" : 
#		(($reorderRet == 0) ? "persistent" : "unstable");
#print "REORDERING: $str\n" if $reorderRet != -2;
#printReorderArr();

# Write localization data to the db
localizationCommitData($inputFile);

# Danny: done with structs. Can destroy the module
localizationDestroy();

#print STDERR "done.\n";

