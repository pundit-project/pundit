#!/usr/bin/perl

use strict;
require "tr_receiver.pl";
use Data::Dumper;

# Creates a list of edges
sub dbg_create_loc_lists
{
	my ($in_tr_list) = @_;
	
	my %node_list = ();
	my %edge_list = ();
	my @path_list = ();
	my $node_count = 0;
	
	foreach my $entry (@$in_tr_list)
	{
		my $tr_list = $entry->{'tr_list'};
		my $src_str = $entry->{'src'};
		
		# Do mapping to src_id
		if (!exists($node_list{$src_str}))
		{
			$node_list{$src_str} = $node_count++;
		}
		my $src_id = $node_list{$src_str};
		
		if (!exists($edge_list{$src_id}))
		{
			$edge_list{$src_id} = {};
		}
		
		foreach my $tr_entry (@$tr_list)
		{
			my $i;
			my $path = $tr_entry->{'path'};
			
			my $count = scalar(@$path);
			
			my $dst_str = $$path[$count - 1];
			if (!exists($node_list{$dst_str}))
			{
				$node_list{$dst_str} = $node_count++;
			}
			my $dst_id = $node_list{$dst_str};
			
			for ($i = 0; $i < $count; $i++)
			{
				my $node_str = $$path[$i];
				if (!exists($node_list{$node_str}))
				{
					$node_list{$node_str} = $node_count++;
				}
				my $node_id = $node_list{$node_str};
				
				# Build edge list
				if ($i < ($count - 1))
				{
					my $node2_str = $$path[$i+1];
					if (!exists($node_list{$node2_str}))
					{
						$node_list{$node2_str} = $node_count++;
					}
					my $node2_id = $node_list{$node2_str};
					
					if (!exists($edge_list{$node_id}))
					{
						$edge_list{$node_id} = {};
					}
					
					$edge_list{$node_id}->{$node2_id} += 1;
				}	
				
				# insert into path list
				my %node_entry = (
					'node' => $node_id,
					'src' => $src_id,
					'dst' => $dst_id,
				);
				push (@path_list, \%node_entry);
			}
			
			# Add edge for first hop
			if ($src_str ne $$path[0])
			{
				my $node_str = $$path[0];
				if (!exists($node_list{$node_str}))
				{
					$node_list{$node_str} = $node_count++;
				}
				my $node_id = $node_list{$node_str};
				
				$edge_list{$src_id}->{$node_id} += 1;
			}
		}
	}
	
	return \%node_list, \%edge_list, \@path_list;
}

sub dbg_print_node_list
{
	my ($node_list) = @_;
	
	foreach my $src (keys(%$node_list))
	{
		my $value = $node_list->{$src};
		print "('$src', $value), \n";
		
	}
}


sub dbg_print_edge_list
{
	my ($edge_list) = @_;
	
	foreach my $src (keys(%$edge_list))
	{
		foreach my $dst (keys(%{$edge_list->{$src}}))
		{
			print "($src, $dst), \n";
		}
	}
}

sub dbg_print_path_list
{
	my ($path_list) = @_;
	
	foreach my $entry (@$path_list)
	{
		my $node = $entry->{'node'};
		my $src = $entry->{'src'};
		my $dst = $entry->{'dst'};
		print "($node, $src, $dst), \n";
	}
}

sub dbg_print_path_list2
{
	my ($in_tr_list) = @_;
	
	print "\$array = array(\n";
	
	foreach my $entry (@$in_tr_list)
	{
		my $tr_list = $entry->{'tr_list'};
		my $src_str = $entry->{'src'};
		
		print "\t\"$src_str\" => array (\n";
				
		foreach my $tr_entry (@$tr_list)
		{
			my $i;
			my $path = $tr_entry->{'path'};
			
			my $count = scalar(@$path);
			
			my $dst_str = $$path[$count - 1];
			
			next if ($dst_str eq $src_str);
			
			print "\t\t\"$dst_str\" => array (";
			
			for ($i = 0; $i < $count; $i++)
			{
				my $node_str = $$path[$i];
				
				print "\"$node_str\", ";
				
			}
			print "), \n";
		}
		print "\t), \n";
	}
	print ")\n";
}

#my ($node_list, $edge_list, $path_list) = dbg_create_loc_lists(get_tr_list());
#my $node_list = build_node_idx(get_tr_list());
#dbg_print_node_list($node_list);
#dbg_print_edge_list($edge_list);
#dbg_print_path_list($path_list);

dbg_print_path_list2(get_tr_list());