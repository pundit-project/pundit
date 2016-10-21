#!/usr/bin/perl
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

package PuNDIT::Utils::Misc;

use POSIX qw(floor);
use Exporter;

our @ISA= qw( Exporter );

# these CAN be exported.
our @EXPORT_OK = qw( calc_bucket_id );

# these are exported by default.
our @EXPORT = qw( calc_bucket_id );

=pod

Miscellaneous functions

=cut

# Calculates the id for a given bucket given a timestamp
sub calc_bucket_id
{
    my ($curr_ts, $windowsize) = @_;
    return ($windowsize * floor($curr_ts / $windowsize));
}

1;