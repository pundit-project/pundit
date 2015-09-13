#!/usr/bin/perl
=pod
tr_receiver_paristr.pl

Interface to paris traceroute
=cut

package Loc::TrReceiver::Paristr;

use strict;

require "paristr_parser.pl";

# init the module
sub new
{
    use Net::SSH::Perl;
    use Math::BigInt::GMP; # needed for faster SSH

    my $class = shift;
    my $cfg = shift;
    
    # needed for ssh
    my $id_file = $cfg->get_param("paristr", "id_file");
    
    # we need the hosts info so we can do checking
    my $hosts = $cfg->get_param("traceroute", "hosts");
    my $tr_freq = $cfg->get_param("traceroute", "tr_frequency");
        
    my $self = {
        _config => $cfg,
        _id_file => $id_file,
        _hosts => $hosts,
        _tr_freq => $tr_freq,
    };
    
    bless $self, $class;
    return $self;
}

# Make TR query from src_host to dst_host
# Use SSH to call paristr on the src_host
sub make_tr_query
{
	my ($self, $ssh, $dst_host) = @_;	
	
	my($stdout, $stderr, $exit) = $ssh->cmd("paris-traceroute $dst_host");
	
	my $res = paristr_parser::parse($stdout);
	
	unless (defined $res)
	{
		return undef;
	}
	
	my %tr_result = (
		'ts' => time,
		'dst' => $dst_host,
		'path' => $res
	);
	return \%tr_result; 
}

# gets the tr targets to query
sub get_tr_targets
{
	my ($self, $dst) = @_;	
	my @filtered = grep { $_ ne $dst } $self->{'_hosts'};
	return \@filtered;
}

# Retrieves all traceroute info for a host and processes it
# We don't expect to use this much. We'll probably get the TRs at a regular interval and cache them instead of constantly retrieving
sub get_tr_host
{
	my ($self, $src_host) = @_;
	
	# open connection
    my $ssh = Net::SSH::Perl->new($src_host, identity_files => $self->{'_id_file'}, options => ["StrictHostKeyChecking no", "UserKnownHostsFile /dev/null"]);
    $ssh->login("pundit");
    
	# Get the array of src and dst for that endpoint
	my $dest_array = $self->get_tr_targets($src_host);
	
	my %host_tr = ();
	$host_tr{"src"} = $src_host;
	my @tr_list = ();
		
	# loop over the results, getting the TR for each src, dst pair
	foreach my $dst_host (@$dest_array)
	{
		#print Dumper $dst_host;
		
		# Make a query to the target
		my $tr_result = $self->make_tr_query($ssh, $dst_host);
		
		# If actually returns something parsable, add to list
		if (defined $tr_result)
		{
			push @tr_list, $tr_result;	
		}
	}
	
	# cleanup connection
	undef $ssh;
	
	# Store the returned list
	$host_tr{"tr_list"} = \@tr_list;
	
	return \%host_tr;
}

# calls get_tr_host for all monitors
sub get_tr_hosts_all()
{
    my ($self) = @_;
    
    my @tr_list = ();
    for my $host (@{$self->{'_hosts'}})
    {
        print $host . "\n";
        push @tr_list, $self->get_tr_host($host);
    }
    return \@tr_list;
}

1;


# debug
use Data::Dumper;
#print Dumper get_tr_host("punditdev2.aglt2.org");
print Dumper get_tr_hosts_all();