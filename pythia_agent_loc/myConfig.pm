#
# Copyright 2012 Georgia Institute of Technology
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

package myConfig;

use strict;

use Exporter;
use base 'Exporter';
our @EXPORT = qw($minWlen $maxWlen $dfield $tfield $sfield $rsfield $minProbDelay $maxInterProbGap $minProbDuration $minBinWidth $baseDensityThresh $minLowModeFrac $DATADIR $MINSCANDUR);


### config
our $minWlen = 5; #s
our $maxWlen = 60; #s

our $minProbDelay = 5; #ms
our $maxInterProbGap = 1; #s
our $minProbDuration = 10; #s
our $minLowModeFrac = 0.3; # %

our $minBinWidth = 0.1; #ms
our $baseDensityThresh = 0.2; #density of lowest mode

our $dfield = 2; #s
our $tfield = 3; #s
our $sfield = 1; #s
our $rsfield = 4; #s
###

our $DATADIR = "/var/lib/owamp/hierarchy/root/regular/";
#our $DATADIR = "/tmp/owp/";
our $MINSCANDUR = 300; #s


1;

