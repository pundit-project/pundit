#!perl -w

use strict;
use myConfig;

sub preprocessReader
{
	my $inputFile = shift;
	my $fileStartTime = shift;
	my $fileEndTime = shift;
	my $timeseriesref = shift;
	my $lostseqsref = shift;

	my @orgseqs = ();
	my @sendTS = ();
	my $min = 0xFFFFFF; my $max = -0xFFFFFF; my $nout = 0;

	open(IN, "./owstats -v $inputFile |") or die;
	while(my $line = <IN>)
	{
		next if $line !~ /^seq_no/;
		chomp $line;
		$line =~ s/=/ /g; $line =~ s/\t/ /g;
		my @obj = split(/\s+/, $line);

		if($line !~ /LOST/)
		{
			next if $obj[10] < $fileStartTime;
			last if $obj[10] > $fileEndTime;
		}
		else
		{
			$lostseqsref->{$obj[1]} = 1;
			next;
		}

		my $d = $obj[3];

		push(@orgseqs, $obj[1]);
		push(@sendTS, $obj[10]);

		my %elem = ();
		$elem{seq} = $obj[1];
		$elem{delay} = $d;
		push(@$timeseriesref, \%elem);

		$max = $d if $max < $d; $min = $d if $min > $d;
		$nout++ if $d-$min > $minProbDelay;
	}
	close IN;

	@$timeseriesref = sort { $a->{seq} <=> $b->{seq} } @$timeseriesref;
	@sendTS = sort { $a <=> $b} @sendTS;
	my $n = @sendTS;
	my $prevdelay = $timeseriesref->[0]->{delay};
	my $prevTS = $sendTS[0];
	for(my $c = 0; $c < $n; $c++)
	{
		my $ref = $timeseriesref->[$c];
		$ref->{sendTS} = $sendTS[$c];
		$ref->{seqorg} = $orgseqs[$c];
		$ref->{delay} = $prevdelay if $c != 0 and $ref->{sendTS} - $prevTS < 100e-6;
		$prevdelay = $ref->{delay};
		$prevTS = $sendTS[$c];
	}
	return ($min, $max, $nout);
}

sub preprocess
{
	my $inputFile = shift;
	my $fileStartTime = shift;
	my $fileEndTime = shift;
	my $timeseriesref = shift;
	my $lostseqsref = shift;

	my ($min, $max, $nout) = 
		preprocessReader($ARGV[0], $ARGV[1], $ARGV[2], $timeseriesref, $lostseqsref);
	return ($min, $max, $nout);
}


=pod
my @timeseries = (); #array of hashes
my %lostseqs = ();

preprocess($ARGV[0], $ARGV[1], $ARGV[2], \@timeseries, \%lostseqs);

my $n = @timeseries;
for(my $c = 0; $c < $n; $c++)
{
	my $ref = $timeseries[$c];
	print "$ref->{seq} $ref->{delay} $ref->{sendTS} $ref->{seqorg}\n";
}
=end
=cut

1;

