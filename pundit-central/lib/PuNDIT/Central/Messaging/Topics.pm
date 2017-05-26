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

package PuNDIT::Central::Messaging::Topics;

# Module to set up a message queuing system using Net::RabbitMQ.
# The messaging scheme used here is based on a topic exchange.

use strict;

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

use Net::AMQP::RabbitMQ;

use vars qw(@ISA @EXPORT $VERSION);
use Exporter;
$VERSION = "1.0";
@ISA = qw/Exporter/;

@EXPORT = qw (
               &set_topic
               &set_bindings
             );

# This function is called by producers to establish a connection, channel, and exchange
sub set_topic {
    my ( $consumer, $user, $password, $channel, $exchange ) = @_;

    $logger->debug("input params: $consumer, $user, $password, $channel, $exchange"); ### Remove

    # establish connection and channel
    my $msgq = Net::AMQP::RabbitMQ->new();
    $msgq->connect($consumer, { user => $user, password => $password });
    $msgq->channel_open($channel);

    # declare exchange
    $msgq->exchange_declare($channel,$exchange,{exchange_type => 'topic'});

    return $msgq;
}


# This is called by consumers to bind a channel to a queue via an exchange
# using the given binding key(s) for message pattern matching.
sub set_bindings {
    my ( $user, $password, $channel, $exchange, $queue, $binding_keys ) = @_;

    # establish connection
    my $msgq = Net::AMQP::RabbitMQ->new();
    $msgq->connect("localhost", { user => $user, password => $password });

    # declare channel
    $msgq->channel_open($channel);
    $msgq->queue_declare($channel, $queue);
    $msgq->consume($channel, $queue);

    # declare exchange
    $msgq->exchange_declare($channel,$exchange,{exchange_type => 'topic', auto_delete => 0});

    # bindings
    my @binding_keys = split(',', $binding_keys);
    foreach my $binding_key (@binding_keys) {
        $msgq->queue_bind($channel,$queue,$exchange,$binding_key);
    }

    return $msgq;
}

1;
