#!/usr/bin/perl
#
# Copyright 2016 Georgia Institute of Technology
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

use 5.012;
use warnings;

use Data::Dumper;
use Config::General;

use FindBin qw( $RealBin );

use lib "$RealBin/../lib";

use PuNDIT::Central::Localization::Tomography;
use PuNDIT::Central::Localization::Tomography::RangeSum;
use PuNDIT::Utils::TrHop;

=pod
TomographyRangeSumTest.pl

Test cases for Range Tomography (Sum Tomography)
=cut

my $trMatrix;
my @event_table;

my $configFile = "$RealBin/../etc/pundit_central.conf";
my %cfgHash = Config::General::ParseConfig($configFile);
my $rt = new PuNDIT::Central::Localization::Tomography::RangeSum(\%cfgHash, "federation1");

# Y shaped topology
# Endpoints are A1 B1 C1
sub build_y_topology
{
    my $a1 = new PuNDIT::Utils::TrHop('A1','A1');
    my $b1 = new PuNDIT::Utils::TrHop('B1','B1');
    my $c1 = new PuNDIT::Utils::TrHop('C1','C1');
    my $da = new PuNDIT::Utils::TrHop('D.A','D.A');
    my $db = new PuNDIT::Utils::TrHop('D.B','D.B');
    my $dc = new PuNDIT::Utils::TrHop('D.C','D.C');
    return {
        'A1' => {
                    'A1' => { 'src' => 'A1', 'dst' => 'A1', 'path' => [$a1,]},
                    'B1' => { 'src' => 'A1', 'dst' => 'B1', 'path' => [$da, $b1,]},
                    'C1' => { 'src' => 'A1', 'dst' => 'C1', 'path' => [$da, $c1,]},
        },
        'B1' => {
                    'A1' => { 'src' => 'B1', 'dst' => 'A1', 'path' => [$db,$a1,]},
                    'B1' => { 'src' => 'B1', 'dst' => 'B1', 'path' => [$b1,]},
                    'C1' => { 'src' => 'B1', 'dst' => 'C1', 'path' => [$db, $c1,]},
        },
        'C1' => {
                    'A1' => { 'src' => 'C1', 'dst' => 'A1', 'path' => [$dc, $a1,]},
                    'B1' => { 'src' => 'C1', 'dst' => 'B1', 'path' => [$dc, $b1,]},
                    'C1' => { 'src' => 'C1', 'dst' => 'C1', 'path' => [$c1,]},
        },
    };
}

# Bottleneck topology
# Endpoints are A1 B1 C1 D1
sub build_bottleneck_topology
{
    my $a1 = new PuNDIT::Utils::TrHop('A1','A1');
    my $b1 = new PuNDIT::Utils::TrHop('B1','B1');
    my $c1 = new PuNDIT::Utils::TrHop('C1','C1');
    my $d1 = new PuNDIT::Utils::TrHop('D1','D1');
    
    my $ea = new PuNDIT::Utils::TrHop('E.A','E.A');
    my $ec = new PuNDIT::Utils::TrHop('E.C','E.C');
    my $ef = new PuNDIT::Utils::TrHop('E.F','E.F');
    
    my $fb = new PuNDIT::Utils::TrHop('F.B','F.B');
    my $fd = new PuNDIT::Utils::TrHop('F.D','F.D');
    my $fe = new PuNDIT::Utils::TrHop('F.E','F.E');
    return {
        'A1' => {
                    'A1' => { 'src' => 'A1', 'dst' => 'A1', 'path' => [$a1,]},
                    'B1' => { 'src' => 'A1', 'dst' => 'B1', 'path' => [$ea, $fe, $b1,]},
                    'C1' => { 'src' => 'A1', 'dst' => 'C1', 'path' => [$ea, $c1]},
                    'D1' => { 'src' => 'A1', 'dst' => 'D1', 'path' => [$ea, $fe, $d1,]},
        },
        'B1' => {
                    'A1' => { 'src' => 'B1', 'dst' => 'A1', 'path' => [$fb, $ef, $a1,]},
                    'B1' => { 'src' => 'B1', 'dst' => 'B1', 'path' => [$b1,]},
                    'C1' => { 'src' => 'B1', 'dst' => 'C1', 'path' => [$fb, $ef, $c1,]},
                    'D1' => { 'src' => 'B1', 'dst' => 'D1', 'path' => [$fb, $d1,]},
        },
        'C1' => {
                    'A1' => { 'src' => 'C1', 'dst' => 'A1', 'path' => [$ec, $a1,]},
                    'B1' => { 'src' => 'C1', 'dst' => 'B1', 'path' => [$ec, $fe, $b1,]},
                    'C1' => { 'src' => 'C1', 'dst' => 'C1', 'path' => [$c1,]},
                    'D1' => { 'src' => 'C1', 'dst' => 'D1', 'path' => [$ec, $fe, $d1,]},
        },
        'D1' => {
                    'A1' => { 'src' => 'D1', 'dst' => 'A1', 'path' => [$fd, $ef, $a1,]},
                    'B1' => { 'src' => 'D1', 'dst' => 'B1', 'path' => [$fd, $b1,]},
                    'C1' => { 'src' => 'D1', 'dst' => 'C1', 'path' => [$fd, $ef, $c1,]},
                    'D1' => { 'src' => 'D1', 'dst' => 'D1', 'path' => [$d1,]},
        },
    };
}

