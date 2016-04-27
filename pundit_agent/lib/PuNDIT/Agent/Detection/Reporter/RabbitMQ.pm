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

# Handles the interface to RabbitMQ
package PuNDIT::Agent::Detection::Reporter::RabbitMQ;

use strict;
use Log::Log4perl qw(get_logger);
use PuNDIT::Agent::Messaging::Topics;

my $logger = get_logger(__PACKAGE__);

# Constructor
sub new
{
    my ($class, $cfgHash, $site) = @_;

    # Load RabbitMQ parameters
    my ($consumer)    = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"rabbitmq"}{"consumer"};
    my ($user)        = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"rabbitmq"}{"user"};
    my ($password)    = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"rabbitmq"}{"password"};
    my ($channel)     = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"rabbitmq"}{"channel"};
    my ($exchange)    = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"rabbitmq"}{"exchange"};
    my ($routing_key) = $cfgHash->{"pundit_agent"}{$site}{"reporting"}{"rabbitmq"}{"routing_key"};

    print "In Reporter::RabbitMQ, channel=$channel\n";

    # Set up the RabbitMQ topic exchange
    my $mq = set_topic( $consumer, $user, $password, $channel, $exchange );

    my $self = {
        '_consumer' => $consumer,
        '_user' => $user,
        '_password' => $password,
        '_channel' => $channel,
        '_exchange' => $exchange,
        '_routing_key' => $routing_key,
        '_mq' => $mq,
    };

    bless $self, $class;
    return $self;
}


# Destructor
sub DESTROY
{
    my ($self) = @_;
    
    $self->{'_mq'}->disconnect;
}


# Publishers

sub writeStatus
{
    my ($self, $status) = @_;

    $logger->debug("To publish: $status");

    # publish results
    $self->{'_mq'}->publish($self->{'_channel'},$self->{'_routing_key'},$status, { exchange => $self->{'_exchange'} });
}

1;
