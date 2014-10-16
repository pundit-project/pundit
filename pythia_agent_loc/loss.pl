#!perl -w

use strict;

my $shortoutagegap = 1; #s


sub getLossHash {
	my $lseqrefall = shift;
	my $seqref = shift;
	my $n = @$seqref;
	my $minseq = 0xFFFFFF;
	my $maxseq = -1;
	for(my $s = 0; $s < $n; $s++)
	{
		my $seq = $seqref->[$s];
		$minseq = $seq if $minseq >= $seq;
		$maxseq = $seq if $maxseq <= $seq;
	}

	my %lseqall = %$lseqrefall;
	my %newhash = ();
	for(my $s = $minseq; $s <= $maxseq; $s++)
	{
		$newhash{$s} = $lseqall{$s} if exists $lseqall{$s};
	}
	return \%newhash;
};


sub checkevent {
	my $eventstart = shift;
	my $eventend = shift;
	my $ref_seq_ts = shift;
	my %seq_ts = %$ref_seq_ts;
	my $gap = -1;

	if(exists $seq_ts{$eventstart-1} and
	   exists $seq_ts{$eventend+1})
	{
		$gap = $seq_ts{$eventend+1} - $seq_ts{$eventstart-1};
print "Short-out: gap $gap\n" if $gap > $shortoutagegap;
		return 1 if $gap > $shortoutagegap;
	}
	return 0;
};

sub shortoutage {
	my $ref = shift;
	my $tref = shift;
	my $seqref = shift;
	my $lseqref = shift;
	my $ref_seq_ts = shift;
	my $n = @$seqref;

	my $nloss = scalar(keys %$lseqref);
	if($nloss == 0) { print STDERR "loss-rate: no losses\n"; return -1; }

	my $oldseq = -1;
	my $seq = -1;
	for(my $c = 0; $c < $n; $c++)
	{
		my $seq = $seqref->[$c];
		$oldseq = $seq-1 if $oldseq == -1;
		if($seq > $oldseq + 1)
		{
			my $ret = checkevent($oldseq+1, $seq-1, $ref_seq_ts);
			return 1 if $ret == 1;
		}
		$oldseq = $seq;
	}

	my $ret = checkevent($oldseq+1, $seq-1, $ref_seq_ts);
	return $ret;
};


1;


