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

# Handles the interface to MySQL

package Detection::Reporter::MySQL;

use strict;
use DBI;

# fake rounding function, so we don't need to include posix
sub _roundOff
{
    my ($val) = @_;
    
    # different rounding whether positive or negative
    if ($val >= 0)
    {
        return int($val + 0.5);
    }
    else
    {
        return int($val - 0.5);
    }
}


sub new
{
    my ($class, $cfgHash, $site) = @_;
        
    my ($host) = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"mysql"}{"host"};
    my ($port) = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"mysql"}{"port"};
    my ($database) = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"mysql"}{"database"};
    my ($user) = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"mysql"}{"user"};
    my ($password) = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"mysql"}{"password"};
    
    # make the db connection here?
    my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $password) or die "Critical error: cannot connect to DB";
    
    my $self = {
        _dbh => $dbh,
    };
    
    bless $self, $class;
    return $self;
}

# Legacy format. Will be removed soon
sub writeEvent
{
    my ($self, $event) = @_;
    
    my $sql = "INSERT INTO events (sendTS, recvTS, srchost, dsthost, diagnosis, plot, filename) VALUES (?, ?, ?, ?, ?, ?, ?)";
    my $sth = $self->{_dbh}->prepare($sql) or die "It didn't work. [$DBI::errstr]\n";
=pod
    $sth->bind_param(1, $startTS);
    $sth->bind_param(2, $endTS);
    $sth->bind_param(3, $src);
    $sth->bind_param(4, $dst);
    $sth->bind_param(5, $diag);
=cut
    $sth->execute or die "It didn't work. [$DBI::errstr]\n";
    $sth->finish;
}

sub writeStatus
{
    my ($self, $status) = @_;
    
    # build the sql string
    my $sql = "INSERT INTO status (startTime, endTime, srchost, dsthost, baselineDelay, detectionCode, queueingDelay, lossRatio, reorderMetric) VALUES ";
    for (my $i = scalar(@{$status->{'entries'}}); $i > 0; $i--)
    {
        $sql .= "(?, ?, ?, ?, ?, ?, ?, ?, ?)";
        if ($i > 1)
        {
            $sql .= ", ";
        }
    }
    
    my $sth = $self->{_dbh}->prepare($sql) or die "It didn't work. [$DBI::errstr]\n";
    
    # bind each parameter in its corresponding place
    for (my $i = 0; $i < scalar(@{$status->{'entries'}}); $i++)
    {
        my $currEntry = $status->{'entries'}->[$i];
        
        # placeholder
        my $detectionCode = $currEntry->{'delayProblem'} * 2 + $currEntry->{'lossProblem'} * 4;
#        print "Mysql: inserting " . int($currEntry->{'firstTimestamp'}) . " to " . int($currEntry->{'lastTimestamp'}) . "\n";
        
        $sth->bind_param((9 * $i) + 1, _roundOff($currEntry->{'firstTimestamp'}));
        $sth->bind_param((9 * $i) + 2, _roundOff($currEntry->{'lastTimestamp'}));
        $sth->bind_param((9 * $i) + 3, $status->{"srchost"});
        $sth->bind_param((9 * $i) + 4, $status->{"dsthost"});
        $sth->bind_param((9 * $i) + 5, $status->{'baselineDelay'});
        $sth->bind_param((9 * $i) + 6, $detectionCode);
        $sth->bind_param((9 * $i) + 7, $currEntry->{'queueingDelay'});
        $sth->bind_param((9 * $i) + 8, $currEntry->{'lossPerc'});
        $sth->bind_param((9 * $i) + 9, 0.0);
    }

    $sth->execute or die "It didn't work. [$DBI::errstr]\n";
    $sth->finish;
}

1;