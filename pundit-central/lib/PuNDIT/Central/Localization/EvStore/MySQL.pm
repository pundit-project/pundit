#!perl -w
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

package PuNDIT::Central::Localization::EvStore::MySQL;

use strict;
use DBI qw(:sql_types);
use Log::Log4perl qw(get_logger);

=pod

=head1 PuNDIT::Central::Localization::EvStore::MySQL

This class handles the writing to the MySQL backend once an event is received.

=cut


my $logger = get_logger(__PACKAGE__);


# Constructor
sub new
{
    my ($class, $cfgHash, $fedName) = @_;
            
    # DB Params
    # uses the same params from "reporting". Change if necessary
    my ($host) = $cfgHash->{"pundit_central"}{$fedName}{"reporting"}{"mysql"}{"host"};
    my ($port) = $cfgHash->{"pundit_central"}{$fedName}{"reporting"}{"mysql"}{"port"};
    my ($database) = $cfgHash->{"pundit_central"}{$fedName}{"reporting"}{"mysql"}{"database"};
    my ($user) = $cfgHash->{"pundit_central"}{$fedName}{"reporting"}{"mysql"}{"user"};
    my ($password) = $cfgHash->{"pundit_central"}{$fedName}{"reporting"}{"mysql"}{"password"};
    
    # make the db connection here, refreshing it if it dies later
    my $dsn = "DBI:mysql:$database:$host:$port";
    my $dbh = DBI->connect($dsn, $user, $password); 
    if (!$dbh)
    {
        $logger->error("Critical error: cannot connect to DB");
        return undef;
    }
    
    my $self = {
        '_dsn' => $dsn,
        '_user' => $user,
        '_password' => $password,
        '_dbh' => $dbh,
    };
    
    bless $self, $class;
    return $self;
}

# Destructor
sub DESTROY
{
    my ($self) = @_;
    
    $self->{'_dbh'}->disconnect;
}

# inserts an event into the mysql database
sub writeEvHash
{
    my ($self, $evHash) = @_;
    
    # skip empty hashes
    return 1 if (!%{$evHash});
    
    # check whether the db connection is still alive, otherwise reconnect
    unless ($self->{'_dbh'} && $self->{'_dbh'}->ping) 
    {
        $self->{'_dbh'} = DBI->connect($self->{'_dsn'}, $self->{'_user'}, $self->{'_password'});
    }
    
    my $sql = "INSERT INTO statusStaging (startTime, endTime, srcHost, dstHost, baselineDelay, detectionCode, queueingDelay, lossRatio, reorderMetric) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);";
    
    my $sth = $self->{'_dbh'}->prepare($sql);
    if (!$sth)
    {
        $logger->error("SQL Prepare failed. [$DBI::errstr]");
        return undef;
    }
    
    while (my ($srcHost, $dstHash) = each %$evHash)
    {
        while (my ($dstHost, $events) = each %$dstHash)
        {
            foreach my $event (@{$events})
            {
#                $logger->debug("Inserting status to MySQL for " . $srcHost . " to " . $dstHost . " at " . $event->{"startTime"});
    
                $sth->bind_param(1, $event->{'startTime'});
                $sth->bind_param(2, $event->{'endTime'});
                $sth->bind_param(3, $srcHost, SQL_VARCHAR);
                $sth->bind_param(4, $dstHost, SQL_VARCHAR);
                $sth->bind_param(5, $event->{'baselineDelay'});
                $sth->bind_param(6, $event->{'detectionCode'});
                $sth->bind_param(7, $event->{'queueingDelay'});
                $sth->bind_param(8, $event->{'lossRatio'});
                $sth->bind_param(9, $event->{'reorderMetric'});
                
                my $res = $sth->execute;
                if (!$res)
                {
                    $logger->error("SQL execute failed. [$DBI::errstr]");
                    return undef;
                }
            }
        }
    }

    return 1; # return success
}

1;
