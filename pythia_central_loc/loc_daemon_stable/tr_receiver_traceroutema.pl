#!/usr/bin/perl

use strict;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;

use XML::SAX;
require "traceroutema_meta_parser.pl";
require "traceroutema_setup_parser.pl";

# Globals

# Endpoint list: Array of src, dst and keys
my $endpoint_list;

# number of seconds to query
my $query_limit = 60 * 15;


my $debug = 1;

if ($debug == 1)
{
	use Data::Dumper;
}

# Builds the metadata request to a tracerouteMA host
# The reply will indicate all traceroutes in the specified time period
sub build_meta_request
{
	my ($start_time, $end_time) = @_;
	my $request = 
	"<SOAP-ENV:Envelope xmlns:SOAP-ENC='http://schemas.xmlsoap.org/soap/encoding/' 
                   xmlns:xsd='http://www.w3.org/2001/XMLSchema' 
                   xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' 
                   xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/'>
  <SOAP-ENV:Header/>
  <SOAP-ENV:Body>
  <nmwg:message type='MetadataKeyRequest' id='metadataKeyRequest1' 
              xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/' 
              xmlns:select='http://ggf.org/ns/nmwg/ops/select/2.0/' 
              xmlns:nmwgt='http://ggf.org/ns/nmwg/topology/2.0/' 
              xmlns:nmtm='http://ggf.org/ns/nmwg/time/2.0/'>
  
    <!-- get all keys between a given start and end time -->
  <nmwg:metadata id='meta2' xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/'>
    <traceroute:subject xmlns:traceroute='http://ggf.org/ns/nmwg/tools/traceroute/2.0' id='s-in-iperf-1'>
      <nmwgt:endPointPair xmlns:nmwgt='http://ggf.org/ns/nmwg/topology/2.0/' />
    </traceroute:subject>
    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/traceroute/2.0</nmwg:eventType>
    <nmwg:parameters id='params2'></nmwg:parameters>
  </nmwg:metadata> 
  <nmwg:metadata id='meta.2.chain' xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/'>
    <select:subject id='subject.16110882' metadataIdRef='meta2' xmlns:select='http://ggf.org/ns/nmwg/ops/select/2.0/'/>
    <select:parameters id='parameters.14643134' xmlns:select='http://ggf.org/ns/nmwg/ops/select/2.0/'>
        <nmwg:parameter name='startTime'>${start_time}</nmwg:parameter>
        <nmwg:parameter name='endTime'>${end_time}</nmwg:parameter>
    </select:parameters>
    <nmwg:eventType>http://ggf.org/ns/nmwg/ops/select/2.0</nmwg:eventType>
  </nmwg:metadata>
  <nmwg:data id='data2' metadataIdRef='meta2' xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/'/>
  </nmwg:message>
  
	</SOAP-ENV:Body>
</SOAP-ENV:Envelope>";
	return $request;
}

# Processes the metadata response packet and builds hash of hashes to access endpoints
sub process_meta_response
{
	my ($raw_xml) = @_;
	
	my $parser = XML::SAX::ParserFactory->parser(Handler => traceroutema_meta_parser->new);
	my $result_table = $parser->parse_string($raw_xml);
	
	return $result_table;
}

# Returns an array of endpoints
sub get_tr_info
{
	my ($dest_host) = @_;

	# Destination URL is the tracerouteMA	
	my $dest_url = "http://${dest_host}:8086/perfSONAR_PS/services/tracerouteMA";
		
	# define the HTTP header
	my $objHeader = HTTP::Headers->new;
	$objHeader->push_header('Content-Type' => 'text/xml');
	
	my $xml = build_meta_request(time - $query_limit, time);
	
	# make the call
	my $objRequest = HTTP::Request->new("POST", $dest_url, $objHeader, $xml);
	
	# deal with the response
	my $objUserAgent = LWP::UserAgent->new;
	my $objResponse = $objUserAgent->request($objRequest);
	
	# Print error and quit
	if ($objResponse->is_error) 
	{
	    print $objResponse->error_as_HTML;
	    return;
	}
	#print $objResponse->content;
	
	# Returns the endpoint list
	return process_meta_response($objResponse->content);
}

