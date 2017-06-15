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

package PuNDIT::Central::Localization::TrStore::MySQL;

use strict;
use DBI qw(:sql_types);
use Log::Log4perl qw(get_logger);

use PuNDIT::Utils::TrHop;

=pod

=head1 PuNDIT::Central::Localization::TrStore::MySQL

This class handles the writing to a MySQL backend once a traceroute is received.

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
    
    # Cleanup
    $self->{'_dbh'}->disconnect;
}

# writes a received traceroute hash to the MySQL backend
# return undef for failures or 1 for success
sub writeTrHash
{
    my ($self, $trHash) = @_;
    
    # check whether the db connection is still alive, otherwise reconnect
    unless ($self->{'_dbh'} && $self->{'_dbh'}->ping) {
        $self->{'_dbh'} = DBI->connect($self->{'_dsn'}, $self->{'_user'}, $self->{'_password'});
    }
    
    my $sql = "INSERT INTO tracerouteStaging ( ts, src, dst, hop_no, hop_ip, hop_name ) VALUES (?, ?, ?, ?, ?, ?);";
    
    my $sth = $self->{'_dbh'}->prepare($sql);
    if (!$sth)
    {
        $logger->error("Failed to prepare SQL for writing to db");
        return undef;
    }
    
    while (my ($srcHost, $dstHash) = each(%$trHash))
    {
        while (my ($dstHost, $trList) = each(%$dstHash))
        {
            foreach my $inTr (@{$trList})
            { 
                for (my $i = 0; $i < scalar(@{$inTr->{'path'}}); $i++) # i is the hop count - 1
                {
                    my $trHops = $inTr->{'path'}[$i]->getRawList();
                    
                    foreach my $hop (@{$trHops})
                    {
                        $sth->bind_param(1, $inTr->{'ts'}, SQL_INTEGER);
                        $sth->bind_param(2, $inTr->{'src'}, SQL_VARCHAR);
                        $sth->bind_param(3, $inTr->{'dst'}, SQL_VARCHAR);
                        $sth->bind_param(4, $i + 1, SQL_INTEGER);
                        $sth->bind_param(5, $hop->{'hopIp'}, SQL_VARCHAR);
                        $sth->bind_param(6, $hop->{'hopName'}, SQL_VARCHAR);
                        $sth->execute;
                    }
                }
            }
        }
    }
    return 1; # success
}

1;
