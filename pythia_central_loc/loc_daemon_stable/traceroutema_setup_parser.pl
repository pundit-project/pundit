#!/usr/bin/perl
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

package traceroutema_setup_parser;
use base qw(XML::SAX::Base);

#use Data::Dumper;

# Callback at the start of the document.
# Initialises everything
sub start_document 
{
    my ($self, $doc) = @_;
    # process document start event
    my %data = ();
    $self->{data} = \%data;
    $self->{maxttl} = ();
    $self->{invalid} = 0;
}

# Returns the parsed data structure once it hits the end of the doc
sub end_document
{
	my ($self, $doc) = @_;
	
	# Discard everything if invalid
	return (undef, undef, undef, undef) if ($self->{invalid} == 1);
	
	# else return the parsed data structures 
	return ($self->{src}, $self->{dst}, $self->{data}, $self->{maxttl});
}

# Callback for when the parser encounters an open clause. 
# Most of the storage will be done here 
sub start_element 
{
    my ($self, $el) = @_;
    
    # process element start event
    if ($el->{LocalName} eq "src")
    {
    	#"No matching tests found"
    	#print Dumper $el;
    	my $src = $el->{"Attributes"}->{"{}value"}->{"Value"};
    	$self->{src} = $src;
   	}
   	elsif ($el->{LocalName} eq "dst")
    {
    	#"No matching tests found"
    	#print Dumper $el;
    	my $dst = $el->{"Attributes"}->{"{}value"}->{"Value"};
    	$self->{dst} = $dst;
   	}
    elsif ($el->{LocalName} eq "datum")
    {
    	#print Dumper $el;
    	# Copy out the required values
    	my $ttl = $el->{"Attributes"}->{"{}ttl"}->{"Value"};
    	my $hop = $el->{"Attributes"}->{"{}hop"}->{"Value"};
    	my $querynum = $el->{"Attributes"}->{"{}queryNum"}->{"Value"};
    	my $timeval = $el->{"Attributes"}->{"{}timeValue"}->{"Value"};

		# Store it in the data structure
    	$self->{data}->{$timeval}->{$querynum}->{$ttl} = $hop;
    	
    	# update the ttl
    	#$self->{maxttl}->{$timeval} = () if (!exists($self->{maxttl}->{$timeval}));
    	$self->{maxttl}->{$timeval}->{$querynum} = $ttl if ($ttl > $self->{maxttl}->{$querynum});
    }
    
}

# Helper function to check whether a test was valid or not
# The function name is a parser interface
sub characters
{
	my ($self, $el) = @_;
	
	# If the test doesn't have any results, skip it
	# SAX doesn't allow us to stop parsing here
	if ($el->{Data} eq "No matching tests found")
	{
		$self->{invalid} = 1;	
	}
	elsif ($el->{Data} eq "Query returned 0 results")
	{
		$self->{invalid} = 1;	
	}
}

1;
