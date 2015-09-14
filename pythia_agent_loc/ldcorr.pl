#!perl -w
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

my $rndNeighborFrac = 0.4;


sub ldcorr {
	my $ref = shift;
	my $tref = shift;
	my $seqref = shift;
	my $lseqref = shift;
	my $prevbaseline = shift;
	my $seq_d_ref = shift;
	my $seq_ts_ref = shift;

	my $n = @$ref;
	my %seq_d = %$seq_d_ref;
	my %seq_ts = %$seq_ts_ref;

	if(!defined %$seq_d_ref or !defined %$seq_d_ref)
	{
		%seq_d = ();
		%seq_ts = ();
		for(my $c = 0; $c < $n; $c++)
		{
			$seq_d{$seqref->[$c]} = $ref->[$c];
			$seq_ts{$seqref->[$c]} = $tref->[$c];
		}
	}

	my $nloss = scalar(keys %$lseqref);
	if($nloss == 0) { print STDERR "loss-rate: no losses\n"; return (-1, \%seq_d, \%seq_ts); }

	my $nonrndfrac = 0;
	my $levelshiftfrac = 0;
	foreach my $seq (keys %$lseqref)
	{
		my $ndfrac = 0;
		my $ntot = 0;
		my @halfarr = (); my $halfmed = -1;
		# count # pts in n-hood > baseline
		for(my $s = $seq - 5; $s <= $seq + 5; $s++)
		{
			if($s == $seq)
			{
				$halfmed = median(\@halfarr);
				@halfarr = ();
				next;
			}
			if(exists $seq_d{$s})
			{
				$ndfrac++ if $seq_d{$s} > $prevbaseline + 1; #ms
				$ntot++;
				push(@halfarr, $seq_d{$s});
			}
		}
		next if $ntot < 5;
		my $halfmed2 = median(\@halfarr);
		#$levelshiftfrac++ if $halfmed != -1 and $halfmed2 != -1 and 
		#			abs($halfmed2 - $halfmed) > 1; #ms
		#$nonrndfrac++ if $ndfrac/$ntot > $rndNeighborFrac;
		if($halfmed != -1 and $halfmed2 != -1 and 
			abs($halfmed2 - $halfmed) > 1) #ms
		{
			$levelshiftfrac++ 		
		}
		else
		{
			$nonrndfrac++ if $ndfrac/$ntot > $rndNeighborFrac;
		}
print STDERR "Rnd-loss: seq $seq non-neighborhood: $ndfrac / $ntot\n";
print STDERR "Rnd-loss: seq $seq medians: $halfmed $halfmed2 LSfrac: $levelshiftfrac\n" if $halfmed != -1 and $halfmed2 != -1;
	}
print STDERR "Rnd-loss: nonrnd $nonrndfrac LS $levelshiftfrac nloss $nloss\n";

	#TODO: distinguish LSes from congestion
	# 3 : routing + random losses
	# 2 : routing change losses
	# 1 : random losses; 0 : otherwise
	my $ret = (($nloss!=$levelshiftfrac and 
			1-$nonrndfrac/($nloss-$levelshiftfrac) > 0.5) ? 1 : 0) + 
		  (($levelshiftfrac != 0) ? 2 : 0);
	return ($ret, \%seq_d, \%seq_ts);
};



sub ldcorr2 {
	my $ref = shift;
	my $tref = shift;
	my $seqref = shift;
	my $lseqref = shift;
	my $n = @$ref;

	my %d_seq = ();
	my %d_lostseq = ();
	for(my $c = 0; $c < $n; $c++)
	{
		$d_seq{$ref->[$c]} = $seqref->[$c];
	}
	my $oldseq = -1;
	foreach my $d (sort { $d_seq{$a} <=> $d_seq{$b} } keys %d_seq)
	{
		my $s = $d_seq{$d};
		$oldseq = $s-1 if $oldseq == -1;
		for(my $c = $oldseq+1; $c < $s; $c++)
		{
			# use previous delay for lost packets
			$d_lostseq{$d} = $c if defined $lseqref->{$c};
		}
		$oldseq = $s;
	}
	if(scalar(keys %$lseqref) == 0) { print STDERR "loss-rate: no losses\n"; return -1; }

	# start with highest delays of lost packets
	my $nlost = 0; my $npts = 0;
	foreach my $lostd (reverse sort {$a <=> $b} keys %d_lostseq)
	{
		$nlost++;
		#$npts = 0;
		foreach my $d (reverse sort {$a <=> $b} keys %d_seq)
		{
#print "d $d lostd $lostd\n";
			last if $d < $lostd;
			$npts++; # no. of pts >= lostd
			delete $d_seq{$d};
		}
		print "loss-rate for d >= $lostd: ".($nlost/$npts)." $nlost/$npts\n";
	}
};


1;

