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

package traceroutema_meta_parser;
use base qw(XML::SAX::Base);

#use Data::Dumper;

sub start_document 
{
    my ($self, $doc) = @_;
    # process document start event
    my @data = ();
    $self->{data} = \@data;
}

sub end_document
{
	my ($self, $doc) = @_;
	return $self->{data};
}

sub start_element 
{
    my ($self, $el) = @_;
    
    # process element start event
    if ($el->{LocalName} eq "metadata")
    {
    	my $value = $el->{"Attributes"}->{"{}id"}->{"Value"};
    	$self->{endpointpair} = ();
    	$self->{endpointpair}->{key} = substr($value, 5);;
   	}
    elsif ($el->{LocalName} eq "src")
    {
    	my $value = $el->{Attributes}->{"{}value"}->{Value};
    	$self->{endpointpair}->{src} = $value;
    }
    elsif ($el->{LocalName} eq "dst")
    {
    	my $value = $el->{Attributes}->{"{}value"}->{Value};
    	$self->{endpointpair}->{dst} = $value;
    }
    
}

sub end_element 
{
    my ($self, $el) = @_;
    # process element start event
    
    if ($el->{LocalName} eq "metadata")
    {
    	my $endpointpair = $self->{endpointpair}; 
    	push $self->{data}, $endpointpair;
    	$self->{endpointpair} = ();
    }
    
}
1;
