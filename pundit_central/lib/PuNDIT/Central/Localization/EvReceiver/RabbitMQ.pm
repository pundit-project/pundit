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
package PuNDIT::Central::Localization::EvReceiver::RabbitMQ;

use strict;
use Data::Dumper;
use Log::Log4perl qw(get_logger);
use PuNDIT::Central::Messaging::Topics;

=pod

=head1 PuNDIT::Central::Localization::EvReceiver::RabbitMQ

Interface to get events from the message queue

=cut

my $logger = get_logger(__PACKAGE__);

# Constructor
sub new
{
    my ($class, $cfgHash, $fedName) = @_;

    # Load RabbitMQ parameters
    my ($user)         = $cfgHash->{"pundit_central"}{$fedName}{"ev_receiver"}{"rabbitmq"}{"user"};
    my ($password)     = $cfgHash->{"pundit_central"}{$fedName}{"ev_receiver"}{"rabbitmq"}{"password"};
    my ($channel)      = $cfgHash->{"pundit_central"}{$fedName}{"ev_receiver"}{"rabbitmq"}{"channel"};
    my ($exchange)     = $cfgHash->{"pundit_central"}{$fedName}{"ev_receiver"}{"rabbitmq"}{"exchange"};
    my ($queue)        = $cfgHash->{"pundit_central"}{$fedName}{"ev_receiver"}{"rabbitmq"}{"queue"};
    my ($binding_keys) = $cfgHash->{"pundit_central"}{$fedName}{"ev_receiver"}{"rabbitmq"}{"binding_keys"};


    # Set up the RabbitMQ topic exchange
    my $mq = set_bindings( $user, $password, $channel, $exchange, $queue, $binding_keys );

    my $self = {
        '_user' => $user,
        '_password' => $password,
        '_channel' => $channel,
        '_exchange' => $exchange,
        '_queue' => $queue,
        '_binding_keys' => $binding_keys,
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


sub getLatestEvents
{
    my ($self, $lastTS) = @_;

    $logger->debug("Consume...");

    my $event = $self->getEventsMQ($lastTS, undef);
    my @arr = split (/\|/, $event);
    my %h = (
      "srcHost"       => $arr[0],
      "dstHost"       => $arr[1],
      "baselineDelay" => $arr[2],
      "measures"      => $arr[3]         ###
     );
    my $href = \%h;
    return $href;
}

sub getEventsMQ
{
    my ($self, $startTS, $endTS) = @_;

     my $payload = $self->{'_mq'}->recv();
     #my $event = Dumper($payload->{body});
     my $event = $payload->{body};            ###
     $logger->debug("$event");
     return $event;
}

1;
