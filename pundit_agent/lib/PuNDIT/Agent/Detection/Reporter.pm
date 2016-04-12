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

# handles output queueing for reporting events
package PuNDIT::Agent::Detection::Reporter;

use strict;
use Log::Log4perl qw(get_logger);

use PuNDIT::Agent::Detection::Reporter::MySQL;

my $logger = get_logger(__PACKAGE__);

sub new
{
    my ($class, $cfgHash, $fedName) = @_;
    
    my ($type) = $cfgHash->{"pundit_agent"}{$fedName}{"reporting"}{"type"};
    
    my $reporter;
    if ($type eq "mysql") 
    {
        $logger->debug("Initializing MySQL Detection Reporter");
        $reporter = new PuNDIT::Agent::Detection::Reporter::MySQL($cfgHash, $fedName);
    }
    elsif ($type eq "rabbitmq")
    {
        #TODO: add rabbitmq init here
    }
    
    my $self = {
        _type => $type, # type of reporter
        _reporter => $reporter, # reporter object
        
        # for multithreaded
        _lock => 0, # crude locking 
        _queue => [], # empty queue
    };
    
    bless $self, $class;
    return $self;
}

# internal function because eventually we want to make it multithreaded 
sub _enqueue
{
    my ($self, $event) = @_;
    
    while ($self->{'_lock'} == 1)
    {
        sleep 1;
    }
    $self->{'_lock'} = 1;
    push(@{$self->{'_queue'}}, [$event]);
    $self->{'_lock'} = 0;
}

# internal function because eventually we want to make it multithreaded
sub _dequeue
{
    my ($self) = @_;
    
    while ($self->{'_lock'} == 1)
    {
        sleep 1;
    }
    $self->{'_lock'} = 1;
    my $event = shift(@{$self->{_queue}});
    $self->{'_lock'} = 0;
    
    return $event;
}

# gets the queue size
sub _getQueueSize
{
     my ($self) = @_;
     
     return -1 if ($self->{'_lock'} == 1);
     return scalar(@{$self->{'_queue'}});
}

# Public function for writing events. 
# Legacy format. Will be removed soon
# Eventually we want to make it multithreaded, so will use enqueue and dequeue
sub writeEvent
{
    my ($self, $event) = @_;
    
    $self->{'_reporter'}->writeEvent($event);
}

# Public function for writing statuses (once every minute) 
# Eventually we want to make it multithreaded, so will use enqueue and dequeue
sub writeStatus
{
    my ($self, $status) = @_;
    
    # TODO: clear the queue here
    
    eval
    {
        $self->{'_reporter'}->writeStatus($status);
    };
    # catch any exception here
    if ($@)
    {
        # TODO: Put the status on a queue for resending later
        $logger->warn("Failed to write status to server. Discarding status from " . $status->{'srcHost'} . " to " . $status->{'dstHost'} . " at " . $status->{'startTime'});
    }
}

1;