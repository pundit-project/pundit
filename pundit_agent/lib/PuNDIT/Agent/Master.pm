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

package PuNDIT::Agent::Master;

use strict;
use Log::Log4perl qw(get_logger);

# local libs
use PuNDIT::Agent::Detection;
use PuNDIT::Agent::InfileScheduler;
use PuNDIT::Agent::Utils::CleanOwamp;

my $logger = get_logger(__PACKAGE__);

# Top-level init for agent master
sub new
{
    my ( $class, $cfgHash ) = @_;

    my $cleanupThreshold = $cfgHash->{"pundit_agent"}{"owamp_data"}{"cleanup_threshold"};
    my $owampPath = $cfgHash->{"pundit_agent"}{"owamp_data"}{"path"};  
    
    # Get the list of measurement federations
    my $fedString = $cfgHash->{"pundit_agent"}{"measurement_federations"};
    $fedString =~ s/,/ /g;
    my @fedList = split(/\s+/, $fedString);

    if (!@fedList)
    {
        $logger->error("Empty federation list! Corrupt/invalid configuration file.");
        return undef;
    }

    my %detHash = ();
    foreach my $fed (@fedList)
    {
        $logger->debug("Creating Detection Object: $fed");
        my $detectionModule = new PuNDIT::Agent::Detection($cfgHash, $fed);
        
        if (!$detectionModule)
        {
            $logger->error("Couldn't init detection object for federation $fed. Quitting.");    
            return undef;
        }
        
        $detHash{$fed} = $detectionModule;
    }
    
    my $infileScheduler = new PuNDIT::Agent::InfileScheduler($cfgHash, \%detHash);
    if (!$infileScheduler)
    {
        $logger->error("Couldn't init infileScheduler. Quitting.");    
        return undef;
    }
        
    my $self = {
        '_fedList' => \@fedList,
        '_detHash' => \%detHash,
        '_inFileSched' => $infileScheduler,
        
        '_cleanupThresh' => $cleanupThreshold,
        '_owampPath' => $owampPath, 
    };

    bless $self, $class;
    return $self;
}

# Top-level exit for event receiver
sub DESTROY
{

    # Do nothing?
}

sub run
{
    my ($self) = @_;
    
    # Clean old owamp files
    PuNDIT::Agent::Utils::CleanOwamp::cleanOldFiles($self->{'_cleanupThresh'}, $self->{'_owampPath'});
    
    my $runLoop = 1;
    
    while($runLoop)
    {
        $logger->debug("Master woke. Running schedule.");
        $self->{'_inFileSched'}->runSchedule();
        sleep(10);
    }
}

1;