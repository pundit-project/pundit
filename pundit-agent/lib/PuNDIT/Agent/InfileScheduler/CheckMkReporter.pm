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

package PuNDIT::Agent::InfileScheduler::CheckMkReporter;

use Log::Log4perl qw(get_logger);

my $logger = get_logger(__PACKAGE__);

sub new
{
    my ($class, $cfgHash) = @_;
    
    my $processedCountEnabled = 1;
    my $processedCountInterval = $cfgHash->{"pundit-agent"}{"check_mk"}{"processed_count_interval"};
    my $processedCountPath = $cfgHash->{"pundit-agent"}{"check_mk"}{"processed_count_path"};
    if (!(defined($processedCountInterval)&&defined($processedCountPath)))
    {
        $logger->warn("processed_count variables not defined. Disabling this feature");
        $processedCountEnabled = 0;   
    }
        
    my $self = {
        '_processedCountEnabled' => $processedCountEnabled,
        '_processedCountInterval' => $processedCountInterval, # interval between reports, in seconds
        '_processedCountPath' => $processedCountPath, # file to write to
        
        '_processedCountNum' => 0, 
        '_processedCountLast' => undef,
    };
    
    bless $self, $class;
    return $self;
}

# This should be called every second by infileScheduler
sub reportProcessedCount
{
    my ($self, $count) = @_;
    
    # Skip this entire thing if not enabled
    return if ($self->{'_processedCountEnabled'} == 0);
    
    # Threshold passed, write out the variable
    if (!$self->{'_processedCountLast'} || (time - $self->{'_processedCountLast'}) >= $self->{'_processedCountInterval'})
    {
        $logger->debug("Writing out processed_count variable " . $self->{'_processedCountNum'});
        
        open my $process_fh, ">", $self->{'_processedCountPath'};
        print $process_fh $self->{'_processedCountNum'};
        close $process_fh;
        
        $self->{'_processedCountNum'} = 0;
        $self->{'_processedCountLast'} = time;
    }
    
    $self->{'_processedCountNum'} += $count;
}

1;
