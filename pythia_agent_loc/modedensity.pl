#!perl -w

use strict;

my $binwidth = $ARGV[0];
chomp $binwidth;

open(IN, "ts.pdf") or die;

my $prev = -1;
my $cur = -1;
my $next = -1;

my $curmax = -1;
my $curdensity = 0;

while(my $line = <IN>)
{
	next if $line =~ /^"x" /;
	chomp $line;
	my @obj = split(/\s+/, $line);

	$next = $obj[2];

	if($prev != -1)
	{
		#minima
		if($prev > $cur and $next > $cur)
		{
			print "max $curmax density $curdensity\n";
			$curmax = $obj[1];
			$curdensity = 0;
		}
	}

	$curmax = $obj[1] if $curmax < $obj[1];
	$curdensity += $binwidth * $next;


	$prev = $cur;
	$cur = $next;
}

print "max $curmax density $curdensity\n";

close IN;

