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

package Localization;

use strict;
use POSIX qw(floor strftime);

# local libs
use Localization::Tomography;
use Localization::TrReceiver;
use Localization::EvReceiver;

my $runLoop = 1;

sub exit_handler{
    $runLoop = 0;
}

# constructor
sub new
{
    my ($class, $cfgHash, $fedName) = @_;
        
    my $tomography = new Localization::Tomography($cfgHash, $fedName);
    return undef if (!defined($tomography));
    my $trReceiver = new Localization::TrReceiver($cfgHash, $fedName);
    return undef if (!defined($trReceiver));
    my $evReceiver = new Localization::EvReceiver($cfgHash, $fedName);
    return undef if (!defined($evReceiver));
    
    # parameters from config file
    my $windowSize = $cfgHash->{"pundit_central"}{$fedName}{"localization"}{"window_size"};
    return undef if (!defined($windowSize));
    
    my $lagTime = $cfgHash->{"pundit_central"}{$fedName}{"localization"}{"lag_time"};
    return undef if (!defined($lagTime));
    
    my $self = {
        '_windowSize' => $windowSize, # reference window size, in seconds
        '_lagTime' => $lagTime, # Number of minutes to wait before analyzing
        
        # submodules
        '_tomography' => $tomography,
        '_trReceiver' => $trReceiver,
        '_evReceiver' => $evReceiver,
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
    
    # Time lag converted from minutes to seconds
    my $timeLag = $self->{'_lagTime'} * 60;
    my $windowSize = $self->{'_windowSize'};
    
    # This is the reference time that we want to process. Uses a fixed time lag
    my $refTime = calc_bucket_id(time, $windowSize) - $timeLag;
    
    # variables
    my $sleep_time = 0; # Number of seconds to sleep until the next run (dynamic)

    # run the loop
    while ($runLoop)
    {
        print "Running localization on $refTime (", strftime("%F %T", localtime($refTime)), "):\n";
        
        # Get the current updated traceroute matrix
        my ($trMatrix, $trNodeList) = $self->{'_trReceiver'}->getTrMatrix($refTime, $refTime + $windowSize);

        # grab the event table from db
        my ($evTable) = $self->{'_evReceiver'}->getEventTable($refTime, $refTime + $windowSize);
    
        # Process this tr matrix and event table for this reference timestamp
        $self->{'_tomography'}->processTimeWindow($refTime, $trMatrix, $trNodeList, $evTable);
        
        $refTime += $windowSize; # advance the reference time after processing
        
        # sleep until the next run
        $sleep_time = $refTime + $timeLag - time();
        sleep $sleep_time if $sleep_time > 0;
        
        $refTime += $windowSize; # advance window by 5
        
        # ensure that the delay is 
        while ((time - $timeLag) < $refTime)
        {
            sleep(5);
        }
    }
}

# Calculates the id for a given bucket given a timestamp
sub calc_bucket_id
{
    my ($curr_ts, $windowsize) = @_;
    return ($windowsize * floor($curr_ts / $windowsize));
}