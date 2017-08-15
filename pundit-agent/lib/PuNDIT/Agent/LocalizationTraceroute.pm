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
use PuNDIT::Agent::Detection::TrReporter::RabbitMQ;
use Data::Dumper;
use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

# Constructor
sub new
{
    #my ($class, $cfgHash, $site, $start_time, $host_id) = @_;
    my ($class, $cfgHash, $fedName, $host_id) = @_;
    
    # Usage example (of this module) taken from InfileScheduler.pm
    # new PuNDIT::Agent::LocalizationTraceroute($self->{'_cfgHash'}, $fedName, time, $stats->{'srcHost'});
    # $fedName is $site

    my $reporter;
    $logger->info("Initializing RabbitMQ Detection Reporter for LocalizationTraceroute");
    my $tr_reporter = new PuNDIT::Agent::Detection::TrReporter::RabbitMQ($cfgHash, $fedName);
    
    my $self = {
        # reporter object (_dbh replacement)
        _tr_reporter => $tr_reporter, 

        #_start_time => $start_time,
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
    $logger->debug("\n!!!LocalziationTraceroute!!!\n" . Dumper($parse_result));
    

    #$self->storeTraceRabbitMQ($parse_result);
    $self->{'_tr_reporter'}->storeLocalizationTraceRabbitMQ($parse_result, $self->{'_host_id'});

}

1;
