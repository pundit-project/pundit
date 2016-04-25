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

package PuNDIT::Central::Localization::EvStore;

use strict;
use Log::Log4perl qw(get_logger);

# debug
use Data::Dumper;

use PuNDIT::Central::Localization::EvStore::MySQL;

=pod

=head1 PuNDIT::Central::Localization::EvStore

This class handles the writing to database backend once an event is received.

=cut

my $logger = get_logger(__PACKAGE__);

sub new
{
    my ( $class, $cfgHash, $fedName ) = @_;

    # Shared structure that will hold the trace queues
    my $evStoreDb = new PuNDIT::Central::Localization::EvStore::MySQL($cfgHash, $fedName);
    if (!defined($evStoreDb))
    {
        $logger->error("Couldn't initialize evStoreDb. Quitting");
        return undef;
    }
    
    # Any state can be stored here
    my $self = {
        '_evStoreDb' => $evStoreDb,
    };

    bless $self, $class;
    return $self;
}

sub DESTROY
{
    my ($self) = @_;
    
    # clean up state (if needed)
}

# Writes a received event to the db
sub writeEvToDb
{
    my ($self, $inEv) = @_;
    
    return ($self->{'_evStoreDb'}->writeEv($inEv));
}

1;