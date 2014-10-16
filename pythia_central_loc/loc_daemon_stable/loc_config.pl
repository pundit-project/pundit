#!/usr/bin/perl
package Loc::Config;

use strict;
# Uses this package for loading config files
use Config::IniFiles;

# Just wrap the config::inifiles package for the time being

# Constructor
sub new
{
    my $class = shift;
    my $filename = shift;
    
    my $cfg = Config::IniFiles->new( -file => $filename );
    if (!$cfg)
    {
    	print "Error opening config file $filename\n";
    	return undef;
    }
    
    my $self = {
        _config => $cfg,
    };
    
    bless $self, $class;
    return $self;
}

# Retrieves the value
sub get_param
{
	my ($self, $section, $param) = @_;
    return $self->{_config}->val($section, $param);
}

1;

=pod Test Code
my $derp = new LocConfig("localization.conf");
print $derp->get_param("mysql", "host");
=cut