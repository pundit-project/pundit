#!perl -w

use strict;

sub uniq {
	return keys %{{ map { $_ => 1 } @_ }};
};

sub newNode {
	my $name = shift;
	my $type = shift;

	my $node = {};
	$node->{VAL} = $name;
	$node->{TYPE} = $type; # symptom
	$node->{CHILD} = ();
	$node->{CHILDLABEL} = ();
	$node->{PARENTLABEL} = -1;
	$node->{PARENT} = ();
	#push(@{$root->{CHILD}}, $pmatrix[$instance][$attr]);

	return $node;
};

sub addParent {
	my $node = shift;
	my $parent = shift;
	my $label = shift;

	push(@{$node->{PARENT}}, $parent);
	push(@{$parent->{CHILD}}, $node);
	push(@{$parent->{CHILDLABEL}}, $label);
	$node->{PARENTLABEL} = $label;
};

sub deleteLink {
	my $root = shift;
	my $child = shift;
	my $carr = $root->{CHILD};
	my $clarr = $root->{CHILDLABEL};
	my $n = @{$carr};
	#print "DELETE from n $n child $child\n";
	for(my $c = $n-1; $c >= 0; $c--)
	{
		#print "DELETE element  $carr->[$c]\n";
		#print "DELETE $root->{VAL} -> $carr->[$c]->{VAL} element $carr->[$c]\n" if $carr->[$c] == $child;
		if($carr->[$c] == $child)
		{
			splice(@{$carr}, $c, 1);
			splice(@{$clarr}, $c, 1);
		}
	}
};

sub traverseTree {
	my $root = shift;
	my $carr = $root->{CHILD};

	return if !defined $carr;
	my $n = @{$carr};
	for(my $c = 0; $c < $n; $c++)
	{
		my $child = $carr->[$c];
		print "$root->{VAL} -> $child->{VAL} label:$root->{CHILDLABEL}[$c]\n";
		traverseTree($child);
	}
};


use GraphViz;
sub graph_start {
	my $g = GraphViz->new();
	return $g;
};
sub graph_addisland {
	my $root = shift;
	my $g = shift;
	traverseTreeViz($root, $g);
};
sub graph_end {
	my $g = shift;
	my $file = shift;
	$g->as_png($file);
	undef $g;
};
sub graph {
	my $root = shift;
	my $file = shift;

	my $g = GraphViz->new();
	traverseTreeViz($root, $g);
	$g->as_png($file);
};
sub traverseTreeViz {
	my $root = shift;
	my $g = shift;
	my $carr = $root->{CHILD};

	return if !defined $carr;
	my $n = @{$carr};
	for(my $c = 0; $c < $n; $c++)
	{
		my $child = $carr->[$c];
		$g->add_node("$child->{VAL}-$child", label => $child->{VAL}, style => 'filled', fillcolor => 'yellow') if $child->{TYPE} == 2;
		$g->add_node("$root->{VAL}-$root", label => $root->{VAL}) if $root->{TYPE} == 1;
		$g->add_node("$child->{VAL}-$child", label => $child->{VAL}) if $child->{TYPE} == 1;
		$g->add_edge("$root->{VAL}-$root" => "$child->{VAL}-$child", label => $root->{CHILDLABEL}[$c]);
		traverseTreeViz($child, $g);
	}
};
sub storePaths {
	my $ref = shift;
	my $file = shift;
	open(FILE, ">$file") or die;
	my $n = @$ref;
	for(my $c = 0; $c < $n; $c++)
	{
		my $tnode = $ref->[$c];
		my @parentarr = @{ $tnode->{PARENT} };
		while(@parentarr != 0)
		{
			print FILE "$tnode->{VAL} $tnode->{PARENTLABEL} ";
			$tnode = $tnode->{PARENT}[0];
			last if !defined $tnode->{PARENT};
			@parentarr = @{ $tnode->{PARENT} };
		}
		print FILE "$tnode->{VAL}\n";
	}
	close FILE;
};


1;

