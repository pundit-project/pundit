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
require "tr_receiver_mysql.pl";

my $cfg = new Loc::Config("localization.conf");
my $mysql_rcv = new Loc::TrReceiver::Mysql($cfg);

print Dumper $mysql_rcv->get_tr_hosts_all();