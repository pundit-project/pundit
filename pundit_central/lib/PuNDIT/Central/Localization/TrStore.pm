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

package PuNDIT::Central::Localization::TrStore;

use strict;
use Log::Log4perl qw(get_logger);

# debug
use Data::Dumper;

use PuNDIT::Central::Localization::TrStore::MySQL;

=pod

=head1 PuNDIT::Central::Localization::TrStore

This class handles the writing to database backend once a traceroute is received.

=cut

my $logger = get_logger(__PACKAGE__);

sub new
{
    my ( $class, $cfgHash, $fedName ) = @_;

    # Shared structure that will hold the trace queues
    my $trStoreDb = new PuNDIT::Central::Localization::TrStore::MySQL($cfgHash, $fedName);
    if (!defined($trStoreDb))
    {
        $logger->error("Couldn't initialize trStoreDb. Quitting");
        return undef;
    }
    
    # Any state can be stored here
    my $self = {
        '_trStoreDb' => $trStoreDb,
    };

    bless $self, $class;
    return $self;
}

sub DESTROY
{
    my ($self) = @_;
    
    # clean up state (if needed)
}

# Writes a received traceroute to the db
sub writeTrToDb
{
    my ($self, $inTr) = @_;
    
    return ($self->{'_trStoreDb'}->writeTr($inTr));
}

1;