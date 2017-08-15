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

# handles input file detection and queueing
package PuNDIT::Agent::InfileScheduler;

use strict;
use Log::Log4perl qw(get_logger);

use PuNDIT::Agent::LocalizationTraceroute;
use PuNDIT::Utils::HostInfo;

my $logger = get_logger(__PACKAGE__);

# creates a new infile scheduler, which calls the detection object on the files in the specified path 
sub new
{
    my ($class, $cfgHash, $detHash) = @_;
    
    my $hostId = PuNDIT::Utils::HostInfo::getHostId();

    my $self = {        
        _hostId => $hostId,

        _detHash => $detHash,
        _cfgHash => $cfgHash,

        # TODO Not implemented.
        # flag that indicates whether a traceroute should be run after a problem is detected
        _runTrace => 1, 
        
    };
    
    bless $self, $class;
    return $self;
}

# Public Method. Runs a single iteration of the schedule 
# Call this only in a loop with a sleep() operation 
sub runSchedule
{
    my ($self, $dataIn) = @_;
    
    $self->_processFiles($dataIn);
}

# No longer processes "files" after adopting rabbitmq
# it processes a message as it arrives.
sub _processFiles
{
    my ($self, $dataIn) = @_;
       
    my $return = $self->_processOwpfile($dataIn);
}

# processes an owamp file here. Deletes the file when done with it.
sub _processOwpfile
{
    my ($self, $dataIn) = @_;
    
    $logger->debug("Processing $dataIn");
    
    while (my ($fedName, $detObj) = each (%{$self->{'_detHash'}}))
    {
        # each detobj will know whether the owamp file belongs to the federation
        # $return - the number of problems detected, 0 or -1 (not a member of federation)
        # $stats - status summary generated from this file
        my ($return, $stats) = $detObj->processFile($dataIn); 
        
        # One or more problems were detected
        if ($return > 0)
        {
             $logger->info("$fedName analysis: $return problems for " . $stats->{'srcHost'} . " to "  . $stats->{'dstHost'});

            #run trace if runTrace option is enabled
            if ($self->{'_runTrace'})
            {            
                if ($stats->{'srcHost'} eq $self->{'_hostId'})
                {
                    $logger->debug('runTrace enabled. Running trace to ' . $stats->{'dstHost'});
                    my $tr_helper = new PuNDIT::Agent::LocalizationTraceroute($self->{'_cfgHash'}, $fedName, $stats->{'srcHost'});
                    $tr_helper->runTrace($stats->{'dstHost'});
                }
                else
                {
                    $logger->debug("runTrace enabled. Can't run trace on this host: It is the destination");
                }
            }
            
        }
    }

    return 0; # return ok 
}


