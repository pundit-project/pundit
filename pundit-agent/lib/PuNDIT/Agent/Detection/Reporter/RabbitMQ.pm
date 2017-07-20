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
use Data::Dumper;   ###
use Log::Log4perl qw(get_logger);
use PuNDIT::Agent::Messaging::Topics;

my $logger = get_logger(__PACKAGE__);
$logger->info("Reporter::RabbitMQ called");

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

    # Load RabbitMQ parameters
    my ($consumer)    = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"consumer"};
    my ($user)        = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"user"};
    my ($password)    = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"password"};
    my ($channel)     = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"channel"};
    my ($exchange)    = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"exchange"};
    my ($routing_key) = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"routing_key"};
    $logger->debug($consumer . " / " . $user . " / " . $channel . " / " . $exchange . " / " . $routing_key);

    $logger->debug("Constructor Reporter::RabbitMQ, channel=$channel");
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

    # publish results
    my $set = _compress($status->{'entries'});
    my $body = "$status->{'srcHost'}|$status->{'dstHost'}|$status->{'baselineDelay'}|$set";
    
    $logger->info("To publish: " . $body);
    $self->{'_mq'}->publish($self->{'_channel'},$self->{'_routing_key'},
                            $body,
                            { exchange => $self->{'_exchange'} });
}

# This function compresses the array of hashes for remote delivery
sub _compress {
    my $aref = shift;

    my $set = undef;
    foreach my $h (@$aref) {
        $set .= _roundOff($h->{'firstTimestamp'}) . "," . _roundOff($h->{'lastTimestamp'}) . ",";
        $set .= "$h->{'detectionCode'}," . _twoDecimalPlace($h->{'queueingDelay'}) . ",";
        $set .= _oneDecimalPlace($h->{'lossPerc'}) . ",0.0;";
    }
    return $set;
}

1;
