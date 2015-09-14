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
=pod
tr_receiver_mysql.pl

Interface to get traceroutes stored in MySQL
=cut

package Loc::TrReceiver::Mysql;

use strict;

# Database
use DBI qw(:sql_types);

use Data::Dumper;

# Init the db connection
# Returns
# 1 if success, 0 otherwise
sub new
{
    my $class = shift;
    my $cfg = shift;
    
    # init the DBI
    my $host = $cfg->get_param("mysql", "host");
    my $port = $cfg->get_param("mysql", "port");
    my $database = $cfg->get_param("mysql", "database");
    my $user = $cfg->get_param("mysql", "user");
    my $pw = $cfg->get_param("mysql", "password");
    
    my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $pw) or return undef;
    
    # we need the hosts info so we can do checking
    my $hosts = $cfg->get_param("traceroute", "hosts");
    my $tr_freq = $cfg->get_param("traceroute", "tr_frequency");
        
    my $self = {
        _config => $cfg,
        _dbh => $dbh,
        _hosts => $hosts,
        _tr_freq => $tr_freq,
    };
    
    bless $self, $class;
    return $self;
}

# return the traceroute src, dst pairs within the last tr_freq seconds
sub get_recent_hosts
{
    my ($self) = @_;
    
    # We want all entries within the last tr_freq calls
    my $last_time = time() - $self->{'_tr_freq'};
    
    return $self->get_hosts_timerange($last_time, time());
}

# return the traceroute src, dst pairs within a specified time range 
sub get_hosts_timerange
{
    my ($self, $start_ts, $end_ts) = @_;
    
    my $dbh = $self->{'_dbh'};
    
    # if there are 2 entries in the same time period, this query should overwrite earlier ones.
    my $sql = "SELECT ts, src, dst FROM traceroutes WHERE ts >= $start_ts AND ts <= $end_ts GROUP BY src, dst ORDER BY src ASC, ts DESC";
    my $sth = $dbh->prepare($sql) or return undef;
    
    $sth->execute() or return undef;
    
    return undef if (!$sth);
    
    # Init an empty array
    my @host_array = ();
        
    while (my $ref = $sth->fetchrow_hashref) 
    {
        push (@host_array, $ref);
    }
    
    return \@host_array;
}

sub get_tr_host($)
{
    my ($self, $tr_host) = @_;
    
    #$sth->execute($tr_host->{'ts'}, $tr_host->{'src'}, $tr_host->{'dst'}) or return undef;
}

# builds the whole tr_list struct from all the entries
sub get_tr_hosts_all() 
{
    my ($self) = @_;
    
    my $host_array = $self->get_recent_hosts();
    
    my @tr_list = ();
    
    return undef if (!$host_array);
    
    my $dbh = $self->{'_dbh'};
#    $dbh->trace($dbh->parse_trace_flags('SQL|1|test'));
    
#    my $sql = "SELECT hop_no, hop_name FROM traceroutes WHERE ( ts = \$ ) AND ( src = \$ ) AND ( dst = \$ ) ORDER BY hop_no DESC";
#    my $sth = $dbh->prepare($sql) or return undef;

    foreach my $host_tr (@$host_array)
    {
        # I don't know why this doesn't work
        # using crude workaround
#        $sth->execute($host_tr->{'ts'}, $host_tr->{'src'}, $host_tr->{'dst'}) or next;

        my $sql = "SELECT hop_no, hop_name FROM traceroutes WHERE ( ts = $host_tr->{'ts'} ) AND ( src = \'$host_tr->{'src'}\' ) AND ( dst = \'$host_tr->{'dst'}\' ) ORDER BY hop_no ASC";
        
        my $sth = $dbh->prepare($sql) or return undef;
        $sth->execute() or next;
        
        next if (!$sth);
        
        my @path = ();
        
        # faster method than fetchrow_hashref
        my $counter = 1;
        my ($src, $hop_no, $hop_name);
        $sth->bind_columns ( \$hop_no, \$hop_name );
        while ($sth->fetchrow_arrayref)
        {
            # preserve stars
            while (int($hop_no) > $counter)
            {
                push(@path, '*');
                $counter++;
            }
            push(@path, $hop_name);
            $counter++;
        }
        
        my $tr_entry = { 
            'ts' => $host_tr->{'ts'},
            'dst' => $host_tr->{'dst'},
            'path' => \@path,
        };
        
        # check the last entry and append a new src if not
        if (!@tr_list || $tr_list[-1]{'src'} != $host_tr->{'src'})
        {
            my $new_host = { 
                'src' => $host_tr->{'src'}, 
                'tr_list' => [ $tr_entry ], 
            };
            push(@tr_list, $new_host);
        }
        else
        {
            push(@{$tr_list[-1]{'tr_list'}}, $tr_entry);
        }
    }
    
    return \@tr_list;
}

1;