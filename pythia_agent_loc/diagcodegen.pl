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

require 'treeutil.pl';

sub codegenHeader
{
	open(OUT, ">dtreerun.pl") or die;
	print OUT "#!perl -w\n";
	print OUT "use strict;\n\n";
	print OUT "require 'symptomdiag.pl';\n\n";
	print OUT "sub diagnosisTree {\n";
	print OUT "my \$diagstr = \"\";\n\n";
	close OUT;
};

sub codegenIsland
{
	my $root = shift;
	my $symptom_procs = shift;
	open(OUT, ">>dtreerun.pl") or die;

	my @codearr = ();
	dfsCodeGen($root, \@codearr, 0, $symptom_procs);

	my $n = @codearr;
	for(my $c = 0; $c < $n; $c++)
	{
		print OUT "$codearr[$c]\n";
	}
	close OUT;
};

sub codegenTrailer
{
	open(OUT, ">>dtreerun.pl") or die;
	print OUT "\$diagstr = \"Unknown<BR>\" if \$diagstr =~ /^\$/;\n";
	print OUT "return \$diagstr;\n";
	print OUT "};\n\n";
	print OUT "1;\n";
	close OUT;
}

sub dfsCodeGen {
	my $root = shift;
	my $codearrref = shift;
	my $curpos = shift; #curpos is inside the "if' condition of parent edge
	my $symptom_procs = shift;

	if($root->{TYPE} == 2)
	{
		my $pathology = $root->{VAL}; $pathology =~ s/-1$//;
		my $str = "\$diagstr .= \"$pathology<BR>\";";
		splice(@$codearrref, $curpos, 0, $str); $curpos++;
		return $curpos;
	}

	my $carr = $root->{CHILD};
	return $curpos if !defined $carr;
	my $n = @{$carr};
	for(my $c = 0; $c < $n; $c++)
	{
		my $child = $carr->[$c];
		#"$root->{VAL} -> $child->{VAL} label:$root->{CHILDLABEL}[$c]\n";
		if($root->{CHILDLABEL}[$c] == 1 or $root->{CHILDLABEL}[$c] == 2)
		{
			my $str = "if(".$symptom_procs->{$root->{VAL}}."() == $root->{CHILDLABEL}[$c]) {";
			splice(@$codearrref, $curpos, 0, $str); $curpos++;

			$curpos = dfsCodeGen($child, $codearrref, $curpos, $symptom_procs);

			$str = "}";
			splice(@$codearrref, $curpos, 0, $str); $curpos++;
		}
		elsif($root->{CHILDLABEL}[$c] == 0)
		{
			$curpos = dfsCodeGen($child, $codearrref, $curpos, $symptom_procs);
		}
	}
	return $curpos;
};


1;