# YY topology
# Y with additional nodes from each edge
# Endpoints are A1, B1, C1, D1, E1, F1
sub build_yy_topology
{
    my $a1 = new PuNDIT::Utils::TrHop('A1','A1');
    my $b1 = new PuNDIT::Utils::TrHop('B1','B1');
    my $c1 = new PuNDIT::Utils::TrHop('C1','C1');
    my $d1 = new PuNDIT::Utils::TrHop('D1','D1');
    my $e1 = new PuNDIT::Utils::TrHop('E1','E1');
    my $f1 = new PuNDIT::Utils::TrHop('F1','F1');
    
    my $ga = new PuNDIT::Utils::TrHop('G.A','G.A');
    my $gb = new PuNDIT::Utils::TrHop('G.B','G.B');
    my $gj = new PuNDIT::Utils::TrHop('G.J','G.J');
    
    my $hc = new PuNDIT::Utils::TrHop('H.C','H.C');
    my $hd = new PuNDIT::Utils::TrHop('H.D','H.D');
    my $hj = new PuNDIT::Utils::TrHop('H.J','H.J');
    
    my $ie = new PuNDIT::Utils::TrHop('I.E','I.E');
    my $if = new PuNDIT::Utils::TrHop('I.F','I.F');
    my $ij = new PuNDIT::Utils::TrHop('I.J','I.J');
    
    my $jg = new PuNDIT::Utils::TrHop('J.G','J.G');
    my $jh = new PuNDIT::Utils::TrHop('J.H','J.H');
    my $ji = new PuNDIT::Utils::TrHop('J.I','J.I');
    return {
        'A1' => {
                    'A1' => { 'src' => 'A1', 'dst' => 'A1', 'path' => [$a1,]},
                    'B1' => { 'src' => 'A1', 'dst' => 'B1', 'path' => [$ga, $b1,]},
                    'C1' => { 'src' => 'A1', 'dst' => 'C1', 'path' => [$ga, $jg, $hj, $c1]},
                    'D1' => { 'src' => 'A1', 'dst' => 'D1', 'path' => [$ga, $jg, $hj, $d1]},
                    'E1' => { 'src' => 'A1', 'dst' => 'E1', 'path' => [$ga, $jg, $ij, $e1]},
                    'F1' => { 'src' => 'A1', 'dst' => 'F1', 'path' => [$ga, $jg, $ij, $f1]},
        },
        'B1' => {
                    'A1' => { 'src' => 'B1', 'dst' => 'A1', 'path' => [$gb, $a1,]},
                    'B1' => { 'src' => 'B1', 'dst' => 'B1', 'path' => [$b1,]},
                    'C1' => { 'src' => 'B1', 'dst' => 'C1', 'path' => [$gb, $jg, $hj, $c1]},
                    'D1' => { 'src' => 'B1', 'dst' => 'D1', 'path' => [$gb, $jg, $hj, $d1]},
                    'E1' => { 'src' => 'B1', 'dst' => 'E1', 'path' => [$gb, $jg, $ij, $e1]},
                    'F1' => { 'src' => 'B1', 'dst' => 'F1', 'path' => [$gb, $jg, $ij, $f1]},
        },
        'C1' => {
                    'A1' => { 'src' => 'C1', 'dst' => 'A1', 'path' => [$hc, $jh, $gj, $a1]},
                    'B1' => { 'src' => 'C1', 'dst' => 'B1', 'path' => [$hc, $jh, $gj, $b1]},
                    'C1' => { 'src' => 'C1', 'dst' => 'C1', 'path' => [$c1,]},
                    'D1' => { 'src' => 'C1', 'dst' => 'D1', 'path' => [$hc, $d1,]},
                    'E1' => { 'src' => 'C1', 'dst' => 'E1', 'path' => [$hc, $jh, $ij, $e1]},
                    'F1' => { 'src' => 'C1', 'dst' => 'F1', 'path' => [$hc, $jh, $ij, $f1]},
        },
        'D1' => { 
                    'A1' => { 'src' => 'D1', 'dst' => 'A1', 'path' => [$hd, $jh, $gj, $a1]},
                    'B1' => { 'src' => 'D1', 'dst' => 'B1', 'path' => [$hd, $jh, $gj, $b1]},
                    'C1' => { 'src' => 'D1', 'dst' => 'C1', 'path' => [$hd, $c1,]},
                    'D1' => { 'src' => 'D1', 'dst' => 'D1', 'path' => [$d1,]},
                    'E1' => { 'src' => 'D1', 'dst' => 'E1', 'path' => [$hd, $jh, $ij, $e1]},
                    'F1' => { 'src' => 'D1', 'dst' => 'F1', 'path' => [$hd, $jh, $ij, $f1]},
        },
        'E1' => {
                    'A1' => { 'src' => 'E1', 'dst' => 'A1', 'path' => [$ie, $ji, $gj, $a1]},
                    'B1' => { 'src' => 'E1', 'dst' => 'B1', 'path' => [$ie, $ji, $gj, $b1]},
                    'C1' => { 'src' => 'E1', 'dst' => 'C1', 'path' => [$ie, $ji, $hj, $c1]},
                    'D1' => { 'src' => 'E1', 'dst' => 'D1', 'path' => [$ie, $ji, $hj, $d1]},
                    'E1' => { 'src' => 'E1', 'dst' => 'E1', 'path' => [$e1,]},
                    'F1' => { 'src' => 'E1', 'dst' => 'F1', 'path' => [$ie, $f1,]},
        },
        'F1' => {
                    'A1' => { 'src' => 'F1', 'dst' => 'A1', 'path' => [$if, $ji, $gj, $a1]},
                    'B1' => { 'src' => 'F1', 'dst' => 'B1', 'path' => [$if, $ji, $gj, $b1]},
                    'C1' => { 'src' => 'F1', 'dst' => 'C1', 'path' => [$if, $ji, $hj, $c1]},
                    'D1' => { 'src' => 'F1', 'dst' => 'D1', 'path' => [$if, $ji, $hj, $d1]},
                    'E1' => { 'src' => 'F1', 'dst' => 'E1', 'path' => [$if, $e1,]},
                    'F1' => { 'src' => 'F1', 'dst' => 'F1', 'path' => [$f1,]},
        },
    };
}

