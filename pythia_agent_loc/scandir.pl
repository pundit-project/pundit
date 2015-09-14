<<<<<<< HEAD
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

if ($myConfig::psVersion == "3.3")
{
	require OWP::Utils;
}
else
{
	require perfSONAR_PS::RegularTesting::Utils;
}

require 'scanheap.pl';

my @sortList = ();
my %fileSeen = ();
#my %prevwsecs = ();

# number of files processed every time duration
my $process_count = 0;
my $process_ts = time();

sub debug_write_heapsize
{
	my $heap_filename = "debug_heap_size";
	open my $heap_fh, ">", $heap_filename or die $!;
	print $heap_fh scalar @sortList;
	close $heap_fh;
}

sub report_process_count
{
	my ($count) = @_;
	my $process_filename = "processed_count";
	open my $process_fh, ">", $process_filename or die $!;
	print $process_fh $process_count;
	close $process_fh;
}

sub scandir
{
	my $dir = shift;
	my $fileProcessor = shift;

	opendir(DIR, $dir) or die "Cannot open $dir: $!\n";
	for(readdir DIR)
	{
		my $file = "$dir/$_";
		if($file =~ /\.owp$/i and -f $file and !exists $fileSeen{$file})
		{
			my $ret = &$fileProcessor($file);
			$fileSeen{$file} = 1 if $ret != -1;
		}
	}
	close DIR;
}

# Scandir 2 takes a directory and finds the owamp subdirectories within it
# Calls scandir() on any directories found
# Only used for perfSONAR 3.4
sub scandir2
{
	my $dir = shift;
	my $fileProcessor = shift;

	foreach my $dirSearch (glob $dir . "owamp_*") 
	{
		next if ! -d $dirSearch;              # skip if it's not a directory
		scandir($dirSearch, $fileProcessor); # Pass it on to scandir()
	}
}

sub getTSFile
{
	my $filename = shift;
	my $sline = `owstats -R $filename | head -1 | cut -d ' ' -f 2`;
	chomp $sline;
	if ($myConfig::psVersion == "3.3")
	{
		return owptime2time($sline);
	}
	else
	{
		return perfSONAR_PS::RegularTesting::Utils::owptime2datetime($sline)->epoch();
	}
}

# Gets the start timestamp from an owp file
# Simplified version that gets it from the filename
sub getTSFile2
{
	my $filename = shift;
	$filename =~ s#^.*/##; # strip everything up to the last slash
	if ($filename =~ m/^(.*)_.*$/) # match the first part of the filename
	{
		if ($myConfig::psVersion == "3.3")
		{
			return owptime2time($1);
		} else {
			return perfSONAR_PS::RegularTesting::Utils::owptime2datetime($1)->epoch();
		}
	} else {
		return -1;
	}
}

sub checkFile
{
	my $filename = shift;
	#my $wsecs = (stat($filename))[9];
	my $wsecs = getTSFile2($filename);

	if ($wsecs > time() || $wsecs == -1)
	{
		return -1; ### e.g.: a file with no records; bug with owptime2time
	}
	
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

	# Note: We use owstats here to ensure the files aren't empty/incomplete
	my $eline = `owstats -R $filename | tail -1 | cut -d ' ' -f 2`;
	chomp $eline;
	
	my $ftime = -1;
	if ($myConfig::psVersion == "3.3")
	{
		$ftime = owptime2time($eline);
	}
	else
	{
		$ftime = perfSONAR_PS::RegularTesting::Utils::owptime2datetime($eline)->epoch();
	}
	
	return -1 if $ftime > time(); ### e.g.: a file with no records; bug with owptime2time
	return -1 if time() - (stat($filename))[9] > 2*$MINSCANDUR; #file not updated for over 10mins

	print "processing $filename ...\n";
	`perl events.pl $filename $starttime $endtime`; #XXX: replace by a procedure call

	return 0;
}

sub runScan
{
	while(1)
	{
		if ($myConfig::psVersion == "3.3")
		{
			# scan for files and add to job list
			scandir($DATADIR, \&checkFile);
		}
		else
		{
			scandir2($DATADIR, \&checkFile);
		}
		debug_write_heapsize();
		
		# run pending jobs
		while(1)
		{
			my $elem = popElem(\@sortList);
			last if !defined $elem;
			$process_count += 1; # increment counter
			my $elemts = $elem->{TS};
			print "pop..\n";
			# run from elemts to curtime-5mins if dur > 5mins
			my $elemRun = 0;
			my $curtime = time();
			
			# report values for check_mk
			if (($curtime - $process_ts) >= $myConfig::reportingDuration)
			{
				report_process_count($process_count);
				$process_count = 0;
				$process_ts = $curtime;
			}
			
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


=======
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


>>>>>>> branch 'master' of https://github.com/pundit-project/pundit.git
