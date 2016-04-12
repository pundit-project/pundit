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

package PuNDIT::Agent::Detection::Reporter::MySQL;

use strict;
use DBI;
use Log::Log4perl qw(get_logger);

my $logger = get_logger(__PACKAGE__);

# returns a value to 1 decimal place
sub _oneDecimalPlace
{
    my ($val) = @_;
    
    return sprintf("%.1f", $val);
}

# returns a value to 2 decimal places
sub _twoDecimalPlace
{
    my ($val) = @_;
    
    return sprintf("%.2f", $val);
}

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

# Constructor
sub new
{
    my ($class, $cfgHash, $fedName) = @_;
        
    my ($host) = $cfgHash->{"pundit_agent"}{$fedName}{"reporting"}{"mysql"}{"host"};
    my ($port) = $cfgHash->{"pundit_agent"}{$fedName}{"reporting"}{"mysql"}{"port"};
    my ($database) = $cfgHash->{"pundit_agent"}{$fedName}{"reporting"}{"mysql"}{"database"};
    my ($user) = $cfgHash->{"pundit_agent"}{$fedName}{"reporting"}{"mysql"}{"user"};
    my ($password) = $cfgHash->{"pundit_agent"}{$fedName}{"reporting"}{"mysql"}{"password"};
    
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

sub writeStatus
{
    my ($self, $status) = @_;
    
    $logger->debug("Inserting status to MySQL for " . $status->{"srcHost"} . " to " . $status->{"dstHost"} . " at " . $status->{"startTime"});
    
    unless ($self->{'_dbh'} || $self->{'_dbh'}->ping) {
        $self->{'_dbh'} = DBI->connect($self->{'_dsn'}, $self->{'_user'}, $self->{'_password'});
    }
    
    # build the sql string
    my $sql = "INSERT INTO status (startTime, endTime, srcHost, dstHost, baselineDelay, detectionCode, queueingDelay, lossRatio, reorderMetric) VALUES ";
    for (my $i = scalar(@{$status->{'entries'}}); $i > 0; $i--)
    {
        $sql .= "(?, ?, ?, ?, ?, ?, ?, ?, ?)";
        if ($i > 1)
        {
            $sql .= ", ";
        }
    }
    
    my $sth = $self->{'_dbh'}->prepare($sql) or die "It didn't work. [$DBI::errstr]\n";
    
    # bind each parameter in its corresponding place
    for (my $i = 0; $i < scalar(@{$status->{'entries'}}); $i++)
    {
        my $currEntry = $status->{'entries'}->[$i];

#        print "Mysql: inserting " . int($currEntry->{'firstTimestamp'}) . " to " . int($currEntry->{'lastTimestamp'}) . "\n";
        
        my $paramCount = 9;
        
        $sth->bind_param(($paramCount * $i) + 1, _roundOff($currEntry->{'firstTimestamp'}));
        $sth->bind_param(($paramCount * $i) + 2, _roundOff($currEntry->{'lastTimestamp'}));
        $sth->bind_param(($paramCount * $i) + 3, $status->{"srcHost"});
        $sth->bind_param(($paramCount * $i) + 4, $status->{"dstHost"});
        $sth->bind_param(($paramCount * $i) + 5, _twoDecimalPlace($status->{'baselineDelay'}));
        $sth->bind_param(($paramCount * $i) + 6, $currEntry->{'detectionCode'});
        $sth->bind_param(($paramCount * $i) + 7, _twoDecimalPlace($currEntry->{'queueingDelay'}));
        $sth->bind_param(($paramCount * $i) + 8, _oneDecimalPlace($currEntry->{'lossPerc'}));
        $sth->bind_param(($paramCount * $i) + 9, 0.0);
    }

    $sth->execute or die "It didn't work. [$DBI::errstr]\n";
    $sth->finish;
}

1;