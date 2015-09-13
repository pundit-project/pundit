#!/usr/bin/perl
package Loc;

use strict;

require "loc_config.pl";
#require Loc::Config;
require "loc_processor.pl";
#require Loc::Processor;

use POSIX qw(floor setsid strftime);

=pod

=head1 DESCRIPTION

This is the main entry point for the localisation code.
Run this script to start all subcomponents

=cut

# Calculates the id for a given bucket given a timestamp
sub calc_bucket_id
{
	my ($curr_ts, $windowsize) = @_;
	return ($windowsize * floor($curr_ts / $windowsize));
}

sub main
{
	my $cfg = new Loc::Config("localization.conf");
	my $windowsize = $cfg->get_param("loc", "window_size");
    my $time_lag = $cfg->get_param("loc", "time_lag");
    	
	my $processor = new Loc::Processor($cfg);
	
	my $last_time = calc_bucket_id(time, $windowsize) - ($time_lag * 60);
	my $sleep_time = 0;
	# run the loop
	while (1)
	{
		print "$last_time (", strftime("%F %T", localtime($last_time)), "):\n";
		$processor->process_time($last_time);
		$last_time += $windowsize;
		$sleep_time = $last_time + ($time_lag * 60) - time();
		sleep $sleep_time if $sleep_time > 0;	
	}
}


umask 0;
open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
open(STDOUT, ">>run.log") or die;
open STDERR, '>>run.log' or die "Can't write to /dev/null: $!";
defined(my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";

print "Starting server..\n";
#while(1)
#{
#	`perl tree.pl`;
#	`perl scandir.pl >> run.log 2>&1`;
#}
#
main;
