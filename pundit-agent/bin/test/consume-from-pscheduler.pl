#!/usr/bin/perl

use strict;

use FindBin qw( $RealBin );
use lib "$RealBin/../../lib";
use PuNDIT::Agent::Messaging::Topics;

use JSON qw (decode_json); 
use URI::Split qw/ uri_split /;
use Data::Dumper;

=pod
=head1 DESCRIPTION
Listens to the queue and dumps the message
=cut

my $archiverFile='/etc/pscheduler/default-archives/pscheduler-archiver-pundit';
my $json;
{
  local $/; #Enable 'slurp' mode
  open my $fh, "<", $archiverFile;
  $json = <$fh>;
  close $fh;
}
my $decoded_json = decode_json($json);
my @_url = uri_split($decoded_json->{'data'}->{'_url'});
my @url = split(/:|@/, $_url[1]);

my $user = $url[0];
my $password = $url[1];
my $host = $url[2];
my $port = $url[3];
my $exchange = $decoded_json->{'data'}->{'exchange'};
my $routing_key = $decoded_json->{'data'}->{'routing-key'};
my $channel = 1;
my $queue = "";
# Open connection and retrieves a handle to the queue
my $mq = set_bindings( $user, $password, $channel, $exchange, $queue, $routing_key );


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