# Test case 0
# The one described in the paper
sub run_test_case_0
{
    @event_table = (
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 3, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 4, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "D1", 'metric' => 2, 'processed' => 0,},
        );
    # l1 = A1 to B1, L2 = B1 to C1, L3 = C1 to D1
    my $a1 = new PuNDIT::Utils::TrHop('A1','A1');
    my $b1 = new PuNDIT::Utils::TrHop('B1','B1');
    my $c1 = new PuNDIT::Utils::TrHop('C1','C1');
    my $d1 = new PuNDIT::Utils::TrHop('D1','D1');
    $trMatrix = 
        {
            'A1' => {
                'B1' => { 'src' => 'A1', 'dst' => 'B1', 'path' => [$b1]},
                'C1' => { 'src' => 'A1', 'dst' => 'C1', 'path' => [$b1, $c1,]},
            },
            'B1' => {
                'D1' => { 'src' => 'B1', 'dst' => 'D1', 'path' => [$c1, $d1,]},
            }
        };
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

sub run_test_case_1
{
    run_test_case_1_1();
    run_test_case_1_2();
    run_test_case_1_3();
    run_test_case_1_4();
    run_test_case_1_5();
    run_test_case_1_6();
    run_test_case_1_7();
    run_test_case_1_8();
}

# Test case 1.1
# Y shaped topology with 1 bad link 
# 2 paths affected - same origin
# bad links are alpha similar
sub run_test_case_1_1
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # D.A = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 55, 'processed' => 0,},
        );
    
