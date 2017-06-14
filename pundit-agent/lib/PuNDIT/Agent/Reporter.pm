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


package PuNDIT::Agent::Reporter;

use strict;
use Log::Log4perl qw(get_logger);
use Net::AMQP::RabbitMQ;

my $logger = get_logger(__PACKAGE__);

sub new {

	my ($class, $cfgHash, $fedName) = @_;

    # Incoming data flow through RabbitMQ from pscheduler
    my $mqOut = Net::AMQP::RabbitMQ->new();

	my $hostname = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"consumer"};
	my $r_user = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"user"};
	my $r_pass = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"password"};
	my $channel = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"channel"};
    my $routing_key = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"routing_key"};
    my $exchange = $cfgHash->{"pundit-agent"}{$fedName}{"reporting"}{"rabbitmq"}{"exchange"};
	
	$mqOut->connect($hostname, { user => $r_user, password => $r_pass});
    $mqOut->channel_open($channel);
    $mqOut->exchange_declare($channel, $exchange);



    # Declare queue, letting the server auto-generate one and collect the name
    my $queuename = $mqOut->queue_declare($channel, "");

	# Bind the new queue to the exchange using the routing key
    $mqOut->queue_bind($channel, $queuename, $exchange, $routing_key);
	$logger->info($hostname);
	$logger->info($channel);
	$logger->info($queuename);
	$logger->info($exchange);
	$logger->info($routing_key);

	my $self = {
        '_fedName' => $fedName,
        '_mqOut' => $mqOut,

		'_routing_key' => $routing_key,
		'_channel' => $channel,
		'_exchange' => $exchange,
	};

    bless $self, $class;
    return $self;

}

sub report {

	my	($self) = @_;
	$logger->info("report module running");
	my $body = "Reporter module is working";
	$self->{'_mqOut'}->publish($self->{'_channel'}, $self->{'_routing_key'}, $body, {exchange => $self->{'_exchange'}});

}
