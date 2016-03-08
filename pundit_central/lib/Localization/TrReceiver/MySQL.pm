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

=pod
Localization::TrReceiver::MySQL.pm

Interface to get traceroutes stored in MySQL
=cut

package Localization::TrReceiver::MySQL;

use strict;
use threads::shared;

# Database
use DBI qw(:sql_types);

# debug
use Data::Dumper;

# Init the db connection
# Returns
# 1 if success, 0 otherwise
sub new
{
    my ($class, $cfgHash, $siteName) = @_;
    
    # init the DBI
    my $host = $cfgHash->{'pundit_central'}{$siteName}{'tr_receiver'}{'mysql'}{"host"};
    my $port = $cfgHash->{'pundit_central'}{$siteName}{'tr_receiver'}{'mysql'}{"port"};
    my $database = $cfgHash->{'pundit_central'}{$siteName}{'tr_receiver'}{'mysql'}{"database"};
    my $user = $cfgHash->{'pundit_central'}{$siteName}{'tr_receiver'}{'mysql'}{"user"};
    my $pw = $cfgHash->{'pundit_central'}{$siteName}{'tr_receiver'}{'mysql'}{"password"};
    
    my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $pw) or return undef;
    
    my $self = {
        '_dbh' => $dbh,
    };
    
    bless $self, $class;
    return $self;
}

# Cleanup
sub DESTROY
{
    my ($self) = @_;
    
    my $dbh = $self->{'_dbh'};
    
    $dbh->disconnect if $dbh;
}

# returns the traces that are on or after this timestamp
sub getLatestTraces
{
    my ($self, $timestamp) = @_;
    
    return $self->_get_hosts_timerange($timestamp, undef);
}

# return the traceroute src, dst pairs within a specified time range
# if the end_ts parameter is undefined, returns all the entries from the  
sub _get_hosts_timerange
{
    my ($self, $start_ts, $end_ts) = @_;
    
    my $dbh = $self->{'_dbh'};
    
    # The SQL query ensures that the hops will be sorted in order. 
    # The processing steps later will rely on this order
    my $sql;
    if (defined($end_ts))
    {    
        $sql = "SELECT ts, src, dst, hop_no, hop_ip, hop_name FROM traceroutes 
                WHERE $start_ts <= ts AND ts <= $end_ts 
                ORDER BY src ASC, dst ASC, ts ASC, hop_no ASC";
    }
    else
    {
        $sql = "SELECT ts, src, dst, hop_no, hop_ip, hop_name FROM traceroutes 
                WHERE $start_ts <= ts 
                ORDER BY src ASC, dst ASC, ts ASC, hop_no ASC";
    }
    
    # prepare and run the SQL query
    my $sth = $dbh->prepare($sql) or return undef;
    $sth->execute() or return undef;
    return undef if (!$sth);
    
    # Init an empty hash
    my %trHash :shared = ();
    
    # variables for error checking
    my $lastTs;
    my $lastHopNo;
    
    # fetchrow_arrayref should be faster than fetchrow_hashref
    while (my $ref = $sth->fetchrow_arrayref) 
    {        
        # create hash for src
        if (!exists($trHash{$ref->[1]}))
        {
            $trHash{$ref->[1]} = &share({}); # hash, for destinations
        }
        
        # create hash for dst
        if (!exists($trHash{$ref->[1]}{$ref->[2]}))
        {
            $trHash{$ref->[1]}{$ref->[2]} = &share([]); # array, sorted by timestamp
        }
        
        # list of traceroutes, sorted by time
        my $currTrList = $trHash{$ref->[1]}{$ref->[2]};
        my $currTs :shared = $ref->[0] * 1;
        my $currHopNo :shared = $ref->[3] * 1; 
        my %newHop :shared = (
            'hop_ip' => $ref->[4], 
            'hop_name' => $ref->[5],
        );
        
        # create hash for new trace if
        # 1. TrList is empty
        # 2. Time mismatch with last entry for that src dst pair
        # 3. First hop in a new path (need to check behaviour of lost packets)
        if ((scalar(@$currTrList) == 0) || 
            ($lastTs != $currTs) ||
            ($lastHopNo > $currHopNo))
        {
#            print "Adding new entry. \$trList is " . scalar(@$currTrList) . " $lastTs $currTs\t$lastHopNo $currHopNo\n";

            my @newHopList :shared = ( \%newHop );
            my @newPath :shared = ( \@newHopList, );
            my %newEntry :shared = (
                      'ts' => $currTs,
                      'path' => \@newPath, # each hop may be load balanced, so each hop_no has an array to hold all possible hosts  
                  );
            push (@{$currTrList}, \%newEntry);
        }
        else # append to the last path 
        {
#            print "Appending $currTs\t$currHopNo\n";
            
            # check if last hop was load balanced
            if ($lastHopNo == $currHopNo)
            {
                # append to last hop at the same level
                push (@{$currTrList->[-1]{'path'}[-1]}, \%newHop);
            }
            else # else add new hop
            {
                my @newHopList :shared = ( \%newHop );
                push (@{$currTrList->[-1]{'path'}}, \@newHopList); # note each entry is a list of nodes
            }
        }
        
        # save for next hop
        $lastTs = $currTs;
        $lastHopNo = $currHopNo;
    }
        
    return \%trHash;
}

1;
