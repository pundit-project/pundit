#!perl -w
#
# Copyright 2015 Georgia Institute of Technology
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

package PuNDIT::Utils::HostInfo;

=pod

=HEAD1 Information about the local host

=cut

use strict;

# returns either the hostname or IP address 
sub getHostId
{
    my $host_id = get_hostname();
    if (!$host_id)
    {
        $host_id = get_local_ip_address();    
    }
    return $host_id;
}


# This idea was borrowed from Net::Address::IP::Local::connected_to()
sub get_local_ip_address 
{
    use IO::Socket::INET;
    
    my $socket = IO::Socket::INET->new(
        Proto       => 'udp',
        PeerAddr    => '198.41.0.4', # a.root-servers.net
        PeerPort    => '53', # DNS
    );

    # A side-effect of making a socket connection is that our IP address
    # is available from the 'sockhost' method
    my $local_ip_address = $socket->sockhost;

    return $local_ip_address;
}

sub get_hostname
{
#    use Net::Domain qw(hostfqdn);
#      
#    return hostfqdn();    
    
    use Sys::Hostname;
    
    return hostname();
}

1;