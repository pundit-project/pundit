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