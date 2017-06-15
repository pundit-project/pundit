#!perl -w
#
# Copyright 2016 Georgia Institute of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	  http://www.apache.org/licenses/LICENSE-2.0
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
$logger->debug("Reporter called");

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

# Destructor
sub DESTROY
{
	my ($self) = @_;
	$self->{'_mqOut'}->disconnect;
}


# Publishers
sub writeStatus
{
	my ($self, $status) = @_;

	$logger->info("To publish: $status");

	# publish results
	my $set = _compress($status->{'entries'});
	my $body = "$status->{'srcHost'}|$status->{'dstHost'}|$status->{'baselineDelay'}|$set";

	#my $body = "Reporter module is working";	
	$self->{'_mqOut'}->publish($self->{'_channel'}, $self->{'_routing_key'}, $body, {exchange => $self->{'_exchange'}});
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

sub report {

	my	($self) = @_;
	$logger->info("report() module");
	my $body = "report()";

	#my $body = "Reporter module is working";	
	$self->{'_mqOut'}->publish($self->{'_channel'}, $self->{'_routing_key'}, $body, {exchange => $self->{'_exchange'}});


}

1
