#!/usr/bin/perl
package Loc::EvReceiver;

use strict;
require "ev_receiver_mysql.pl";

# debug. Remove this for production
use Data::Dumper;
#require "loc_config.pl";
#my $cfg = new Loc::Config("localization.conf");

=pod

=head1 DESCRIPTION

This script reads the events from the database and processes it into a data structure that the loc_processor can use.

=cut

# dummy event table
# Has an extra column indicating whether it's processed or not
my @event_table = 
(
	{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
	{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 55, 'processed' => 0,},
	{ 'start' => time - 9, 'end' => time - 5, 'src' => "A1", 'dst' => "D1", 'metric' => 57, 'processed' => 0,},
);

# Top-level init for event receiver
sub new
{
	my $class = shift;
    my $cfg = shift;
    
	# init the sub-receiver
	my $mysql_rcv = new Loc::EvReceiver::Mysql($cfg);
	return undef if (!$mysql_rcv);
	
	my $windowsize = $cfg->get_param('loc', 'window_size');
	
	my $self = {
        _config => $cfg,
        _rcv => $mysql_rcv,
    };
    
    bless $self, $class;
    return $self;
}


# Top-level exit for event receiver
sub DESTROY
{
	# Do nothing?
}

# Returns the event table
# Parameters: 
# $in_first_ev_ts - timestamp of the first event to get. Leave as 0 if you want all
# $in_last_ev_ts - timestamp of the last event to get. Leave as 0 if you want all
# Returns an array containing:
# $out_first_ev_ts - timestamp of the returned first event
# $out_last_ev_ts - timestamp of the returned last event
# $out_table - Array of events
sub get_event_table 
{
	my ($self, $in_first_ev_ts, $in_last_ev_ts) = @_;

	# Get the event table from db
	my $out_table = $self->{'_rcv'}->get_events_db($in_first_ev_ts, $in_last_ev_ts - $self->{'windowsize'});
	
	# Return nothing if no results
	return (0, 0, undef) if (!$out_table);
	
	# Assume that it's been sorted by the db	
	
	# get the timestamps from the table
	my $out_first_ev_ts = $$out_table[0]->{'startTime'}; 
	my $out_last_ev_ts = $$out_table[-1]->{'startTime'} + $self->{'windowsize'};
	
	# return the array
	return ($out_first_ev_ts, $out_last_ev_ts, $out_table);
}


=pod
# Test code
my $ev_receiver = new Loc::EvReceiver($cfg);
my ($start, $end, $x) = $ev_receiver->get_event_table(0, 0, "delayMetric", 1);
print $start . " to " . $end . "\n";
print Dumper $x;
=cut