# Builds a setup data request from a set of ma keys
sub build_setup_request
{
	my ($ma_key, $start_time, $end_time) = @_;
	
	my $request = 
	"<SOAP-ENV:Envelope xmlns:SOAP-ENC='http://schemas.xmlsoap.org/soap/encoding/' 
                   xmlns:xsd='http://www.w3.org/2001/XMLSchema' 
                   xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' 
                   xmlns:SOAP-ENV='http://schemas.xmlsoap.org/soap/envelope/'>
  <SOAP-ENV:Header/>
  <SOAP-ENV:Body>
	<nmwg:message type='SetupDataRequest' id='setupDataRequest1'
              xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/'
              xmlns:select='http://ggf.org/ns/nmwg/ops/select/2.0/'
              xmlns:nmwgt='http://ggf.org/ns/nmwg/topology/2.0/'
              xmlns:nmtm='http://ggf.org/ns/nmwg/time/2.0/'>

    <!-- get results between all stored endpoints in a given time range -->  
    <nmwg:metadata id='metadata.12773104' xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/'>
      <nmwg:key xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/' id='key-1'>
        <nmwg:parameters id='parameters-key-1'>
            <nmwg:parameter name='maKey'>${ma_key}</nmwg:parameter>
        </nmwg:parameters>
      </nmwg:key>
      <nmwg:eventType>http://ggf.org/ns/nmwg/tools/traceroute/2.0</nmwg:eventType>
      <nmwg:parameters id='traceParams1'>
        <nmwg:parameter name='startTime'>${start_time}</nmwg:parameter>
        <nmwg:parameter name='endTime'>${end_time}</nmwg:parameter>
      </nmwg:parameters>
    </nmwg:metadata>
    
    <nmwg:data id='data1' metadataIdRef='metadata.12773104' xmlns:nmwg='http://ggf.org/ns/nmwg/base/2.0/'/>
    
	</nmwg:message>
	</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
	";
}


# Compares 2 traceroute runs
# Returns 0 if equal, 1 otherwise
sub compare_tr
{
	my ($a, $a_ttl, $b, $b_ttl) = @_;
	
	# ttl mismatch
	return 1 if ($a_ttl != $b_ttl);
	
	# Loop over hashes
	for (my $i = 1; $i <= $a_ttl; $i++)
	{
		# We don't want entries with gaps in them
		return 1 if (!exists($a->{$i}) || !exists($b->{$i}));
		
		# value mismatch
		return 1 if ($a->{$i} ne $b->{$i});
	}
	return 0;
}

# Processes the intermediate traceroute into the "accepted" tr format
sub process_tr
{
	my ($tr, $ttl) = @_;
	
	my @tr_array = ();
	
	for (my $i = 1; $i <= $ttl; $i++)
	{
		push(@tr_array, $tr->{$i});
	}
	
	return \@tr_array;
}

