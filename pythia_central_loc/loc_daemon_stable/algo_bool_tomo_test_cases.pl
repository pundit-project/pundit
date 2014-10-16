#!/usr/bin/perl
use 5.012;
use warnings;

use Data::Dumper;
#use Clone qw(clone);

require "algo_bool_tomo.pl";
require "tr_receiver.pl";
require "ev_receiver.pl";

my @tr_list;
my @event_table;

# Y shaped topology
# Endpoints are A1 B1 C1
sub build_y_topology
{
	return (
		{
			'src' => 'A1',
			'tr_list' => 
				[
					['A1',],
					['D.A', 'B1',],
					['D.A', 'C1',],
				],
		},
		{
			'src' => 'B1',
			'tr_list' => 
				[
					['D.B','A1',],
					['B1',],
					['D.B', 'C1',],
				],
		},
		{
			'src' => 'C1',
			'tr_list' => 
				[
					['D.C','A1',],
					['D.C','B1',],
					['C1',],
				],
		},
	);
}

# Bottleneck topology
# Endpoints are A1 B1 C1 D1
sub build_bottleneck_topology
{
	return (
		{
			'src' => 'A1',
			'tr_list' => 
				[
					['A1',],
					['E.A', 'F.E', 'B1',],
					['E.A', 'C1'],
					['E.A', 'F.E', 'D1',],
				],
		},
		{
			'src' => 'B1',
			'tr_list' => 
				[ 
					['F.B', 'E.F', 'A1'],
					['B1',],
					['F.B', 'E.F', 'C1',],
					['F.B', 'D1',],
				],
		},
		{
			'src' => 'C1',
			'tr_list' => 
				[ 
					['E.C', 'A1'],
					['E.C', 'F.E', 'B1',],
					['C1',],
					['E.C', 'F.E', 'D1',],
				],
		},
		{
			'src' => 'D1',
			'tr_list' => 
				[ 
					['F.D', 'E.F', 'A1',],
					['F.D', 'B1',],
					['F.D', 'E.F', 'C1',],
					['D1',],
				],
		},
	);
}

# YY topology
# Y with additional nodes from each edge
# Endpoints are A1, B1, C1, D1, E1, F1
sub build_yy_topology
{
		return (
		{
			'src' => 'A1',
			'tr_list' => 
				[
					['A1',],
					['G.A', 'B1',],
					['G.A', 'J.G', 'H.J', 'C1'],
					['G.A', 'J.G', 'H.J', 'D1'],
					['G.A', 'J.G', 'I.J', 'E1'],
					['G.A', 'J.G', 'I.J', 'F1'],
				],
		},
		{
			'src' => 'B1',
			'tr_list' => 
				[ 
					['G.B', 'A1',],
					['B1',],
					['G.B', 'J.G', 'H.J', 'C1'],
					['G.B', 'J.G', 'H.J', 'D1'],
					['G.B', 'J.G', 'I.J', 'E1'],
					['G.B', 'J.G', 'I.J', 'F1'],
				],
		},
		{
			'src' => 'C1',
			'tr_list' => 
				[ 
					['H.C', 'J.H', 'G.J', 'A1'],
					['H.C', 'J.H', 'G.J', 'B1'],
					['C1',],
					['H.C', 'D1',],
					['H.C', 'J.H', 'I.J', 'E1'],
					['H.C', 'J.H', 'I.J', 'F1'],
				],
		},
		{
			'src' => 'D1',
			'tr_list' => 
				[ 
					['H.D', 'J.H', 'G.J', 'A1'],
					['H.D', 'J.H', 'G.J', 'B1'],
					['H.D', 'C1',],
					['D1',],
					['H.D', 'J.H', 'I.J', 'E1'],
					['H.D', 'J.H', 'I.J', 'F1'],
				],
		},
		{
			'src' => 'E1',
			'tr_list' => 
				[ 
					['I.E', 'J.I', 'G.J', 'A1'],
					['I.E', 'J.I', 'G.J', 'B1'],
					['I.E', 'J.I', 'H.J', 'C1'],
					['I.E', 'J.I', 'H.J', 'D1'],
					['E1',],
					['I.E', 'F1',],
				],
		},
		{
			'src' => 'F1',
			'tr_list' => 
				[ 
					['I.F', 'J.I', 'G.J', 'A1'],
					['I.F', 'J.I', 'G.J', 'B1'],
					['I.F', 'J.I', 'H.J', 'C1'],
					['I.F', 'J.I', 'H.J', 'D1'],
					['I.F', 'E1',],
					['F1',],
				],
		},
	);
}

