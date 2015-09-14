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

sub saturation {
	my $dref = shift;
	my $tref = shift;

	my $oldd = $dref->[0];
	my $oldt = $tref->[0];
	my $n = @$dref;

	my $nGT1ratios = 0;
	my $nGT1_5ratios = 0;

	for(my $c = 0; $c < $n; $c++)
	{
		my $d = $dref->[$c]; #ms
		my $t = $tref->[$c]; #s

		my $sd = ($t - $oldt);
		my $rd = ($t + $d*1e-3) - ($oldt + $oldd*1e-3);

		my $ratio = ($sd < 0.1 and $sd != 0) ? $rd/$sd : -1;
		#print "RATIO $ratio at $oldt\n" if $ratio != -1;

		$nGT1ratios++ if $ratio > 1;
		$nGT1_5ratios++ if $ratio > 1.5;

		$oldd = $d;
		$oldt = $t;
	}

	my $rfrac = $nGT1_5ratios/$nGT1ratios;
	print "RATIO-frac $rfrac\n";
};

1;

