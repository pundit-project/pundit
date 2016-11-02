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

package PuNDIT::Central::Localization::Reporter::MySQL;

use strict;
use Log::Log4perl qw(get_logger);
use DBI;

=pod

=head1 PuNDIT::Central::Localization::Reporter::MySQL

Handles the writing back of localization events to the MySQL database backend

=cut

my $logger = get_logger(__PACKAGE__);

# Creates a new object
sub new
{
    my ( $class, $cfgHash, $fedName ) = @_;

    # init the DBI
    my $host = $cfgHash->{'pundit_central'}{$fedName}{'reporting'}{'mysql'}{"host"};
    my $port = $cfgHash->{'pundit_central'}{$fedName}{'reporting'}{'mysql'}{"port"};
    my $database = $cfgHash->{'pundit_central'}{$fedName}{'reporting'}{'mysql'}{"database"};
    my $user = $cfgHash->{'pundit_central'}{$fedName}{'reporting'}{'mysql'}{"user"};
    my $password = $cfgHash->{'pundit_central'}{$fedName}{'reporting'}{'mysql'}{"password"};

    # make the db connection here, refreshing it if it dies later
    my $dsn = "DBI:mysql:$database:$host:$port";
    my $dbh = DBI->connect($dsn, $user, $password);
    if (!$dbh)
    {
        $logger->error("Couldn't initialize DBI connection. Quitting");
        return undef;
    }

    # Create the table if it doesn't exist
    $dbh->do(
        "CREATE TABLE IF NOT EXISTS localization_events (
    	ts TIMESTAMP,
    	link_ip INT UNSIGNED,
    	link_name VARCHAR(256),
    	det_code TINYINT UNSIGNED,
    	val1 INT UNSIGNED NULL,
    	val2 INT UNSIGNED NULL
    	);"
    );

    my $sql = "INSERT INTO localization_events (ts, link_ip, link_name, det_code, val1, val2) 
               VALUES (FROM_UNIXTIME(?), INET_ATON(?), ?, ?, ?, ?)";

    my $sth = $dbh->prepare($sql);
    if (!$sth)
    {
        $logger->error("Failed to prepare DBH. Quitting");
        return undef;
    }

    my $self = {
        '_dsn'      => $dsn,
        '_user'     => $user,
        '_password' => $password,
        '_dbh'      => $dbh,
        '_sql'      => $sql,
        '_sth'      => $sth,
    };

    bless $self, $class;
    return $self;
}

# Cleanup
sub DESTROY
{
    my $self = shift;

    my $sth = $self->{'_sth'};
    my $dbh = $self->{'_dbh'};

    $sth->finish     if $sth;
    $dbh->disconnect if $dbh;
}

# Writes the result array to the database
sub writeData
{
    my ($self, $startTime, $hopIp, $hopName, $detectionCode, $val1, $val2) = @_;

    # check whether the db connection is still alive, otherwise reconnect
    unless ($self->{'_dbh'} && $self->{'_dbh'}->ping)
    {
        my $dbh = DBI->connect($self->{'_dsn'}, $self->{'_user'}, $self->{'_password'});
        $self->{'_sth'} = $dbh->prepare( $self->{'_sql'} );
        $self->{'_dbh'} = $dbh;
    }

    $logger->debug("writing localization event at $startTime for $hopName to db");

    my $sth = $self->{'_sth'};
    my $dbh = $self->{'_dbh'};

    if (!$sth->execute($startTime, $hopIp, $hopName, $detectionCode, $val1, $val2))
    {
        $logger->error("$dbh->errstr");
    }
}

1;