#    my (undef,undef,$tr_matrix, $tr_node_list) = process_tr_all(\$trMatrix);
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.1\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 1.2
# Y shaped topology with 1 bad link at endpoint
# 2 paths affected - diff origin
# bad links are alpha similar
sub run_test_case_1_2
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # B1 = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 55, 'processed' => 0,},
        );
    
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.2\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 1.3
# Y shaped topology with 2 bad links at diff endpoints
# 4 paths affected - diff origin
# bad links are alpha similar
sub run_test_case_1_3
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # B1 = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 55, 'processed' => 0,},
            # C1 = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 55, 'processed' => 0,},
        );
    
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.3\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 1.4
# Y shaped topology with 2 bad links
# Union of test cases 1.1 and 1.2
# Bad links are not alpha similar
sub run_test_case_1_4
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # D.A = 40, B1 = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            # D.A = 40
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 40, 'processed' => 0,},
            # B1 = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.4\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 1.5
# Y shaped topology with 3 bad links: 2 are at endpoint, 1 at ingress to middle node
# Bad links are not alpha-similar
sub run_test_case_1_5
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # D.A = 40, B1 = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            # D.A = 40, C1 = 15
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 55, 'processed' => 0,},
            # C1 = 15
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 15, 'processed' => 0,},
            # B1 = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.5\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 1.6
# Y shaped topology with 3 bad links: 2 are at endpoint, 1 at ingress to middle node
# All bad links are alpha-similar
sub run_test_case_1_6
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # D.A = 10, B1 = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 20, 'processed' => 0,},
            # D.A = 10, C1 = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 20, 'processed' => 0,},
            # C1 = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 10, 'processed' => 0,},
            # B1 = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.6\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 1.7
