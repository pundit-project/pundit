#!/usr/bin/perl

use strict;
use Config::General;

use FindBin qw( $RealBin );

use lib "$RealBin/../../lib";

use PuNDIT::Central::Messaging::Topics;

use Data::Dumper;

=pod
=head1 DESCRIPTION
Listens to the traceroute queue and dumps the message
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

# Open connection and retrieves a handle to the queue
my $mq = set_bindings( $user, $password, $channel, $exchange, $queue, $binding_keys );

print Dumper($user . " / " . $exchange . " / " . $channel . " / " . $binding_keys);

# Consume loop
while ( my $payload = $mq->recv() ) {
    last if ( !defined $payload );
    my $msg=undef;
    if ( $exchange =~ m/^json_/ ) {
        $msg = decode_json($payload->{body});
        print Dumper($msg);
    } else {
        #print Dumper($payload->{body});
        print Dumper($payload);
    }
}

# close connection
$mq->disconnect();

