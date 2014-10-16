#!/usr/bin/perl
package Loc::EvReceiver::Mysql;

use strict;

# Database
use DBI;

# Debug
#use POSIX qw(floor);
#use Data::Dumper;

# Init the db connection
# Returns
# 1 if success, 0 otherwise
sub new
{
	my $class = shift;
    my $cfg = shift;
    
	# init the DBI
	my $host = $cfg->get_param("mysql", "host");
	my $port = $cfg->get_param("mysql", "port");
	my $database = "pythia";
	my $user = $cfg->get_param("mysql", "user");
	my $pw = $cfg->get_param("mysql", "password");
	
	my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $pw) or return undef;
		
	my $self = {
        _config => $cfg,
        _dbh => $dbh,
    };
    
    bless $self, $class;
    return $self;
}

# Retrieve from db
sub get_events_db
{
	my ($self, $startTS, $endTS) = @_;
	
	# Extract from self
	my $sth = $self->{'_sth'};
	my $dbh = $self->{'_dbh'};
	
	if ($endTS != 0)
	{
		# Normal case: Bounded query
		my $sql = 
		"SELECT startTime, srchost, dsthost, delayMetric, lossMetric, reorderMetric FROM localizationdata 
			WHERE (startTime >= ?) AND 
				(startTime <= ?)
			ORDER BY startTime ASC";
		$sth = $dbh->prepare($sql) or return undef;
		
		# Bind the current timestamp
		$sth->execute($startTS, $endTS) or return undef;
	}
	else
	{
		# Special case when no endTS: Get everything until the end
		my $sql = 
		"SELECT startTime, srchost, dsthost, delayMetric, lossMetric, reorderMetric FROM localizationdata 
			WHERE (startTime >= ?)
			ORDER BY startTime ASC";
		$sth = $dbh->prepare($sql) or return undef;
		
		# Bindings have different params
		$sth->execute($startTS) or return undef;
	}
	
	return undef if (!$sth);
	
	# Init an empty array
	my @ev_array = ();
	
	# This fetches the contents of the db into a hash
	# Supposedly slow
	while (my $ref = $sth->fetchrow_hashref) 
	{
		push (@ev_array, $ref);
#		print "sth->fetchrow_hashref\n";
#		print Dumper $ref;
	}
	
	return \@ev_array;
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

=pod
# Test code
my $windowsize = 5;
# Calculates the id for a given bucket given a timestamp
sub calc_bucket_id
{
	my ($curr_ts) = @_;
	return ($windowsize * floor($curr_ts / $windowsize));
}
mysql_receiver_init();
print Dumper get_events_db(calc_bucket_id(time) - 700, calc_bucket_id(time) - 500);
mysql_receiver_exit();
=cut

1;