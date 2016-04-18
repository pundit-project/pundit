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

package PuNDIT::Central::Localization;

use strict;
use Log::Log4perl qw(get_logger);
use POSIX qw(floor strftime);

# local libs
use PuNDIT::Central::Localization::Tomography;
use PuNDIT::Central::Localization::TrReceiver;
use PuNDIT::Central::Localization::EvReceiver;

my $logger = get_logger(__PACKAGE__);

# constructor
sub new
{
    my ($class, $cfgHash, $fedName) = @_;
        
    my $tomography = new PuNDIT::Central::Localization::Tomography($cfgHash, $fedName);
    return undef if (!defined($tomography));
    my $trReceiver = new PuNDIT::Central::Localization::TrReceiver($cfgHash, $fedName);
    return undef if (!defined($trReceiver));
    my $evReceiver = new PuNDIT::Central::Localization::EvReceiver($cfgHash, $fedName);
    return undef if (!defined($evReceiver));
    
    # parameters from config file
    my $windowSize = $cfgHash->{"pundit_central"}{$fedName}{"localization"}{"window_size"};
    if (!defined($windowSize))
    {
        $logger->error("Mandatory parameter window size not defined in federation $fedName config. Quitting");
        return undef;
    }
    
    my $processingDelta = $cfgHash->{"pundit_central"}{$fedName}{"localization"}{"processing_time_delta"};
    if (!defined($processingDelta))
    {
        $logger->error("Mandatory parameter processing time delta not defined in federation $fedName config. Quitting");
        return undef;
    }
    $processingDelta = $processingDelta * 60; # convert to seconds
    
    # This is the reference time that we want to process. Uses a fixed time lag
    my $refTime = calc_bucket_id(time(), $windowSize) - $processingDelta;
    
    my $self = {
        '_windowSize' => $windowSize, # reference window size, in seconds
        '_processingDelta' => $processingDelta, # Number of seconds to wait before analyzing
        
        # submodules
        '_tomography' => $tomography,
        '_trReceiver' => $trReceiver,
        '_evReceiver' => $evReceiver,
        
        # runtime variables
        '_refTime' => $refTime,
    };
    
    bless $self, $class;
    return $self;
}

sub DESTROY
{
    my ($self) = @_;
}

# Main entry point. Starts all the subprocesses
sub run
{
    my ($self) = @_;

    my $refTime = $self->{'_refTime'};
    my $windowSize = $self->{'_windowSize'};
    my $processingDelta = $self->{'_processingDelta'};
    
    # deadline not reached yet. Sleep until reftime + processingDelta has been reached
    if ((time() - $processingDelta) < $refTime)
    {
        $logger->debug("Not reached deadline yet.");
        return $refTime + $processingDelta - time();
    }

    # Get the current updated traceroute matrix
    my ($trMatrix, $trNodeList) = $self->{'_trReceiver'}->getTrMatrix($refTime, $refTime + $windowSize);

    # grab the event table from db
    my $evTable = $self->{'_evReceiver'}->getEventTable($refTime, $refTime + $windowSize);
    
#    $logger->debug(sub { Data::Dumper::Dumper($evTable) });
    
    # Process this tr matrix and event table for this reference timestamp
    $self->{'_tomography'}->processTimeWindow($refTime, $trMatrix, $evTable);
    
    $refTime += $windowSize; # advance the reference time after processing
    $self->{'_refTime'} = $refTime;
    
    # sleep until the next run
    my $sleepTime = $refTime + $processingDelta - time();
    if ($sleepTime < 0)
    {
        $logger->error("Localization Federation missed it's deadline. Central server possibly overloaded");
        $sleepTime = 0;
    }
    $logger->debug("Sleeptime is $sleepTime");
    return $sleepTime;
}

# Calculates the id for a given bucket given a timestamp
sub calc_bucket_id
{
    my ($curr_ts, $windowsize) = @_;
    return ($windowsize * floor($curr_ts / $windowsize));
}