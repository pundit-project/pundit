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

package CheckMkReporter;

sub new
{
    my ($class, $cfg) = @_;
    
    my %cfgHash = Config::General::ParseConfig($cfg);
    
    my $self = {
        '_processedCountInterval' => 60, # interval between reports, in seconds
        '_processedCountPath' => './processed_count', # file to write to
        '_processedCountNum' => 0, 
        '_processedCountLast' => undef,
    };
    
    bless $self, $class;
    return $self;
}

# This should be called every second by detection logic
sub reportProcessedCount
{
    my ($self, $count) = @_;
    
    if (!$self->{'_processedCountLast'} || (time - $self->{'_processedCountLast'}) >= $self->{'_processedCountInterval'})
    {
        open my $process_fh, ">", $self->{'_processedCountPath'};
        print $process_fh $self->{'_processedCountNum'};
        close $process_fh;
        
        $self->{'_processedCountNum'} = 0;
        $self->{'_processedCountLast'} = time;
    }
    
    $self->{'_processedCountNum'} += $count;
}

1;