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
package PuNDIT::Central::Localization::TrReceiver::RabbitMQ;

use strict;
use Data::Dumper;
use Log::Log4perl qw(get_logger);
use PuNDIT::Central::Messaging::Topics;
use PuNDIT::Utils::TrHop;

my $logger = get_logger(__PACKAGE__);

# Constructor
sub new
{
    my ($class, $cfgHash, $site) = @_;

    # Load RabbitMQ parameters
    my ($user)         = $cfgHash->{"pundit_central"}{$site}{"tr_receiver"}{"rabbitmq"}{"user"};
    my ($password)     = $cfgHash->{"pundit_central"}{$site}{"tr_receiver"}{"rabbitmq"}{"password"};
    my ($channel)      = $cfgHash->{"pundit_central"}{$site}{"tr_receiver"}{"rabbitmq"}{"channel"};
    my ($exchange)     = $cfgHash->{"pundit_central"}{$site}{"tr_receiver"}{"rabbitmq"}{"exchange"};
    my ($queue)        = $cfgHash->{"pundit_central"}{$site}{"tr_receiver"}{"rabbitmq"}{"queue"};
    my ($binding_keys) = $cfgHash->{"pundit_central"}{$site}{"tr_receiver"}{"rabbitmq"}{"binding_keys"};


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


# Consumer
sub getLatestTraces
{
    my ($self, $refTime) = @_;

    $logger->debug("Quering MQ for traces later than", $refTime);

    # Init an empty hash
    my %trHash = ();
    
    # variables for error checking
    my $lastTs;
    my $lastHopNo;
    
    # make a nonblocking call to rabbitmq
    while (my $payload = $self->{'_mq'}->recv(500))
    {
        last unless defined($payload); # no more messages to retrieve
        
        # We assume each message will contain only 1 traceroute from a specific src to dst
        # This is because the PuNDIT archiver is called on a per traeroute run basis
        # TODO: Use a binary format instead
        my ($ts, $srcHost, $dstHost, $traceStr) = split(/\|/, $payload->{'body'});
        
        unless (defined($traceStr))
        {
            $logger->error("Got malformed rabbitMQ message ", $payload->{'body'});
            next;
        }
        
        if ($ts < $refTime)
        {
            $logger->error("Got traceroute older than ", $refTime, " from RabbitMQ ", $payload->{'body'});
            next;
        }
        
        # create the subhashes if they don't exist
        if (!exists($trHash{$srcHost}))
        {
            $trHash{$srcHost} = {};
        }
        if (!exists($trHash{$srcHost}{$dstHost}))
        {
            # this is a list of hashes, one per timestamp, sorted in ascending time
            $trHash{$srcHost}{$dstHost} = [];
        }
        
        # Keep track of the current traceroute, compiling it to a list
        my @newPath = ();
        my %newEntry = (
            'ts' => $ts,
            'path' => \@newPath, # each hop may be load balanced, so each hop_no has an array to hold all possible hosts  
            'src' => $srcHost,
            'dst' => $dstHost,
        );
        push (@{$trHash{$srcHost}{$dstHost}}, \%newEntry);
        $lastHopNo = 0;
        
        # loop over each hop in traceroute entry, accumulating them into a list of TrHops
        foreach my $hopStr (split(';', $traceStr)) 
        {
            my ($hop_no, $hop_ip, $hop_name) = split(',', $hopStr);
                
            # skip malformed messages
            if (!defined($hop_name))
            {
                $logger->error("Got malformed rabbitMQ message ", $hopStr, ". Skipping this message");
                next;
            }
            
            # load balanced hops will show up as 2 consecutive hops with the same hop_no
            if ($lastHopNo != $hop_no) # not load balanced
            {
                my $newHop = new PuNDIT::Utils::TrHop($hop_name, $hop_ip);
                push (@newPath, $newHop);
            }
            else # load balanced hop
            {
                $newPath[-1]->addHopEntry($hop_name, $hop_ip);
            }
            
            # update for next hop
            $lastHopNo = $hop_no;
        }
    }
    
    return \%trHash;
}

1;
