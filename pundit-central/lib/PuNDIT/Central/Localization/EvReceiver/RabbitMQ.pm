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

    my $evHash = $self->getEventsMQ($lastTS, undef);
    return $evHash;
}

# Retrieves events from the MQ and processes them into a hash of event hashes
sub getEventsMQ
{
    my ($self, $startTS, $endTS) = @_;

    # init an empty hash
    my %evHash = ();
    my $counter = 0;
    
    $logger->debug("Get from MQ");

    # make a nonblocking call
    while (my $payload = $self->{'_mq'}->recv(500))
    {
        last if !defined($payload); # no more messages to retrieve

        # Check payload matches the expected format
        if (!($payload->{'body'} =~ /^[^\|]*\|[^\|]*\|[\d\.]*\|([\d\.]*,[\d\.]*,[\d\.]*,[\d\.]*,[\d\.]*,[\d\.]*;)*$/)) {
            $logger->error("Got malformed rabbitMQ message ", $payload->{'body'});
            next;
        }
        

        
        # TODO: Use a binary format instead
        my ($srcHost, $dstHost, $baselineDelay, $measures) = split(/\|/, $payload->{'body'});
        
        # skip malformed messages
        if (!defined($measures))
        {
            $logger->error("Got malformed rabbitMQ message ", $payload->{'body'});
            next;
        }
        
        # create the subhashes if they don't exist
        if (!exists($evHash{$srcHost}))
        {
            $evHash{$srcHost} = {};
        }
        if (!exists($evHash{$srcHost}{$dstHost}))
        {
            $evHash{$srcHost}{$dstHost} = ();
        }
        
        # loop over each single timeseries entry
        foreach my $snapshot (split(';', $measures)) 
        {
            my ($startTime, $endTime, $detectionCode, $queueingDelay, $lossRatio, $reorderMetric) = split(',', $snapshot);
            
            # skip malformed messages
            if (!defined($reorderMetric))
            {
                $logger->error("Got malformed rabbitMQ message ", $snapshot);
                next;    
            }
            
            # discard outdated messages
            # disabled for now, we want to keep old messages in the db
            # next if $endTime < $startTs
            if ($endTime < $startTS)
            { 
                $logger->warn("Got outdated status message off rabbitMQ queue");
            }
            
            # reconstruct the status message
            my %event = (
                'startTime' => $startTime,
                'endTime' => $endTime,
                'srcHost' => $srcHost,
                'dstHost' => $dstHost,
                'baselineDelay' => $baselineDelay,
                'detectionCode' => $detectionCode,
                'queueingDelay' => $queueingDelay,
                'lossRatio' => $lossRatio,
                'reorderMetric' => $reorderMetric
            );
            
            push (@{$evHash{$srcHost}{$dstHost}}, \%event);
            $counter++;
        }
    }
    $logger->debug("Processed $counter entries into evHash");
    
    return \%evHash;
}

1;
