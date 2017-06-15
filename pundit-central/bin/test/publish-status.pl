#!/usr/bin/perl

use strict;
use Config::General;

use FindBin qw( $RealBin );

use lib "$RealBin/../../lib";

use PuNDIT::Central::Messaging::Topics;

use Data::Dumper;

=pod
=head1 DESCRIPTION
Publishes a test message on the traceroute queue
=cut

my $configFile = $RealBin . "/../../etc/pundit-central.conf";
my %cfgHash = Config::General::ParseConfig($configFile);
my $binding_keys = $cfgHash{pundit_central}{federation1}{ev_receiver}{rabbitmq}{binding_keys};
my $password = $cfgHash{pundit_central}{federation1}{ev_receiver}{rabbitmq}{password};
my $user = $cfgHash{pundit_central}{federation1}{ev_receiver}{rabbitmq}{user};
my $queue = $cfgHash{pundit_central}{federation1}{ev_receiver}{rabbitmq}{queue};
my $channel = $cfgHash{pundit_central}{federation1}{ev_receiver}{rabbitmq}{channel};
my $queue_host = $cfgHash{pundit_central}{federation1}{ev_receiver}{rabbitmq}{queue_host};
my $exchange = $cfgHash{pundit_central}{federation1}{ev_receiver}{rabbitmq}{exchange};

my $message = "psum05.aglt2.org|perfsonar.unl.edu|8.66127014160156|1497536865,1497536870,0,42.87,0.0,0.0;1497536870,1497536875,0,57.71,0.0,0.0;1497536875,1497536880,0,43.95,0.0,0.0;1497536880,1497536885,0,21.94,0.0,0.0;1497536885,1497536890,0,41.21,0.0,0.0;1497536890,1497536895,0,65.05,0.0,0.0;1497536895,1497536900,0,30.88,0.0,0.0;1497536900,1497536905,0,111.27,0.0,0.0;1497536905,1497536910,0,57.15,0.0,0.0;1497536910,1497536915,0,30.63,0.0,0.0;1497536915,1497536920,0,8.36,0.0,0.0;1497536920,1497536925,0,14.56,0.0,0.0;";

# Open connection and retrieves a handle to the queue
my $mq = set_topic( $queue_host, $user, $password, $channel, $exchange );

# Publishes the message
$mq->publish($channel, $binding_keys, $message, { exchange => $exchange } );

# Close connection
$mq->disconnect();
