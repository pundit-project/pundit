#!/usr/bin/perl
#
# Copyright 2016 Georgia Institute of Technology
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

package PuNDIT::Central::Localization::EvReceiver::MySQL;

use strict;
use Log::Log4perl qw(get_logger);
use threads;
use threads::shared;

# Database
use DBI;

=pod

=head1 PuNDIT::Central::Localization::EvReceiver::MySQL.pm

Interface to get events stored in MySQL

=cut

my $logger = get_logger(__PACKAGE__);

# Init the db connection
sub new
{
	my ($class, $cfgHash, $fedName) = @_;
    
	# init the DBI
	my $host = $cfgHash->{'pundit_central'}{$fedName}{'ev_receiver'}{'mysql'}{"host"};
	my $port = $cfgHash->{'pundit_central'}{$fedName}{'ev_receiver'}{'mysql'}{"port"};
	my $database = $cfgHash->{'pundit_central'}{$fedName}{'ev_receiver'}{'mysql'}{"database"};
	my $user = $cfgHash->{'pundit_central'}{$fedName}{'ev_receiver'}{'mysql'}{"user"};
	my $pw = $cfgHash->{'pundit_central'}{$fedName}{'ev_receiver'}{'mysql'}{"password"};
	
	my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $pw) or return undef;
		
	my $self = {
        _config => $cfgHash,
        _dbh => $dbh,
    };
    
    bless $self, $class;
    return $self;
}

# Cleanup
sub DESTROY
{
    my ($self) = @_;
    
    my $dbh = $self->{'_dbh'};
    
    $dbh->disconnect if $dbh;
}

# retrieves the latest values from the db
# formatted to match output format
sub getLatestEvents
{
    my ($self, $lastTS) = @_;
    
    return $self->getEventsDb($lastTS, undef)
}

# Retrieve from db
sub getEventsDb
{
	my ($self, $startTS, $endTS) = @_;
	
	# Extract from self
	my $dbh = $self->{'_dbh'};
	my $sth;
	
	if (defined($endTS))
	{
	    $logger->debug("Querying events from $startTS to $endTS");
	    
		# Normal case: Bounded query
		my $sql = 
		"SELECT startTime, endTime, srchost, dsthost, baselineDelay, detectionCode, queueingDelay, lossRatio, reorderMetric FROM status 
			WHERE (startTime >= ?) AND 
				(startTime <= ?)
			ORDER BY srchost ASC, dsthost ASC, startTime ASC";
		$sth = $dbh->prepare($sql) or return undef;
		
		# Bind the current timestamp
		$sth->execute($startTS, $endTS) or return undef;
	}
	else
	{
	    $logger->debug("Querying events from $startTS onwards");
	    
		# Special case when no endTS: Get everything until the end
		my $sql = 
		"SELECT startTime, endTime, srchost, dsthost, baselineDelay, detectionCode, queueingDelay, lossRatio, reorderMetric FROM status 
			WHERE (startTime >= ?) OR (startTime < ? AND ? < endTime)
			ORDER BY srchost ASC, dsthost ASC, startTime ASC";
		$sth = $dbh->prepare($sql) or return undef;
		
		# Bindings have different params
		$sth->execute($startTS, $startTS, $startTS) or return undef;
	}
	
	return undef if (!$sth);
	
	# Init an empty hash
	my %evHash = ();
	
	# This fetches the contents of the db into a hash
	# Supposedly slow
	while (my $ref = $sth->fetchrow_hashref) 
	{
	    if (!exists($evHash{$ref->{'srchost'}}))
	    {
	        $evHash{$ref->{'srchost'}} = {};
	    }
	    if (!exists($evHash{$ref->{'srchost'}}{$ref->{'dsthost'}}))
        {
            $evHash{$ref->{'srchost'}}{$ref->{'dsthost'}} = ();
        }
		push (@{$evHash{$ref->{'srchost'}}{$ref->{'dsthost'}}}, $ref);
	}
	
	return \%evHash;
}

1;