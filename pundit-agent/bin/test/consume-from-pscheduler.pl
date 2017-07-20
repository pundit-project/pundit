#!/usr/bin/perl

use strict;

use FindBin qw( $RealBin );
use lib "$RealBin/../../lib";
use Config::General;
use PuNDIT::Agent::Messaging::Topics;

use JSON qw (decode_json); 
use Data::Dumper;

=pod
=head1 DESCRIPTION
Listens to the queue and dumps the message
=cut

=head2 parseConfig($cfgPath);
Simple configuration parser
=cut
sub parseConfig
{
    my ($configFile) = @_;
    my %cfgHash = Config::General::ParseConfig($configFile);


    if ( ! -e "$configFile" || !%cfgHash) {
        return (-1, undef);
    }
    
    return (0, \%cfgHash);    
}
1;


my $CONFIG_FILE = "/opt/pundit-agent/etc/pundit-agent.conf";
my ($status, $cfgHash) = parseConfig($CONFIG_FILE);
if ($status != 0) {
    print "Problem parsing configuration file: $CONFIG_FILE. Quitting.\n";
    exit(-1);
}


my ($consumer)    = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"consumer"};
my ($user)        = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"user"};
my ($password)    = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"password"};
my ($exchange)    = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"exchange"};
my ($routing_key) = $cfgHash->{"pundit-agent"}{"raw_receiver"}{"rabbitmq"}{"routing_key"};

my $channel = 1;
my $queue = "";

my $mq = set_bindings( $user, $password, $channel, $exchange, $queue, $routing_key );



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


$mq->disconnect();

