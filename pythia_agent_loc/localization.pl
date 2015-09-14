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

use Data::Dumper;
use POSIX;

require 'printfunc.pl';
require 'dbstore.pl';

# Globals
my $windowsize = 5; # Number of seconds to analyse
my $mode_history_max = 10; # The number of modes to use for analysis
my $nextseq; # expected next seq
my $debug = 0; # Debug flag. Set this off for normal operation

# For storing in db
my @db_delay_metrics = ();
my @db_loss_metrics = ();
my @db_stimes = ();

# Temp variables
my @buffered_delay_metrics = ();
my @buffered_ts = ();
my @buffered_seqno = ();

# The array of the last X modes
my @mode_history = ();

# We need to align the packets

# Scan an array and get the min
sub get_min
{
	my ($array) = @_;
	my $countmax = scalar(@$array);
	
	return -1 if ($countmax == 0);
	 
	my $min = @$array[0];
	for (my $i = 1; $i < $countmax; $i++)
	{
		$min = @$array[$i] if (@$array[$i] < $min);
	}
	return $min;
}

# Calculates the delay metric
sub delay_metric
{
	my ($oldmode, $ref) = @_;
	
	my $n = scalar(@$ref);

	# error check for array
	return -1 if $n == 0;
	
	# Collect the last few oldmodes from detection logic - use median or min on those
	# add to mode history 
	push(@mode_history, $oldmode);
	# chop the first entry if we exceed the max
	shift(@mode_history) if (scalar(@mode_history) > $mode_history_max);
	
	my $min = get_min(\@mode_history);
	my $sum = 0;

	print "delay calc: Min: ${min}\n";
	#print Dumper $ref;

	for(my $c = 0; $c < $n; $c++)
	{
#		my $oldsum = $sum;
		$sum += $ref->[$c]; #XXX: check for overflow
#		if ($oldsum > $sum)
#		{
#			print "Overflow detected. ${oldsum} + ${ref->[$c]} = ${sum}\n";
#			$sum = $oldsum;
#		}
	}
	
	$sum -= $min;
	$sum /= $n;
	return $sum;
};

# Finds if a loss happened in a window
sub find_loss
{
	my ($seqno, $lostseqs) = @_;

	# loop over the array
	foreach my $curr_seqno (@$seqno)
	{
		# Check the seqno for losses
		if ($curr_seqno != $nextseq)
		{
			#print "Debug: Found a loss at seqno ${curr_seqno}. Expected ${nextseq}\n";
			$nextseq = @$seqno[-1] + 1; # Just advance the counter to the end of the window
			
			return 1; # Quit indicating a find
		}
		# Advance the seq no
		$nextseq++;
	}
	return 0;
}

# Initialise the localisation stuff
sub localizationInit
{	
	# Cleanup variables
	@db_delay_metrics = ();
	@db_loss_metrics = ();
	@db_stimes = ();
	@buffered_delay_metrics = ();
	@buffered_ts = ();
	@buffered_seqno = ();
	@mode_history = ();
}

# Cleanup for the localisation module
# Currently does nothing
sub localizationDestroy
{
	return;
}


# Sets the sequence number to start from
# Used for loss detection
sub localization_set_startseq
{
	($nextseq) = @_;	
}

