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
use threads;

require 'scanheap.pl';

my @sortList = ();
my %fileSeen = ();
#my %prevwsecs = ();

sub scandir
{
	my $dir = shift;
	my $fileProcessor = shift;

	opendir(DIR, $dir) or die "Cannot open $dir: $!\n";
	for(readdir DIR)
	{
		my $file = "$DATADIR/$_";
		if(-f $file and !exists $fileSeen{$file})
		{
			my $ret = &$fileProcessor($file);
			$fileSeen{$file} = 1 if $ret != -1;
		}
	}
	close DIR;
}

sub getTSFile
{
	my $filename = shift;
	#my $sline = `owstats -R $filename | head -1 | cut -d ' ' -f 2`;
	my $sline = `./owpingone $filename | head -1 | cut -d ' ' -f 2`;
	chomp $sline;
	return owptime2time($sline);
}

sub checkFile
{
use lib '/opt/perfsonar_ps/perfsonarbuoy_ma/lib/';
use OWP::Utils;

	my $filename = shift;
	#my $wsecs = (stat($filename))[9];
	my $wsecs = getTSFile($filename);

	return -1 if $wsecs > time(); ### e.g.: a file with no records; bug with owptime2time

	#return if exists $prevwsecs{$filename} and $wsecs == $prevwsecs{$filename};
	#$prevwsecs{$filename} = $wsecs;
	print "got file: $filename $wsecs\n";

	my %elem = ();
	$elem{TS} = $wsecs;
	$elem{FILE} = $filename;
	addElem(\@sortList, \%elem);

	return 0;
}

sub runFile
{
	my $filename = shift;
	my $starttime = shift;
	my $endtime = shift;

	my $eline = `owstats -R $filename | tail -1 | cut -d ' ' -f 2`;
	chomp $eline;
	my $ftime = owptime2time($eline);

	return -1 if $ftime > time(); ### e.g.: a file with no records; bug with owptime2time
	return -1 if time() - (stat($filename))[9] > 2*$MINSCANDUR; #file not updated for over 10mins

	print "executing..\n";
	`perl events.pl $filename $starttime $endtime`; #XXX: replace by a procedure call

	return 0;
}

sub runScan
{
	while(1)
	{
		# scan for files and add to job list
		scandir($DATADIR, \&checkFile);

		# run pending jobs
		while(1)
		{
			my $elem = popElem(\@sortList);
			last if !defined $elem;
			my $elemts = $elem->{TS};
print "pop..\n";
			# run from elemts to curtime-5mins if dur > 5mins
			my $elemRun = 0;
			my $curtime = time();
			if($curtime - $elemts > 2*$MINSCANDUR)
			{
				print "run $elem->{FILE}: $elemts to $curtime-5mins\n";

				my $ret = runFile($elem->{FILE}, $elemts, $curtime-$MINSCANDUR);
				next if $ret == -1; # finished analyzing the file; skip it

				$elem->{TS} = $curtime - $MINSCANDUR;
				$elemRun = 1;
			}
			print "heap: ".addElem(\@sortList, $elem)."\n"; # add file back to heap
			# if we didn't run any from the heap, the heap elements are too "new"
			last if $elemRun == 0;
			#print "$elemts ".($curtime - $elemts)."\n";
		}

		print "\n";
		sleep(1);
	}
};

runScan();


