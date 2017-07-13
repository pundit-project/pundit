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

# localization_traceroute.pm
#
# Support library for the localization_traceroute_daemon
# This is also designed to be called from the detection logic, so traceroutes can be done on demand

package PuNDIT::Agent::LocalizationTraceroute;

use strict;
# use DBI qw(:sql_types); TODO to be removed
use PuNDIT::Agent::LocalizationTraceroute::ParisTrParser;
use PuNDIT::Agent::Detection::Reporter::RabbitMQ;
use Data::Dumper;
use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

# Constructor
sub new
{
    my ($class, $cfgHash, $site, $start_time, $host_id) = @_;
    
    # Usage example (of this module) taken from InfileScheduler.pm
    # new PuNDIT::Agent::LocalizationTraceroute($self->{'_cfgHash'}, $fedName, time, $stats->{'srcHost'});
    # $fedName is $site

    my $reporter;
    $logger->info("Initializing RabbitMQ Detection Reporter for LocalizationTraceroute");
    $tr_reporter = new PuNDIT::Agent::Detection::TrReporter::RabbitMQ($cfgHash, $fedName);

    # TODO To be removed
    # DB Params
    # my ($host) = $cfgHash->{"pundit-agent"}{$site}{"reporting"}{"mysql"}{"host"};
    # my ($port) = $cfgHash->{"pundit-agent"}{$site}{"reporting"}{"mysql"}{"port"};
    # my ($database) = $cfgHash->{"pundit-agent"}{$site}{"reporting"}{"mysql"}{"database"};
    # my ($user) = $cfgHash->{"pundit-agent"}{$site}{"reporting"}{"mysql"}{"user"};
    # my ($password) = $cfgHash->{"pundit-agent"}{$site}{"reporting"}{"mysql"}{"password"};
    
    # make the db connection here, for the lifetime of this object
    # my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $password) or die "Critical error: cannot connect to DB";
    
    my $self = {
        # _dbh => $dbh,
        # reporter object (_dbh replacement)
        _tr_reporter => $tr_reporter, 

        _start_time => $start_time,
        _host_id => $host_id,
    };
    
    bless $self, $class;
    return $self;
}

# Destructor
sub DESTROY
{
    # my ($self) = @_;
    
    # Cleanup
    # $self->{'_dbh'}->disconnect;
}

sub runTrace
{
    my ($self, $target) = @_;
    
    my $tr_result = `paris-traceroute $target`;
    my $parse_result = PuNDIT::Agent::LocalizationTraceroute::ParisTrParser::parse($tr_result);
    $logger->info("Dumping tr_result now");
    $logger->info(Dumper($tr_result));
    

    # TODO to be implemented
    # $self->storeTraceRabbitMQ($parse_result);

    # TODO to be removed
    # $self->storeTraceMySql($parse_result);
}

sub relayTrace
{
    my ($self, $target) = @_;
    
    my $tr_result = `paris-traceroute $target`;
    my $parse_result = PuNDIT::Agent::LocalizationTraceroute::ParisTrParser::parse($tr_result);
    $logger->info("Dumping tr_result now");
    $logger->info(Dumper($tr_result));
    

    # TODO to be implemented
    # $self->storeTraceRabbitMQ($parse_result);

    # TODO to be removed
    # $self->storeTraceMySql($parse_result);
}

# TODO to be implemented
# sub storeTraceRabbitMQ
# {
#     my ($self, $trace_hash) = @_;
    
#     my $sql = "INSERT INTO traceroutes ( ts, src, dst, hop_no, hop_ip, hop_name ) VALUES ";
#     for (my $i = scalar(@{$trace_hash->{'path'}}); $i > 0; $i--)
#     {
#         $sql .= "(?, ?, ?, ?, ?, ?)";
#         if ($i > 1)
#         {
#             $sql .= ", ";
#         }
#     }
    
#     my $sth = $self->{'_dbh'}->prepare($sql);
    
#     my $param_cnt = 6; # variable so we don't hardcode the number of params
#     for (my $i = 0; $i < scalar(@{$trace_hash->{'path'}}); $i++)
#     {
#         my $hop = $trace_hash->{'path'}[$i];
        
#         $sth->bind_param(($i*$param_cnt) + 1, $self->{'_start_time'}, SQL_INTEGER);
#         $sth->bind_param(($i*$param_cnt) + 2, $self->{'_host_id'}, SQL_VARCHAR);
#         $sth->bind_param(($i*$param_cnt) + 3, $trace_hash->{'dest_name'}, SQL_VARCHAR);
#         $sth->bind_param(($i*$param_cnt) + 4, $hop->{'hop_count'}, SQL_INTEGER);
#         $sth->bind_param(($i*$param_cnt) + 5, $hop->{'hop_ip'}, SQL_VARCHAR);
#         $sth->bind_param(($i*$param_cnt) + 6, $hop->{'hop_name'}, SQL_VARCHAR);
#     }
    
#     $sth->execute;
#     $sth->finish;
# }

# sub storeTraceMySql
# {
#     my ($self, $trace_hash) = @_;
    
#     my $sql = "INSERT INTO traceroutes ( ts, src, dst, hop_no, hop_ip, hop_name ) VALUES ";
#     for (my $i = scalar(@{$trace_hash->{'path'}}); $i > 0; $i--)
#     {
#         $sql .= "(?, ?, ?, ?, ?, ?)";
#         if ($i > 1)
#         {
#             $sql .= ", ";
#         }
#     }
    
#     my $sth = $self->{'_dbh'}->prepare($sql);
    
#     my $param_cnt = 6; # variable so we don't hardcode the number of params
#     for (my $i = 0; $i < scalar(@{$trace_hash->{'path'}}); $i++)
#     {
#         my $hop = $trace_hash->{'path'}[$i];
        
#         $sth->bind_param(($i*$param_cnt) + 1, $self->{'_start_time'}, SQL_INTEGER);
#         $sth->bind_param(($i*$param_cnt) + 2, $self->{'_host_id'}, SQL_VARCHAR);
#         $sth->bind_param(($i*$param_cnt) + 3, $trace_hash->{'dest_name'}, SQL_VARCHAR);
#         $sth->bind_param(($i*$param_cnt) + 4, $hop->{'hop_count'}, SQL_INTEGER);
#         $sth->bind_param(($i*$param_cnt) + 5, $hop->{'hop_ip'}, SQL_VARCHAR);
#         $sth->bind_param(($i*$param_cnt) + 6, $hop->{'hop_name'}, SQL_VARCHAR);
#     }
    
#     $sth->execute;
#     $sth->finish;
# }

1;
