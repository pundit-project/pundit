#!perl -w

use strict;
use myConfig;

require 'dbstore.pl';

sub getsrcdst
{
	my $owpfile = shift;
	my $str = `./owstats $owpfile | grep "owping statistics from "`;
	chomp $str;
	my @obj = split(/\s+/, $str);

	my $src = $obj[4];
	my $dst = $obj[6];
	$src =~ s/\[//; $src =~ s/]:.*//;
	$dst =~ s/\[//; $dst =~ s/]:.*//;
	return ($src, $dst);
}
 
sub getX
{
        my $g = shift;
        my $val = shift;
        return floor($g->{left} + ($g->{right}-$g->{left}) * 
			1.0*($val-$g->{x_min})/($g->{x_max}-$g->{x_min}) + 0.5);
}
sub printTS
{
	if ($myConfig::plotGraph == 1) {
		require GD::Graph::linespoints;
	}

	my $st = shift;
	my $et = shift;
	my $stime = shift;
	my $offset = shift;
	my $ref = shift;
	my %lostseqs = %$ref;
	my $startS = shift;
	my $endS = shift;
	my $iFile = shift;
	my $str = shift;
	#my $timeserref = shift;
	my $dref = shift;
	my $tref = shift;

	### for owp files only:
	my ($src, $dst) = getsrcdst($iFile);

	my $pngplot = undef;
	if ($myConfig::plotGraph == 1) {
		my $graph = GD::Graph::linespoints->new(400, 300);
		$graph->set(
			x_label => 'Time (s)',
			y_label => 'One-way delay (ms)',
			#title   => 'Some simple graph',
			r_margin => 15,
			transparent => 0,
			x_tick_number => 'auto',
			marker_size => 1
		) or return -1;
	
		my $xmin = $st-$stime-$offset;
		my $xmax = $et-$stime+$offset;
		my $n = @$dref;
		#my $n = @$timeserref;
		my @data = (); my @t = (); my @d = ();
		for(my $c = 0; $c < $n; $c++)
		{
			my $x = $tref->[$c] - $stime;
			#next if $x < $xmin;
			#last if $x > $xmax;
			push(@t, $x); push(@d, $dref->[$c]);
			#my $x = $timeserref->[$c]->{sendTS} - $stime;
			#next if $x < $xmin;
			#last if $x > $xmax;
			#push(@t, $x); push(@d, $timeserref->[$c]->{delay});
		}
		$data[0] = \@t; $data[1] = \@d;
		my $gd = $graph->plot(\@data) or return -1;
	
		for(my $s = $startS; $s <= $endS; $s++)
		{
			#( $lostseqs{$s}-$stime ) if exists $lostseqs{$s};
			if(exists $lostseqs{$s})
			{
				my $xp = getX($graph, $lostseqs{$s}-$stime);
				$graph->{graph}->line($xp, $graph->{top}, $xp, $graph->{bottom}, 1);
			}
		}
		#my $file = $iFile;
		#$file =~ s/^/$stime\_/;
		#$file =~ s/\//_/g;
		#$file =~ s/$/.png/;
		#open(IMG, ">diag-plots/$file") or die $!;
		#binmode IMG;
		#print IMG $gd->png;
		#close IMG;
	
		$pngplot = $gd->png
		
	}
	else {
		$pngplot = undef
	}
	
	my $diagstr = $str; 
	chomp $diagstr; 
	$diagstr =~ s/.*diag: //;
	writeEventDB($st, $et, $src, $dst, $diagstr, $pngplot, $iFile); #"diag-plots/$file");
}

sub printReorderEvent
{
	my $st = shift;
	my $et = shift;
	my $iFile = shift;
	my $diagstr = shift;

	### for owp files only:
	my ($src, $dst) = getsrcdst($iFile);

	writeReorderEventDB($st, $et, $src, $dst, $diagstr, $iFile);
};



sub printTS_gnuplot
{
	my $st = shift;
	my $et = shift;
	my $stime = shift;
	my $offset = shift;
	my $ref = shift;
	my %lostseqs = %$ref;
	my $startS = shift;
	my $endS = shift;
	my $iFile = shift;
	my $str = shift;

	### for owp files only:
	my ($src, $dst) = getsrcdst($iFile);

	open(OUT, ">/tmp/seqs.txt") or die;
	for(my $s = $startS; $s <= $endS; $s++)
	{
		print STDERR "LOST/REORDERED $s t $lostseqs{$s}\n" if exists $lostseqs{$s};
		print OUT ($lostseqs{$s}-$stime)."\n" if exists $lostseqs{$s};
	}
	close OUT;

	my $n = `cat /tmp/seqs.txt | wc -l`; chomp $n;
#	return if $n == 0;

print STDERR "plotting seqs $startS to $endS, path $src->$dst\nstring $str\n";

#return 0 if $str =~ /C-S: 1/;

# sort by recv TS
#`cat ts.txt | awk '{printf \"%d %f %f %f\n\",\$1,\$2,(\$3+\$2*1e-3),\$3;}' | sort -g -k3 > ts-r.txt`;


my $file = $iFile;
$file =~ s/^/$stime\_/;
$file =~ s/\//_/g;
#$file =~ s/archive_/ESnet_$stime\_/;
#$file =~ s/.*zurawski_OWAMP_/I2_/;
#$file =~ s/.*result_/PL_$stime\_/;
$file =~ s/.*lab.org_/SP_$stime\_/;
$file =~ s/SP_/SP_$stime\_/;
#$file =~ s/\.owp/.owp.ps/;
$file =~ s/$/.png/;
#if(-e $file)
#{
#	my $r = int(rand(10000));
#	my $file .= "$r.ps";
#}
print "gnuplot $file\n";

#XXX: note: gnuplot has a bug - it misplaces the arrow
my $shell_out = <<`SHELL`;
./gnuplot -persist <<EF
set term dumb

set xl 'time (s)'
set yl 'OWD (ms)'

set xr[$st-$stime-$offset:$et-$stime+$offset]

a(x) = sprintf("replot %d,t w l ls 0 lc 2 lw 3 axes x1y2 not;\\n", x)
ARROW=""
f(x)=(ARROW=ARROW.a(x))
set parametric
plot '/tmp/seqs.txt' u 1:(f(\\\$1)) 

plot "ts.txt" u (\\\$$tfield-$stime):$dfield w lp not
eval(ARROW)

#set label 8 "str" tc lt 3
#set title "$str"

set term png
set out 'diag-plots/$file'
replot

EF
SHELL
#<>

my $diagstr = $str; chomp $diagstr; $diagstr =~ s/.*diag: //;
writeEventDB($st, $et, $src, $dst, $diagstr, "diag-plots/$file");

};


### unused:

sub printPDF {
	my $ref = shift;
	my $h = shift;
	my $n = shift;
	my $rCI = shift;
	my $lCI = shift;
	my $t = shift;
	my $curW = shift;
	my $stime = shift;
	my $offset = shift;
	my $binwidth = shift;

	my @arr = @$ref;
	my $min = $arr[0]; # assume in ms.
	my $max = $arr[$n-1];
	my $nbkts = ($max - $min)/$binwidth; # buckets of 100us

	open(OUT, ">/tmp/pdf.txt") or die;
	for(my $x = $min-$binwidth; $x <= $max+$binwidth; $x += $binwidth)
	{
		my $pdf = getKernelEstimate($x, $ref, $h, $n);
		print OUT "$x $pdf\n";
	}
	close OUT;

my $shell_out = <<`SHELL`;
gnuplot -persist <<EF
set multiplot layout 2,1
plot "/tmp/pdf.txt" u 1:2 w lp not
set xr[$t-$curW-$stime-$offset:$t-$stime+$offset]
plot "ts.txt" u (\\\$$tfield-$stime):$dfield w lp not, $rCI t '$rCI', $lCI t '$lCI'
unset multiplot
EF
SHELL
<>

};

sub printTSfile {
	my $st = shift;
	my $et = shift;
	my $stime = shift;
	my $offset = shift;
	my $label = shift;

	my $r = int(rand(10000));
	my $file = "$r.ps";

my $shell_out = <<`SHELL`;
gnuplot -persist <<EF
set term postscript
set out '$file'
set xr[$st-$stime-$offset:$et-$stime+$offset]
set xl 'time (s)'
set yl 'OWD (ms)'
set title '$label'
plot "ts.txt" u (\\\$$tfield-$stime):$dfield w lp not
EF
SHELL
};

sub printTSarr {
	my $ref = shift;
	my $tref = shift;
	my $stime = shift;
	my $offset = shift;

open(OUT, ">/tmp/ts.txt") or die;
my $n = @$ref;
for(my $c = 0; $c < $n; $c++)
{
print OUT "$tref->[$c] $ref->[$c]\n";
}
close OUT;

my $shell_out = <<`SHELL`;
gnuplot -persist <<EF
set xl 'time (s)'
set yl 'OWD (ms)'
plot "/tmp/ts.txt" u (\\\$1-$stime):2 w lp not
EF
SHELL
};


1;

