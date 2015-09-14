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
use DBI;

sub queryDB
{
	my $dbh = shift;
	my $query = shift;
	my $sqlQuery  = $dbh->prepare($query) or die "Can't prepare $query: $dbh->errstr\n";
	$sqlQuery->execute or die "can't execute the query: $sqlQuery->errstr";
	return $sqlQuery;
};

sub checkUpdatePathMatches
{
	my $dbh = shift;
	my $sendTS = shift;
	my $recvTS = shift;
	my $srchost = shift;
	my $dsthost = shift;
	my $diagnosis = shift;

	my $query2 = "select count(*) from events where ((sendTS > $sendTS-5 AND sendTS < $recvTS+5) ".
		"OR (recvTS > $sendTS-5 AND recvTS < $recvTS+5)) AND ".
		"(dsthost = '$dsthost' OR srchost = '$srchost') AND ".
		"(diagnosis REGEXP 'Unknown' OR diagnosis REGEXP 'EndHostNoise')";
	my $sqlQuery2  = queryDB($dbh, $query2);
	my @rowint = $sqlQuery2->fetchrow_array();
	$sqlQuery2->finish;

	$query2 = "select count(distinct srchost) from events where dsthost = '$dsthost'";
	$sqlQuery2  = queryDB($dbh, $query2);
	my @rowinttot1 = $sqlQuery2->fetchrow_array();
	$sqlQuery2->finish;
	$query2 = "select count(distinct dsthost) from events where srchost = '$srchost'";
	$sqlQuery2  = queryDB($dbh, $query2);
	my @rowinttot2 = $sqlQuery2->fetchrow_array();
	$sqlQuery2->finish;

	#print "$diagnosis  matches $rowint[0] ".($rowinttot1[0]+$rowinttot2[0])."\n";
	my $fracevents = ($rowinttot1[0]+$rowinttot2[0] != 0) ? 
		$rowint[0]/($rowinttot1[0]+$rowinttot2[0]) : -1;

	return $fracevents if $fracevents < 0.6;

	$query2 = "update events set diagnosis='EndHostNoise<BR>' ".
		"where ((sendTS > $sendTS-5 AND sendTS < $recvTS+5) ".
		"OR (recvTS > $sendTS-5 AND recvTS < $recvTS+5)) AND ".
		"(dsthost = '$dsthost' OR srchost = '$srchost') AND ".
		"(diagnosis REGEXP 'Unknown' OR diagnosis REGEXP 'EndHostNoise')";
	$sqlQuery2  = queryDB($dbh, $query2);
	$sqlQuery2->finish;
	#print $query2."\n";

	return $fracevents;
};


=pod
### this was used to update the old table
my $dbh = prepareDB();
my $query = "select * from events";
my $sqlQuery = queryDB($dbh, $query);
while(my @row= $sqlQuery->fetchrow_array())
{
	my $sendTS = $row[0];
	my $recvTS = $row[1];
	my $srchost = $row[2];
	my $dsthost = $row[3];
	my $diagnosis = $row[4];
	if($diagnosis =~ /Unknown/)
	{
		checkUpdatePathMatches($dbh, $sendTS, $recvTS, $srchost, $dsthost, $diagnosis);
	}
}
$sqlQuery->finish;
$dbh->disconnect;
=cut

1;

