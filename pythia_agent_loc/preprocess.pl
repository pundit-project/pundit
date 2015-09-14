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
	
	my $lost_count = 0;
	my $reorder_metric = 0;
	
	# switches for owamp 3.4+
	open(IN, "owstats -v -U $inputFile |") or die;
	while(my $line = <IN>)
	{
		# grab a reordering metric if any. We calculate our own, so no need to preserve all values
		$reorder_metric = $1 if ($line =~/^\d*-reordering = ([0-9]*\.?[0-9]*)/);
		
		# grab the number of lost packets
		$lost_count = $1 if ($line =~ /^\d*\ssent, (\d*) lost/);
		
		next if $line !~ /^seq_no/; # skip lines that are not owamp measurements
		chomp $line;
		
		# replace equals and tabs with spaces, then split on space
		$line =~ s/=/ /g; 
		$line =~ s/\t/ /g;
		my @obj = split(/\s+/, $line);

		if($line !~ /LOST/)
		{
			# skip values that are out of range
			next if $obj[10] < $fileStartTime;
			last if $obj[10] > $fileEndTime;
		}
		else
		{
			# note sequence number of loss
			$lostseqsref->{$obj[1]} = 1;
			next;
		}

		# Delay
		my $d = $obj[3];

		# Seq no and send timestamp
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
	return ($min, $max, $nout, $lost_count, $reorder_metric);
}

sub preprocess
{
	my $inputFile = shift;
	my $fileStartTime = shift;
	my $fileEndTime = shift;
	my $timeseriesref = shift;
	my $lostseqsref = shift;

	my ($min, $max, $nout, $loss, $reorder) = 
		preprocessReader($ARGV[0], $ARGV[1], $ARGV[2], $timeseriesref, $lostseqsref);
	return ($min, $max, $nout, $loss, $reorder);
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

