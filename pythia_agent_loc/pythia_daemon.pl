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

use POSIX qw(setsid);

umask 0;
open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
open(STDOUT, ">>run.log") or die;
open STDERR, '>>run.log' or die "Can't write to /dev/null: $!";
defined(my $pid = fork) or die "Can't fork: $!";
exit if $pid;
setsid or die "Can't start a new session: $!";

print "Starting server..\n";

# run this only on startup
`perl cleanowamp.pl >> run.log 2>&1`;

while(1)
{
	#`perl tree.pl`;
	`perl scandir.pl >> run.log 2>&1`;
}

