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

=pod
Utils::TrHop.pm

Object to hold hop information. This represents all the hosts for a hop number 
=cut

package Utils::TrHop;

# Top-level init for traceroute hop. Just a list of hops
sub new
{
    my ($class, $hopName, $hopIp) = @_;

    my $self = {
        '_id' => undef,
        '_hopList' => [],
    };

    bless $self, $class;
    
    if (defined($hopName) && defined($hopIp))
    {
        $self->addHopEntry($hopName, $hopIp);
    }
    return $self;
}

# Top-level exit for event receiver
sub DESTROY
{
    # Do nothing?
}

# returns the raw struct
sub getRawList
{
    my ($self) = @_;
    
    return $self->{'_hopList'};
}

sub getHopId
{
    my ($self) = @_;
    
    return $self->{'_id'};
}

# only supports add right now. 
# TODO: Think about delete later. We don't have a use case for it yet
sub addHopEntry
{
    my ($self, $hopName, $hopIp) = @_;

    # error check    
    if (!defined($hopName) || !defined($hopIp))
    {
        warn "Can't add undefined values to TrHop ";
        return;
    }
    
    my %newHop = (
        'hopIp' => $hopIp, 
        'hopName' => $hopName,
    );
    
    # add the new entry
    push (@{$self->{'_hopList'}}, \%newHop);
    
    # update the id
    $self->{'_id'} = _generateHopId($self->{'_hopList'});
}

# generates id from all the nodes
sub _generateHopId
{
    my ($hopArray) = @_;
    
    # optimisation for 1 node
    if (scalar(@{$hopArray}) == 1)
    {
        return $hopArray->[0]{'hopName'};
    }
    # sort to make sure the order is predictable
    my @nameArray = map { $_->{'hopName'} } @{$hopArray}; 
    my @snameArray = sort {lc $a cmp lc $b} @nameArray;
    
    # HopId is just a concatenation
    return join("_", @snameArray); 
}

1;