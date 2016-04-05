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

package PuNDIT::Central::Master;

use strict;
use Log::Log4perl qw(get_logger);

use PuNDIT::Central::Localization;

# globals
my $logger = get_logger(__PACKAGE__);
my $runLoop = 1;

sub exit_handler{
    $runLoop = 0;
}

# constructor
sub new
{
    my ($class, $cfgHash) = @_;
    
    # Get the list of measurement federations
    my $fedString = $cfgHash->{"pundit_central"}{"measurement_federations"};
    $fedString =~ s/,/ /g;
    my @fedList = split(/\s+/, $fedString);
    
    my %fedHash = ();
    foreach my $fedName (@fedList)
    {
        $logger->debug("Initialising locObj for $fedName");
        my $locObj = new PuNDIT::Central::Localization($cfgHash, $fedName);
        
        if (!defined($locObj))
        {
            $logger->error("Failed to initialize locObj for $fedName");
            return undef;
        }
        
        $fedHash{$fedName} = $locObj;
    }
    
    my $self = {
        '_fedHash' => \%fedHash, # hash of feds
    };
    
    bless $self, $class;
    return $self;
}

sub DESTROY
{
    my ($self) = @_;
}

sub run
{
    my ($self) = @_;
    
    while ($runLoop)
    {    
        $logger->debug("Master thread woke");
        
        my $sleepTime = 60; # guaranteed to run once every 60 seconds
        while (my ($fedName, $locObj) = each(%{$self->{'_fedHash'}}))
        {
            $logger->debug("Master thread running localization for federation $fedName");
            
            # each run returns the amount of time to sleep
            my $nextRun = $locObj->run();
            
            $logger->debug("NextRun for federation $fedName is $nextRun");
            
            # keep track of the next run
            if ($nextRun < $sleepTime)
            {
                $sleepTime = $nextRun;
            }
        }
        
        $logger->debug("Master thread sleeping for $sleepTime");
        
        # sleep until next time localisation needs to run
        sleep($sleepTime);
    }
}