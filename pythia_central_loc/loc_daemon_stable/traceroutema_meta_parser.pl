#!/usr/bin/perl

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