# Adds an entry to the local localization table(s)
# Doesn't commit to db
sub localizationAddEntry
{
	my ($ref, $seqno, $ts, $lostseqs, $oldmode) = @_;
	
	# Error check that all inputs are the same length
#	if ((scalar($ref) != scalar($seqno)) || (scalar($ref) != scalar($ts)))
#	{
#		print "Error: input arrays don't match!\n";
#		return; 
#	}
	
	# Append current entries to buffered values 
	push(@buffered_delay_metrics, @$ref); # sorted
	push(@buffered_seqno, @$seqno); # is sorted by seq no
	push(@buffered_ts, @$ts); # sorted, in seconds
	
	# Start timestamp is the first timestamp
	my $start_ts = floor($buffered_ts[0]);

	# Crop if start_ts isn't a multiple of windowsize
	if ($start_ts % $windowsize != 0)
	{
		#print "Cropping ${start_ts}...\n";
		#print Dumper \@buffered_ts;

		my $count = scalar(@buffered_delay_metrics);
		
		for (my $i = 0; $i < $count; $i++)
		{
			my $curr_ts = floor($buffered_ts[$i]);
			#print "Checking ${curr_ts}\n";
			if ($curr_ts % $windowsize == 0)
			{
				# Remove everything before that
				my $last_entry = $i - 1;
								
				# remove from buffered arrays
				splice(@buffered_delay_metrics, 0, $last_entry + 1);
				splice(@buffered_seqno, 0, $last_entry + 1);
				splice(@buffered_ts, 0, $last_entry + 1);
				last;
			}
		}
		
		# Assign the new start_ts
		my $start_ts = floor($buffered_ts[0]);

		#print "Cropped until ${start_ts}\n";
	}	
	# check that the buffers contain at least 1 window of data
	if (($buffered_ts[-1] - $start_ts) < $windowsize)
	{
		print "Debug: Not enough entries to process\n";
		return;
	}
	
	my $countmax = scalar(@buffered_delay_metrics);
	
	# Loop over data looking for a window of data
	for (my $i = 0; $i < $countmax; $i++)
	{
		my $curr_ts = floor($buffered_ts[$i]);
		
		if ((($curr_ts - $start_ts) >= $windowsize) && ($curr_ts % $windowsize == 0)) # run once a timestamp is a multiple of the window size 
		{
			# Only consider up to the last entry
			my $last_entry = $i - 1;
			
			# extract the window
			my @window_delay_metric = @buffered_delay_metrics[0 .. $last_entry];
			my @window_seqno = @buffered_seqno[0 .. $last_entry];
			
			# Calc the delay metric
			my $dmetric = delay_metric($oldmode, \@window_delay_metric);
			return if $dmetric == -1;
		
			# Scan the sequence numbers for loss
			# if exists in the hash, is guaranteed to be lost
			my $lmetric = find_loss(\@window_seqno, $lostseqs);
		
			# Push into db arrays
			push(@db_delay_metrics, $dmetric);
			push(@db_loss_metrics, $lmetric);
			push(@db_stimes, $start_ts);
			
			# remove from buffered arrays
			splice(@buffered_delay_metrics, 0, $last_entry + 1);
			splice(@buffered_seqno, 0, $last_entry + 1);
			splice(@buffered_ts, 0, $last_entry + 1);
			
			# break the loop. 
			# We assume that there's 1 window max in the buffer
			last;
		}
	}
#	print Dumper \@buffered_delay_metrics;
#	print Dumper \@buffered_seqno;
#	print Dumper \@buffered_ts;
};

# Loops over the file times and builds entries from that
sub localizationBuildGoodEntries
{
	my ($fileStartTime, $fileEndTime, $max, $min) = @_;

	print "Building good entries... ${fileStartTime} ${fileEndTime}\n";
	
	my $avg = ($max + $min)/2;
	# We need to align the start time to the window size
	my $file_start = floor($fileStartTime) - (floor($fileStartTime) % $windowsize) + $windowsize;
	my $file_end = floor($fileEndTime);
	
	# Loop over the range
	for (my $i = $file_start; $i < $file_end; $i += $windowsize)
	{		
		# Push into db arrays
		push(@db_delay_metrics, $avg);
		push(@db_loss_metrics, 0);
		push(@db_stimes, $i);
	}
	return;
}

# Writes localization data to SQL database
sub localizationCommitData
{
	my $owpfile = shift;
	my ($src, $dst) = getsrcdst($owpfile);

	# Don't write to db if debug is on
	if ($debug == 1)
	{ 
		print_loc_commit_data($src, $dst, \@db_delay_metrics, \@db_loss_metrics, \@db_stimes);
		return;
	}
	writeLocalizationDataDB($src, $dst, \@db_delay_metrics, \@db_loss_metrics, \@db_stimes);
};

# print function for db data
sub print_loc_commit_data
{
	my ($src, $dst, $db_delay_metrics, $db_loss_metrics, $db_stimes) = @_;
	
	my $countmax = scalar(@$db_stimes);
	for (my $i = 0; $i < $countmax; $i++)
	{
		print STDERR "${db_stimes[$i]}\t${src}\t${dst}\t${db_delay_metrics[$i]}\t${db_loss_metrics[$i]}\n";
	}
	 
}

1;
