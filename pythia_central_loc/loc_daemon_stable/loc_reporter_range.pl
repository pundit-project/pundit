#!/usr/bin/perl
package Loc::Reporter::Range;

use strict;
use DBI;

# debug. Remove this for production
#use Data::Dumper;
#require "loc_config.pl";
#my $cfg = new Loc::Config("localization.conf");

# Creates a new object
sub new
{
	my $class = shift;
    my $cfg = shift;
    my $metric = shift;
    
	# init the DBI
	my $host = $cfg->get_param("mysql", "host");
	my $port = $cfg->get_param("mysql", "port");
	my $database = "pythia";
	my $user = $cfg->get_param("mysql", "user");
	my $pw = $cfg->get_param("mysql", "password");
	
	my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $pw) or return undef;
	my $sql;
	
	if ($metric eq 'delayMetric')
	{
		# Create the table if it doesn't exist
		$dbh->do("CREATE TABLE IF NOT EXISTS delay_range_results (
			start_time INT,
			link VARCHAR(25),
			range_start FLOAT,
			range_end FLOAT
			);");
		
		$sql = "INSERT INTO delay_range_results (start_time, link, range_start, range_end) VALUES (?, ?, ?, ?)";
	}
	
	return if (!defined($sql));
	my $sth = $dbh->prepare($sql) or return undef;
	
	my $self = {
        _config => $cfg,
        _dbh => $dbh,
        _sth => $sth
    };
    
    bless $self, $class;
    return $self;
}

# Writes the result array to the database
sub write_data
{
	my ($self, $start_time, $data_array) = @_;
	
	my $sth = $self->{'_sth'};
	my $dbh = $self->{'_dbh'};
	
	my $element;
	
	foreach $element (@$data_array)
	{
		$sth->execute($start_time, $$element{'link'}, $$element{'range'}[0], $$element{'range'}[1]) or print "$dbh->errstr\n";
	}
}

# Cleanup
sub DESTROY
{
	my $self = shift;
	
	my $sth = $self->{'_sth'};
	my $dbh = $self->{'_dbh'};
	
	$sth->finish if $sth;
	$dbh->disconnect if $dbh;
}

1;

=pod
my $rpt = new Loc::Reporter::Range($cfg);
my @data_array = (
	{
		'link' => "1.1.1.1",
		'range' => [2.5, 2.75],
	},
	{
		'link' => "1.1.1.2",
		'range' => [2.5, 3.75],
	}
);
$rpt->write_data(100, \@data_array);
=cut