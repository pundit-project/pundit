#!/usr/bin/perl
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

package Loc::Reporter::Bool;

use strict;
use DBI;

# debug. Remove this for production
#use Data::Dumper;
#require "loc_config.pl";
#my $cfg = new Loc::Config("localization.conf");

# Creates a new object
sub new
{
	my $class = shift;
    my $cfg = shift;
    my $metric = shift;
    
	# init the DBI
	my $host = $cfg->get_param("mysql", "host");
	my $port = $cfg->get_param("mysql", "port");
	my $database = "pythia";
	my $user = $cfg->get_param("mysql", "user");
	my $pw = $cfg->get_param("mysql", "password");
	
	my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $pw) or return undef;
	my $sql;
	
	if ($metric eq 'lossMetric')
	{
		# Create the table if it doesn't exist
		$dbh->do("CREATE TABLE IF NOT EXISTS loss_bool_results (
			start_time INT,
			link VARCHAR(25)
			);");
		
		$sql = "INSERT INTO loss_bool_results (start_time, link) VALUES (?, ?)";
	}
	elsif ($metric eq 'reorderMetric')
	{
		# Create the table if it doesn't exist
		$dbh->do("CREATE TABLE IF NOT EXISTS reorder_bool_results (
			start_time INT,
			link VARCHAR(25)
			);");
		
		$sql = "INSERT INTO reorder_bool_results (start_time, link) VALUES (?, ?)";
	}
	
	return if (!defined($sql));
	my $sth = $dbh->prepare($sql) or return undef;
	
	my $self = {
        _config => $cfg,
        _dbh => $dbh,
        _sth => $sth
    };
    
    bless $self, $class;
    return $self;
}

# Writes the result array to the database
sub write_data
{
	my ($self, $start_time, $data_array) = @_;
	
	my $sth = $self->{'_sth'};
	my $dbh = $self->{'_dbh'};
	
	foreach my $element (@$data_array)
	{
		$sth->execute($start_time, $element) or print "$dbh->errstr\n";
	}
}

# Cleanup
sub DESTROY
{
	my $self = shift;
	
	my $sth = $self->{'_sth'};
	my $dbh = $self->{'_dbh'};
	
	$sth->finish if $sth;
	$dbh->disconnect if $dbh;
}

1;

=pod
my $rpt = new Loc::Reporter::Range($cfg);
my @data_array = (
	{
		'link' => "1.1.1.1",
		'range' => [2.5, 2.75],
	},
	{
		'link' => "1.1.1.2",
		'range' => [2.5, 3.75],
	}
);
$rpt->write_data(100, \@data_array);
=cut