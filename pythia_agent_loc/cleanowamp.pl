#!perl -w

use strict;
use myConfig;

# Cleans old files in the owamp directories
sub cleanOldFiles
{
	print "cleaning owamp files older than $myConfig::oldOwampThreshold hours in the past.\n";
	my $mintime = $myConfig::oldOwampThreshold * 60;
	system("find $myConfig::DATADIR/* -name \"*.owp\" -type f -mmin +$mintime -delete");
}

cleanOldFiles();