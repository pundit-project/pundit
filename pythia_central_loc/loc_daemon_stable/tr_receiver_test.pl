#!/usr/bin/perl
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
#use 5.012;
use warnings;

use Data::Dumper;
#use Clone qw(clone);

require "loc_config.pl";
require "tr_receiver.pl";

my $cfg = new Loc::Config("localization.conf");
my $rcv = new Loc::TrReceiver($cfg);

# Test Code
my ($out_first_tr_ts, $out_last_tr_ts, $tr_matrix, $tr_nl) = $rcv->get_tr_matrix(0, 0);
print $out_first_tr_ts . " to " . $out_last_tr_ts . "\n";
print Dumper ($tr_matrix);
print Dumper ($tr_nl);

=pod
my ($first, $last, $x, $y) = process_tr_all(\@tr_list);
print "First is $first, Last is $last\n";
print "x is ";
print Dumper ($x);
print "y is ";
print Dumper ($y);
=cut