# Test case 0
# The one described in the paper
run_test_case_0() if (0);
sub run_test_case_0
{
	@event_table = (
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 3, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 4, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "D1", 'metric' => 2, 'processed' => 0,},
		);
	# l1 = A1 to B1, L2 = B1 to C1, L3 = C1 to D1
	my %tr_matrix = 
		(
			'A1' => {
	        	'B1' => ['B1'],
				'C1' => ['B1', 'C1',],
			},
			'B1' => {
				'D1' => ['C1', 'D1',],
			}
        );
	my %tr_node_list = 
		(
			'A1' => [ ],
			'B1' => [
	                     ['A1', 'B1'],
	                     ['A1', 'C1'],
                   ],
          	'C1' => [
	                     ['A1', 'C1'],
	                     ['B1', 'D1']
                   ],
          	'D1' => [
	                    ['B1', 'D1'],
                  ],
             );
	print Dumper bool_tomo(\@event_table, \%tr_matrix, \%tr_node_list);
}

# Test case 1.1
# Y shaped topology with 1 bad link 
# 2 paths affected - same origin
# bad links are alpha similar
run_test_case_1_1() if (0);
sub run_test_case_1_1
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# D.A = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 55, 'processed' => 0,},
		);
	
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 1.2
# Y shaped topology with 1 bad link at endpoint
# 2 paths affected - diff origin
# bad links are alpha similar
run_test_case_1_2() if (0);
sub run_test_case_1_2
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# B1 = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 55, 'processed' => 0,},
		);
	
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 1.3
# Y shaped topology with 2 bad links at diff endpoints
# 4 paths affected - diff origin
# bad links are alpha similar
run_test_case_1_3() if (0);
sub run_test_case_1_3
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# B1 = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 55, 'processed' => 0,},
			# C1 = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 55, 'processed' => 0,},
		);
	
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 1.4
# Y shaped topology with 2 bad links
# Union of test cases 1.1 and 1.2
# Bad links are not alpha similar
run_test_case_1_4() if (0);
sub run_test_case_1_4
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# D.A = 40, B1 = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			# D.A = 40
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 40, 'processed' => 0,},
			# B1 = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 1.5
# Y shaped topology with 3 bad links: 2 are at endpoint, 1 at ingress to middle node
# Bad links are not alpha-similar
run_test_case_1_5() if (0);
sub run_test_case_1_5
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# D.A = 40, B1 = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			# D.A = 40, C1 = 15
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 55, 'processed' => 0,},
			# C1 = 15
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 15, 'processed' => 0,},
			# B1 = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 1.6
# Y shaped topology with 3 bad links: 2 are at endpoint, 1 at ingress to middle node
# All bad links are alpha-similar
run_test_case_1_6() if (0);
sub run_test_case_1_6
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# D.A = 10, B1 = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 20, 'processed' => 0,},
			# D.A = 10, C1 = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 20, 'processed' => 0,},
			# C1 = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 10, 'processed' => 0,},
			# B1 = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 1.7
