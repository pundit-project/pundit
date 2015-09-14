#!perl -w
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

use strict;

require 'checkendhost.pl';
require 'symptomdiag.pl'; #for support vars

use DBI;
use dbConfig;
use myConfig;

sub prepareDB
{
	my $dbh = DBI->connect("DBI:mysql:$dbConfig::database:$dbConfig::host:$dbConfig::port", $dbConfig::user, $dbConfig::pw) or die
		"cannot connect to DB";
=pod
	my $query = "show tables";
	my $sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
	my $rv = $sqlQuery->execute or die "can't execute the query: $sqlQuery->errstr";
	while(my @row= $sqlQuery->fetchrow_array())
	{
		my $tables = $row[0];
		print "$tables\n";
	}
	my $rc = $sqlQuery->finish;
=cut
	return $dbh;
}

sub writeEventDB
{
	my $startTS = shift;
	my $endTS = shift;
	my $src = shift;
	my $dst = shift;
	my $diag = shift;
	#my $file = shift;
	my $filehandle = shift;
	my $filename = shift;

	my $dbh = prepareDB();

	### read file
	#my $png;
	#{
	#	local($/) = undef;  ## read the whole file at once
	#		open IMG, "< $file" or die "$!";
	#	binmode IMG;
	#	$png = <IMG>;
	#	close   IMG;
	#}

	my ($skey, $sval) = getSupportVar();
	my $sql = "INSERT INTO events (sendTS, recvTS, srchost, dsthost, diagnosis, plot, filename) VALUES (?, ?, ?, ?, ?, ?, ?)";
	$sql = "INSERT INTO events (sendTS, recvTS, srchost, dsthost, diagnosis, plot, $skey, filename) VALUES (?, ?, ?, ?, ?, ?, ?, ?)" if $skey !~ /^$/;
	my $sth = $dbh->prepare($sql) or die "It didn't work. [$DBI::errstr]\n";
	$sth->bind_param(1, $startTS);
	$sth->bind_param(2, $endTS);
	$sth->bind_param(3, $src);
	$sth->bind_param(4, $dst);
	$sth->bind_param(5, $diag);
	#$sth->bind_param(6, $png);
	$sth->bind_param(6, $filehandle);
	if($skey !~ /^$/)
	{
		$sth->bind_param(7, $sval);
		$sth->bind_param(8, $filename);
	}
	else
	{
		$sth->bind_param(7, $filename);
	}
	$sth->execute or die "It didn't work. [$DBI::errstr]\n";
	$sth->finish;

	# update overlapping events if needed
	if($diag =~ /Unknown/ and $myConfig::diagEnabled == 1)
	{
		checkUpdatePathMatches($dbh, $startTS, $endTS, $src, $dst, $diag);
	}

	$dbh->disconnect;
}

sub writeReorderEventDB
{
	my $startTS = shift;
	my $endTS = shift;
	my $src = shift;
	my $dst = shift;
	my $diag = shift;
	my $filename = shift;

	my $dbh = prepareDB();

	my $sql = "INSERT INTO reorderevents VALUES (?, ?, ?, ?, ?, ?)";
	my $sth = $dbh->prepare($sql) or die "It didn't work. [$DBI::errstr]\n";
	$sth->bind_param(1, $startTS);
	$sth->bind_param(2, $endTS);
	$sth->bind_param(3, $src);
	$sth->bind_param(4, $dst);
	$sth->bind_param(5, $diag);
	$sth->bind_param(6, $filename);
	$sth->execute or die "It didn't work. [$DBI::errstr]\n";
	$sth->finish;

	$dbh->disconnect;
}

sub writeLocalizationDataDB
{
	my $src = shift;
	my $dst = shift;
	my $mref = shift;
	my $lref = shift;
	my $stimeref = shift;

	my $dbh = prepareDB();
	my $n = @$mref;
	for(my $c = 0; $c < $n; $c++)
	{
		my $sql = "INSERT INTO localizationdata VALUES (?, ?, ?, ?, ?)";
		my $sth = $dbh->prepare($sql) or die "It didn't work. [$DBI::errstr]\n";
		$sth->bind_param(1, $src);
		$sth->bind_param(2, $dst);
		$sth->bind_param(3, $stimeref->[$c]);
		$sth->bind_param(4, $mref->[$c]);
		$sth->bind_param(5, $lref->[$c]);
		$sth->execute or die "It didn't work. [$DBI::errstr]\n";
		$sth->finish;
	}
	$dbh->disconnect;
};


1;