# Y shaped topology with 2 bad links: 2 at ingress to middle node
# All bad links are alpha-similar
sub run_test_case_1_7
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # D.A = 20
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 20, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 20, 'processed' => 0,},
            # D.B = 20
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "A1", 'metric' => 20, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 20, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.7\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 1.8
# Y shaped topology with 3 bad links: 3 at ingress to middle node
# All bad links are alpha-similar
# This doesn't work. Fails because the algo picks the wrong node due to too many candidate links and insufficient good paths
sub run_test_case_1_8
{
    # Y topology
    $trMatrix = build_y_topology();
    @event_table = (
            # D.A = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 10, 'processed' => 0,},
            # D.B = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "A1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 10, 'processed' => 0,},
            # D.C = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "A1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 1.8\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}


sub run_test_case_2
{
    run_test_case_2_1();
    run_test_case_2_2();
    run_test_case_2_3();
    run_test_case_2_4();
    run_test_case_2_5();
}

# Test case 2.1
# Bottleneck link with a faulty link manifesting in delays on both sides
sub run_test_case_2_1
{
    # Bottleneck link
    $trMatrix = build_bottleneck_topology();
    @event_table = (
            # F.E = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            # E.F = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "B1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 2.1\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 2.2
# Bottleneck link with a faulty link manifesting in delays on both sides, plus one faulty link on E.A
sub run_test_case_2_2
{
    # Bottleneck link
    $trMatrix = build_bottleneck_topology();
    @event_table = (
            # E.A = 20, F.E = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 70, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "D1", 'metric' => 70, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 20, 'processed' => 0,},
            # F.E = 50
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            # E.A = 20
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "A1", 'metric' => 20, 'processed' => 0,},
            # E.F = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "B1", 'dsthost' => "A1", 'metric' => 70, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "A1", 'metric' => 70, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 2.2\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 2.3
# Bottleneck link with a faulty link manifesting in delays on both sides, plus one faulty link on C1
# Doesn't work because algo picks the wrong link for the path A1 to C1 due to lack of alpha-similar paths
sub run_test_case_2_3
{
    # Bottleneck link
    $trMatrix = build_bottleneck_topology();
    @event_table = (
            # C1 = 20, F.E = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            # C1 = 20
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 20, 'processed' => 0,},
            # F.E = 50
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            # E.F = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "B1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            # C1 = 20, F.E = 50
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 70, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "C1", 'metric' => 70, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 2.3\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 2.4
# Single path consisting of 3 faulty links from A1 to B1: E.A, F.E, B1 are faulty
sub run_test_case_2_4
{
    # Bottleneck link
    $trMatrix = build_bottleneck_topology();
    @event_table = (
            # E.A = 10, F.E = 10, B1 = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 30, 'processed' => 0,},
            # E.A = 10, F.E = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "D1", 'metric' => 20, 'processed' => 0,},
            # E.A = 10
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 10, 'processed' => 0,},
            # F.E = 10, B1 = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 20, 'processed' => 0,},
            # F.E = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "D1", 'metric' => 10, 'processed' => 0,},
            # B1 = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "D1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 2.4\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 2.5
# Single path consisting of all faulty links coming into E: E.A, E.F, E.C are faulty
# Doesn't work because algo picks the link with the max no of unj paths 
sub run_test_case_2_5
{
    # Bottleneck link
    $trMatrix = build_bottleneck_topology();
    @event_table = (
            # E.A = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "D1", 'metric' => 10, 'processed' => 0,},
            # E.F = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "B1", 'dsthost' => "A1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "D1", 'dsthost' => "A1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "D1", 'dsthost' => "C1", 'metric' => 10, 'processed' => 0,},            
            # E.C = 10
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "A1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 10, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "D1", 'metric' => 10, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 2.5\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}


sub run_test_case_3
{
    run_test_case_3_1();
    run_test_case_3_2();
}

# Test case 3.1
# YY topology with faulty egress links around node J
# This is the continuation of test case 1.4
# All bad links are alpha similar
sub run_test_case_3_1
{
    # Bottleneck link
    $trMatrix = build_yy_topology();
    @event_table = (
            # link I.J = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "B1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "D1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            # link H.J = 50
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "E1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "E1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "F1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "F1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            # link G.J = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "E1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "E1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "F1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "F1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 3.1\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

# Test case 3.2
# YY topology with faulty ingress links around node J
# This is the continuation of test case 1.9
# All bad links are alpha similar
sub run_test_case_3_2
{
    # Bottleneck link
    $trMatrix = build_yy_topology();
    @event_table = (
            # link J.H = 50
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "C1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "C1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},            
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "A1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "B1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "D1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "D1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},

            # link J.G = 50
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "A1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "A1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "C1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "D1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 12, 'end' => time - 3, 'srchost' => "B1", 'dsthost' => "E1", 'metric' => 50, 'processed' => 0,},
            { 'start' => time - 10, 'end' => time - 1, 'srchost' => "B1", 'dsthost' => "F1", 'metric' => 50, 'processed' => 0,},

        );
    my ($path_set, $link_set, $trNodePath, $nodeIdTrHopList) = PuNDIT::Central::Localization::Tomography::_buildPathLinkSet($trMatrix);
    print "Test case 3.2\n";
    print Dumper $rt->runTomo(\@event_table, $trMatrix, $trNodePath, $path_set, $link_set);
}

my $runLoop = 1;
while ($runLoop == 1)
{
    print "1. Test case 0\n";
    print "2. Test case 1\n";
    print "3. Test case 2\n";
    print "4. Test case 3\n";
    print "q. Quit\n";
    print "Please enter your choice: ";
    my $input = <STDIN>;
    chomp $input;
    $runLoop = 0 if ($input eq "q");
    
    run_test_case_0() if ($input eq "1");
    run_test_case_1() if ($input eq "2");
    run_test_case_2() if ($input eq "3");
    run_test_case_3() if ($input eq "4");
}