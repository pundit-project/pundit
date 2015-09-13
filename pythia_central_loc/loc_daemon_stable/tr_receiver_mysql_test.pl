#!/usr/bin/perl
#use 5.012;
use warnings;

use Data::Dumper;
#use Clone qw(clone);

require "loc_config.pl";
require "tr_receiver_mysql.pl";

my $cfg = new Loc::Config("localization.conf");
my $mysql_rcv = new Loc::TrReceiver::Mysql($cfg);

print Dumper $mysql_rcv->get_tr_hosts_all();