# Y shaped topology with 2 bad links: 2 at ingress to middle node
# All bad links are alpha-similar
run_test_case_1_7() if (0);
sub run_test_case_1_7
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# D.A = 20
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 20, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 20, 'processed' => 0,},
			# D.B = 20
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "A1", 'metric' => 20, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 20, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 1.8
# Y shaped topology with 3 bad links: 3 at ingress to middle node
# All bad links are alpha-similar
# This doesn't work. Fails because the algo picks the wrong node due to too many candidate links and insufficient good paths
run_test_case_1_8() if (0);
sub run_test_case_1_8
{
	# Y topology
	@tr_list = build_y_topology();
	@event_table = (
			# D.A = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 10, 'processed' => 0,},
			# D.B = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "A1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 10, 'processed' => 0,},
			# D.C = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "A1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 2.1
# Bottleneck link with a faulty link manifesting in delays on both sides
run_test_case_2_1() if (0);
sub run_test_case_2_1
{
	# Bottleneck link
	@tr_list = build_bottleneck_topology();
	@event_table = (
			# F.E = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			# E.F = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "B1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 2.2
# Bottleneck link with a faulty link manifesting in delays on both sides, plus one faulty link on E.A
run_test_case_2_2() if (0);
sub run_test_case_2_2
{
	# Bottleneck link
	@tr_list = build_bottleneck_topology();
	@event_table = (
			# E.A = 20, F.E = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 70, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "D1", 'metric' => 70, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 20, 'processed' => 0,},
			# F.E = 50
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			# E.F = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "B1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 2.3
# Bottleneck link with a faulty link manifesting in delays on both sides, plus one faulty link on C1
# Doesn't work because algo picks the wrong link for the path A1 to C1 due to lack of alpha-similar paths
run_test_case_2_3() if (0);
sub run_test_case_2_3
{
	# Bottleneck link
	@tr_list = build_bottleneck_topology();
	@event_table = (
			# C1 = 20, F.E = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			# C1 = 20
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 20, 'processed' => 0,},
			# F.E = 50
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			# E.F = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "B1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			# C1 = 20, F.E = 50
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 70, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "C1", 'metric' => 70, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 2.4
# Single path consisting of 3 faulty links from A1 to B1: E.A, F.E, B1 are faulty
run_test_case_2_4() if (0);
sub run_test_case_2_4
{
	# Bottleneck link
	@tr_list = build_bottleneck_topology();
	@event_table = (
			# E.A = 10, F.E = 10, B1 = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 30, 'processed' => 0,},
			# E.A = 10, F.E = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "D1", 'metric' => 20, 'processed' => 0,},
			# E.A = 10
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 10, 'processed' => 0,},
			# F.E = 10, B1 = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "B1", 'metric' => 20, 'processed' => 0,},
			# F.E = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "D1", 'metric' => 10, 'processed' => 0,},
			# B1 = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "D1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 2.5
# Single path consisting of all faulty links coming into E: E.A, E.F, E.C are faulty
# Doesn't work because algo picks the link with the max no of unj paths 
run_test_case_2_5() if (0);
sub run_test_case_2_5
{
	# Bottleneck link
	@tr_list = build_bottleneck_topology();
	@event_table = (
			# E.A = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "D1", 'metric' => 10, 'processed' => 0,},
			# E.F = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "B1", 'dst' => "A1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "B1", 'dst' => "C1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "D1", 'dst' => "A1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "D1", 'dst' => "C1", 'metric' => 10, 'processed' => 0,},			
			# E.C = 10
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "A1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "B1", 'metric' => 10, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "D1", 'metric' => 10, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 3.1
# YY topology with faulty egress links around node J
# This is the continuation of test case 1.4
# All bad links are alpha similar
run_test_case_3_1() if (0);
sub run_test_case_3_1
{
	# Bottleneck link
	@tr_list = build_yy_topology();
	@event_table = (
			# link I.J = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "B1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "D1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			# link H.J = 50
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "E1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "E1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "F1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "F1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			# link G.J = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "E1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "E1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "F1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "F1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}

# Test case 3.2
# YY topology with faulty ingress links around node J
# This is the continuation of test case 1.9
# All bad links are alpha similar
run_test_case_3_2() if (0);
sub run_test_case_3_2
{
	# Bottleneck link
	@tr_list = build_yy_topology();
	@event_table = (
			# link J.H = 50
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "C1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "C1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},			
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "A1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "B1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "D1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "D1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},

			# link J.G = 50
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "A1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "A1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "C1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "D1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 12, 'end' => time - 3, 'src' => "B1", 'dst' => "E1", 'metric' => 50, 'processed' => 0,},
			{ 'start' => time - 10, 'end' => time - 1, 'src' => "B1", 'dst' => "F1", 'metric' => 50, 'processed' => 0,},

		);
	my ($tr_matrix, $tr_node_list) = process_tr_all(\@tr_list);
	print Dumper bool_tomo(\@event_table, $tr_matrix, $tr_node_list);
}