# Processes the setup response xml file into a traceroute table with confidence levels
sub process_setup_response
{
	my ($raw_xml) = @_;
	
	my $parser = XML::SAX::ParserFactory->parser(Handler => traceroutema_setup_parser->new);
	my ($src, $dst, $result_tr, $maxttl) = $parser->parse_string($raw_xml);
	
	return undef if (!$result_tr);
	
	#print "$raw_xml\n";
	
	# Process the intermediate data structures
	my %tr_info = ();
	
	# Save the source and dest
	$tr_info{"src"} = $src;
	$tr_info{"dst"} = $dst;
	
	# Select one of the queries to be representative of the traceroute
	
	# select the largest timestamp
	my @candidate_ts = sort { $b <=> $a } keys($result_tr);
	my $ts = shift @candidate_ts;
	
	if (!$ts)
	{
		print "Error!\n";
		$tr_info{"ts"} = -1;
		$tr_info{"path"} = ();
		return \%tr_info;
	}
	
	# Get the list of queries
	my @candidate_queries = keys($result_tr->{$ts});
	my %selected_queries = ();
	
	# Get info about the current 
	my $curr_queryno = shift @candidate_queries;
	my $curr_ttl = $maxttl->{$ts}->{$curr_queryno};
	my $curr_tr = $result_tr->{$ts}->{$curr_queryno};
	while ($curr_queryno)
	{
		# compare with others
		foreach my $comp_queryno (@candidate_queries)
		{
			my $comp_ttl = $maxttl->{$ts}->{$comp_queryno};
			my $comp_tr = $result_tr->{$ts}->{$comp_queryno};
			
			# Compare if same...
			if (compare_tr($curr_tr, $curr_ttl, $comp_tr, $comp_ttl) == 0)
			{
				$selected_queries{$curr_queryno} += 1;
			}
		}
		
		$curr_queryno = shift @candidate_queries;
	}
	
	# select the queryno with the highest votes
	my @voted_queryno = sort {$selected_queries{$b} <=> $selected_queries{$a}} keys %selected_queries;
	my $selected_queryno = shift @voted_queryno;
	# select at random
	$selected_queryno = 1 if (!$selected_queryno);
	
	#print "Selected tr #$selected_queryno\n";
	
	my $selected_ttl = $maxttl->{$ts}->{$selected_queryno};
	my $selected_tr = $result_tr->{$ts}->{$selected_queryno};
	
	$tr_info{"ts"} = $ts;
	$tr_info{"path"} = process_tr($selected_tr, $selected_ttl);
	
	#print Dumper $result_tr;
	#print Dumper $maxttl;
	#print Dumper \%tr_info;
	
	return \%tr_info;
}

sub get_tr_details
{
	my ($ma_key, $dest_host) = @_;
	
	# Destination URL is the tracerouteMA
	my $dest_url = "http://${dest_host}:8086/perfSONAR_PS/services/tracerouteMA";
		
	# define the HTTP header
	my $objHeader = HTTP::Headers->new;
	$objHeader->push_header('Content-Type' => 'text/xml');
	
	my $xml = build_setup_request($ma_key, time - $query_limit, time);
	
	# make the call
	my $objRequest = HTTP::Request->new("POST", $dest_url, $objHeader, $xml);
	
	# deal with the response
	my $objUserAgent = LWP::UserAgent->new;
	my $objResponse = $objUserAgent->request($objRequest);
	
	# Print error and quit
	if ($objResponse->is_error)
	{
	    print $objResponse->error_as_HTML;
	    return undef;
	}
	#print $objResponse->content;
	
	# returns the processed setup response
	my $tr_info = process_setup_response($objResponse->content);
#	if ($tr_info)
#	{
#		$tr_info->{'ma_key'} = $ma_key;
#	}
	
	return $tr_info;
}

# Retrieves all traceroute info for a host and processes it
# We don't expect to use this much. We'll probably get the TRs at a regular interval and cache them instead of constantly retrieving
sub get_tr_host
{
	my ($dest_host) = @_;
	
	# Get the array of src and dst for that endpoint
	my $src_dest_array = get_tr_info($dest_host);
	
	my %host_tr = ();
	$host_tr{"src"} = $dest_host;
	my %tr_list = ();
	
	# loop over the results, getting the TR for each src, dst pair
	foreach my $element (@$src_dest_array)
	{
		# Skip ipv4 version of the source address
		if ($element->{"src"} ne $dest_host)
		{
			#print "Skipping $element->{src}\n";
			next;
		} 
		
		#print Dumper $element;
		
		# Make a query to the tracerouteMA
		my $tr_result = get_tr_details($element->{"key"}, $dest_host);
		
		# If actually returns something parsable, add to list
		$tr_list{$element->{"key"}} = $tr_result if ($tr_result);
	}
	
	# Store the returned list
	$host_tr{"tr_list"} = \%tr_list;
	
	return \%host_tr;
}

#print Dumper get_tr_info("gammon.barrow.k12.ga.us");
#print Dumper get_tr_details("adb3eed19009344ee7658ff59006f15d", "gammon.barrow.k12.ga.us");
print Dumper get_tr_host("gammon.barrow.k12.ga.us");