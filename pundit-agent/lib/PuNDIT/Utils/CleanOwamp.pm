#!perl -w
#
# Copyright 2015 Georgia Institute of Technology
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

# TODO REMOVE THIS MODULE


package PuNDIT::Utils::CleanOwamp;

use strict;
use Log::Log4perl qw(get_logger);

my $logger = get_logger(__PACKAGE__);

# Cleans old files in the owamp directories
sub cleanOldFiles
{
    my ($threshold, $datadir) = @_;
    
    if (!defined($threshold))
    {
        $threshold = 1;
    }
    if (!defined($datadir) || !(-e $datadir))
    {
        $logger->warn("Couldn't find $datadir to cleanup");
        return;
    }
    
	$logger->debug("cleaning owamp files older than $threshold hours in the past.");
	my $mintime = $threshold * 60;
	system("find $datadir/* -name \"*.owp\" -type f -mmin +$mintime -delete");
}

1;