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
require 'diagcodegen.pl';


open(IN, "tree.conf") or die;

my %symptom_id = ();
my %symptom_name = ();
my $sid = 0;
my %symptom_procs = ();

my @pmatrix = (); #0: NA, 1: true, 2: false
my %pathology_id = ();
my %pathology_name = ();
my $pid = 0;

sub generateMatrix {
#XXX: no support for braces yet
#XXX: check for conflicting instances
	my @lines = <IN>;
	for(my $linec = 0; $linec < scalar(@lines); $linec++)
	{
		my $line = $lines[$linec];

		next if $line =~ /^$/;
		next if $line =~ /^#/;

		if($line =~ /OR/) #XXX: assume only one OR in a statement
		{
			($line, my $line2) = handleOR($line);
			push(@lines, $line2);
		}

		my @obj = split(/\s+/, $line);

		if($line =~ /^SYMPTOM/)
		{
			$symptom_id{$obj[1]} = $sid++;
			next;
		}

		if($line =~ /^PATHOLOGY/)
		{
			$pathology_id{$obj[1]} = $pid++;

			my $n = @obj;
			for(my $c = 3; $c < $n; $c++)
			{
				next if $obj[$c] =~ /^AND$/;
				my $val = 1;
				if($obj[$c] =~ /^NOT$/) { $val = 2; $c++; }
				my $sid = $symptom_id{$obj[$c]};
				$pmatrix[ $pid-1 ][ $sid ] = $val;
			}
		}

		if($line =~ /^PROCEDURE/)
		{
			$symptom_procs{$obj[1]} = $obj[2];
		}
	}
	%symptom_name = reverse %symptom_id;
	%pathology_name = reverse %pathology_id;

	### mark unused symptoms
	for my $i (0 .. $#pmatrix)
	{
		for my $j (0 .. $sid)
		{
			$pmatrix[$i][$j] = 0 if !exists $pmatrix[$i][$j];
		}
	}

	close IN;
};

sub handleOR
{
	my $line = shift;

	my @orobj = split(/ OR /, $line);
	$line = $orobj[0];

	my @orobj1 = split(/\s+/, $line);
	my $a = $orobj1[scalar(@orobj1)-1];
	my $aprev = $orobj1[scalar(@orobj1)-2];
	if($aprev =~ /^NOT$/)
	{
		$orobj1[scalar(@orobj1)-2] = $orobj1[scalar(@orobj1)-1];
		delete $orobj1[scalar(@orobj1)-1];
	}
	else
	{
		splice(@orobj1, scalar(@orobj1)-1, 0, "NOT");
	}
	$orobj1[1] =~ s/$/-1/;
	my $line2 = "@orobj1 AND $orobj[1]";
	print "OR: $line\nOR: $line2\n";
	return ($line, $line2);
};

sub printMatrix {
### print matrix
	for my $i (0 .. $#pmatrix)
	{
		for my $j (0 .. $#{$pmatrix[$i]})
		{
			print "$pmatrix[$i][$j]\t";
		}
		print "\n";
	}
};

sub pathologyOverlap {
	my $i = shift;
	my $j = shift;
	for(my $c = 0; $c < $sid; $c++)
	{
		return 1 if $pmatrix[$i][$c] != 0 and $pmatrix[$j][$c] != 0;
	}
	return 0;
};

sub findDisjointTrees {
	my $codegenfunc = shift;

	my %pid_pid_deps = ();
	my $np = $#pmatrix;

	# find deps
	for(my $i = 0; $i <= $np; $i++)
	{
		@{ $pid_pid_deps{$i} } = ();
		for(my $j = 0; $j <= $np; $j++) # add both i->j and j->i
		{
			if($i != $j and pathologyOverlap($i, $j))
			{
				push(@{ $pid_pid_deps{$i} }, $j);
				#print "deps $i -> $j\n";
			}
		}
	}

	# construct islands
	my $gr = graph_start();
	for(my $i = 0; $i <= $np; $i++)
	{
		next if !exists $pid_pid_deps{$i};
		my @island = ();
		my @pidqueue = ();
		push(@pidqueue, $i);
		while(@pidqueue)
		{
			my $p = shift(@pidqueue);
			push(@island, $p);
			push(@pidqueue, @{ $pid_pid_deps{$p} })
				if defined $pid_pid_deps{$p};
			delete $pid_pid_deps{$p}; #"color" edge
		}
		@island = uniq(@island);
		print "\nisland @island\n";
		my $rootnode = ConstructTree(\@island);

		# generate code for the island
		&$codegenfunc($rootnode, \%symptom_procs);

		#graph tree
		graph_addisland($rootnode, $gr);
	}
	graph_end($gr, "dtree.png");
=pod
	for(my $i = 0; $i <= $np; $i++)
	{
		next if !exists $pid_pid_deps{$i};
		my @arr = @{ $pid_pid_deps{$i} };
		#print "$i -> @arr\n";
		my $n = @arr;
		for(my $j = 0; $j < $n; $j++)
		{
			my $p = $arr[$j];
			push(@{ $pid_pid_deps{$i} }, @{ $pid_pid_deps{$p} })
				if defined $pid_pid_deps{$p};
			delete $pid_pid_deps{$p};
		}
	}
	print "\nislands:\n";
	foreach my $p (keys %pid_pid_deps)
	{
		my @arr = uniq(@{ $pid_pid_deps{$p} });
		push(@arr, $p);
		print "\nisland @arr\n";
		ConstructTree(\@arr);
	}
=cut
};

sub pruneNodes { # assumes child nodes with same labels have same symptoms
	my $root = shift;
	my $carr = $root->{CHILD};

	return if !defined $carr;

	# merge children based on labels
	my $n = @{$carr};
	my %label_node = ();
	for(my $c = $n-1; $c >= 0; $c--)
	{
		my $child = $carr->[$c];
		my $label = $root->{CHILDLABEL}[$c];
		if(!exists $label_node{$label})
		{
			$label_node{$label} = $child;
		}
		else
		{
			my $tnode = $label_node{$label};
#print "PRUNE-NODE $tnode->{CHILD}\n";
			my @tcarr = @{$child->{CHILD}};
			for(my $c2 = 0; $c2 < scalar(@tcarr); $c2++)
			{
				$tcarr[$c2]->{PARENT}[0] = $tnode;
			}
			push(@{$tnode->{CHILD}}, @{$child->{CHILD}}) if exists $child->{CHILD};
			push(@{$tnode->{CHILDLABEL}}, @{$child->{CHILDLABEL}}) if exists $child->{CHILDLABEL};
			deleteLink($root, $child);
		}
	}

	for(my $c = 0; $c < $n; $c++)
	{
		my $child = $carr->[$c];
		pruneNodes($child);
	}
};

sub pruneNonPathologyNodes {
	my $root = shift;
	my $carr = $root->{CHILD};

	if(!defined $carr) # or @{$carr} == 0)
	{
		if($root->{TYPE} != 2) # non-pathology
		{
			deleteLink($root->{PARENT}[0], $root);
		}
		return;
	}

	my $n = @{$carr};
	if($n == 0 and $root->{TYPE} == 1)
	{
                if($root->{TYPE} != 2) # non-pathology
                {
                        deleteLink($root->{PARENT}[0], $root);
                }
                return;
	}
	for(my $c = $n-1; $c >= 0; $c--)
	{
		my $child = $carr->[$c];
		pruneNonPathologyNodes($child);
	}
};

sub pruneUnusedEdges {
	my $root = shift;
	my $carr = $root->{CHILD};

	return if !defined $carr;
	my $n = @{$carr};
	for(my $c = $n-1; $c >= 0; $c--)
	{
		my $child = $carr->[$c];
		if($root->{CHILDLABEL}[$c] == 0)
		{
			my $tnode = $child;
			my $newlabel = 0;
			while(defined $tnode->{PARENT}[0] and $tnode->{PARENTLABEL} == 0) # same as label of parent -> child
			{
				$tnode = $tnode->{PARENT}[0];
				$newlabel = $tnode->{PARENTLABEL};
			}
			$tnode = $tnode->{PARENT}[0];
			if(defined $tnode)
			{
				deleteLink($root, $child);
				$child->{PARENT} = ();
				addParent($child, $tnode, $newlabel);
			}
		}
		pruneUnusedEdges($child);
	}
};
sub pruneUnusedEdgesUniqueNodeLabels {
	my $ref = shift;
	my $n = @$ref;
	for(my $c = 0; $c < $n; $c++) #leaves
	{
		my $tnode = $ref->[$c];
		my @parentarr = @{ $tnode->{PARENT} };
		while(scalar(@parentarr) != 0)
		{
			my $parent = $tnode->{PARENT}[0];
			my @siblings = @{ $parent->{CHILD} };
			my $modified = 0;
			if($tnode->{PARENTLABEL} == 0 and scalar(@siblings) == 1) #cut edge
			{
				my $grandparent = $parent->{PARENT}[0];
				if(defined $grandparent)
				{
					my $newlabel = $parent->{PARENTLABEL};
					deleteLink($parent, $tnode);
					deleteLink($grandparent, $parent);
					$tnode->{PARENT} = ();
					addParent($tnode, $grandparent, $newlabel);
					$parent = $grandparent;
					@siblings = @{ $parent->{CHILD} };
					$modified = 1;
				}
			}

			if($modified == 0)
			{
				$tnode = $parent;
				last if !defined $tnode->{PARENT}; #reached root
				@parentarr = @{ $tnode->{PARENT} };
			}
		}
	}
};


sub ConstructTree {
	my $ref = shift;
	my @arr = @$ref;
	my $n = @arr;
	my @pathologynodes = ();

	my %attr_n = (); # #pids that use each sid
	for my $j (0 .. $sid)
	{
		for(my $c = 0; $c < $n; $c++)
		{
			my $instance = $arr[$c];
			$attr_n{$j}++ if $pmatrix[$instance][$j] != 0;
		}
	}

	my @sortedattrs = ();
	my $nattrs = 0;
	foreach my $attr (sort {$attr_n{$b} <=> $attr_n{$a}} keys %attr_n)
	{
		push(@sortedattrs, $attr);
		$nattrs++;
		print "$symptom_name{$attr} -> $attr_n{$attr}\n";
	}

	# root
	my $root = newNode($symptom_name{$sortedattrs[0]}, 1);
	my $node;

	# bottom-up tree
	for(my $c = 0; $c < $n; $c++) #each pathology
	{
		my $instance = $arr[$c];
		$node = newNode($pathology_name{$instance}, 2); #pathology
		push(@pathologynodes, $node);
		#print "newnode $pathology_name{$instance}\n";
		for(my $cattr = $nattrs-1; $cattr > 0; $cattr--)
		{
			my $parent = newNode($symptom_name{$sortedattrs[$cattr]}, 1);
			addParent($node, $parent, $pmatrix[$instance][$sortedattrs[$cattr]]);
			$node = $parent;
			#print "addparent $symptom_name{$sortedattrs[$cattr]}\n";
		}
		addParent($node, $root, $pmatrix[$instance][$sortedattrs[0]]);
		#print "addparent $symptom_name{$sortedattrs[0]}\n";
	}

	pruneNodes($root);
	print "\n";

	pruneUnusedEdgesUniqueNodeLabels(\@pathologynodes);
	#pruneUnusedEdges($root);
	#pruneNonPathologyNodes($root);
#	traverseTree($root);
	#graph($root, "dtree.png");
#	storePaths(\@pathologynodes, "/tmp/cP-$r.txt");

	return $root;
};


generateMatrix();
printMatrix();

codegenHeader();
findDisjointTrees(\&codegenIsland);
codegenTrailer();


=pod
use DecisionTree2;

sub ConstructTree2 {
	my $ref = shift;
	my @arr = @$ref;
	my $n = @arr;

	### http://search.cpan.org/dist/AI-DecisionTree/lib/AI/DecisionTree.pm
	my $dtree = new DecisionTree2(prune => 0);
	for(my $c = 0; $c < $n; $c++)
	{
		my %attribs = ();
		for my $j (0 .. $sid)
		{
			next if $pmatrix[ $arr[$c] ][$j] == 0;
			$attribs{$symptom_name{$j}} = $pmatrix[ $arr[$c] ][$j];
			print "attribs $symptom_name{$j} => $pmatrix[$arr[$c]][$j] ";
		}
		print " result => $pathology_name{$arr[$c]}\n";
		$dtree->add_instance(attributes => \%attribs, result => $pathology_name{$arr[$c]});
	}
	$dtree->train();
	print "done construction\n";
	my @statements = $dtree->rule_statements(); foreach (@statements) {print "$_\n";}

};
=cut


