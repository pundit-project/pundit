#!perl -w
#
# Copyright 2017 University of Michigan
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

# relay_traceroute.pm
#
# Support library for the localization_traceroute_daemon
# This is also designed to be called from the detection logic, so traceroutes can be relayed

package PuNDIT::Agent::RelayTraceroute;

use strict;
# use DBI qw(:sql_types); TODO to be removed
use PuNDIT::Agent::RelayTraceroute::ParisTrParser;
use PuNDIT::Agent::Detection::TrReporter::RabbitMQ;
use Data::Dumper;
use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

# Constructor
sub new
{
    my ($class, $cfgHash, $fedName) = @_;
    
    # Usage example (of this module) taken from Detection.pm
    # new PuNDIT::Agent::RelayTraceroute($self->{'_cfgHash'}, $fedName);
    # $fedName is $site

    $logger->debug("Initializing RabbitMQ Detection Reporter for RelayTraceroute");
    my $tr_reporter = new PuNDIT::Agent::Detection::TrReporter::RabbitMQ($cfgHash, $fedName);
    
    my $self = {
        _tr_reporter => $tr_reporter, 

        _host_id => $cfgHash->{"pundit-agent"}{"src_host"},
    };
    
    bless $self, $class;
    return $self;
}

# Destructor
sub DESTROY
{
    # my ($self) = @_;
    
    # Cleanup
}

sub relayTrace
{
    my ($self, $raw_json, $previous_trace) = @_;
    
    my $parse_result = PuNDIT::Agent::RelayTraceroute::ParisTrParser::parse($raw_json);
    
    #Uncomment these lines to check the parsed result.
    #$logger->info("Dumping $parse_result now");
    #$logger->info(Dumper($parse_result));
    if ($previous_trace->{'dest_name'} ne $parse_result->{'dest_name'} || $previous_trace->{'ts'} ne $parse_result->{'ts'} ) {
        $self->{'_tr_reporter'}->storeTraceRabbitMQ($parse_result, $self->{'_host_id'});
    } else {
        $logger->info("Duplicate trace skipped: $parse_result->{'ts'}|$self->{'_host_id'}|$parse_result->{'dest_name'} ")
    }

    return $parse_result;
}


1;
