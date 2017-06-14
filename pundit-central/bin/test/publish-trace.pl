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
my $binding_keys = $cfgHash{pundit_central}{federation1}{tr_receiver}{rabbitmq}{binding_keys};
my $password = $cfgHash{pundit_central}{federation1}{tr_receiver}{rabbitmq}{password};
my $user = $cfgHash{pundit_central}{federation1}{tr_receiver}{rabbitmq}{user};
my $queue = $cfgHash{pundit_central}{federation1}{tr_receiver}{rabbitmq}{queue};
my $channel = $cfgHash{pundit_central}{federation1}{tr_receiver}{rabbitmq}{channel};
my $queue_host = $cfgHash{pundit_central}{federation1}{tr_receiver}{rabbitmq}{queue_host};
my $exchange = $cfgHash{pundit_central}{federation1}{tr_receiver}{rabbitmq}{exchange};

my $message = "1485185401|ps3.ochep.ou.edu|psmsu05.aglt2.org|1,129.15.40.1,rtr-40-1.rccc.ou.edu;2,198.124.80.153,esnet-lhc1-uok.es.net;3,198.124.80.57,esnet-lhc1-b-aglt2.es.net;4,198.124.80.58,aglt2-lhc1-b-esnet.es.net;5,192.41.236.35,psmsu05.aglt2.org";

# Open connection and retrieves a handle to the queue
my $mq = set_topic( $queue_host, $user, $password, $channel, $exchange );

# Publishes the message
$mq->publish($channel, $binding_keys, $message, { exchange => $exchange } );

# Close connection
$mq->disconnect();
