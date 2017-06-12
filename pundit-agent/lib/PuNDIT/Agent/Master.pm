#!perl -w
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

package PuNDIT::Agent::Master;

use strict;
use Log::Log4perl qw(get_logger);
# local libs
use JSON qw (decode_json); 
use PuNDIT::Agent::Detection;
use Net::AMQP::RabbitMQ;

#Moved from Scheduler
#use File::Find;
#use File::Copy;
#use File::Basename;
#use Data::Dumper; # used for dumping stats

#use PuNDIT::Agent::InfileScheduler::CheckMkReporter;
use PuNDIT::Agent::LocalizationTraceroute;
use PuNDIT::Utils::HostInfo;

# used for time conversion
use Math::BigInt;
use Math::BigFloat;
use constant JAN_1970 => 0x83aa7e80;    # offset in seconds
my $scale = new Math::BigInt 2**32; # this is also a constant

my $logger = get_logger(__PACKAGE__);

# Top-level init for agent master
sub new
{
    my ( $class, $cfgHash ) = @_;

    # Incoming data flow through RabbitMQ from pscheduler
    my $channel = 1;
    my $exchange = "status";  # This exchange must exist already
    my $routing_key = "perfsonar.status";
    my $mqIn = Net::AMQP::RabbitMQ->new();
    $mqIn->connect("localhost", { user => "guest", password => "guest" });
    $mqIn->channel_open($channel);
    $mqIn->exchange_declare($channel, "status");
    # Declare queue, letting the server auto-generate one and collect the name
    my $queuename = $mqIn->queue_declare($channel, "");
	# Bind the new queue to the exchange using the routing key
    $mqIn->queue_bind($channel, $queuename, $exchange, $routing_key);
	# Request that messages be sent and receive them until interrupted
    $mqIn->consume($channel, $queuename);
    
    # Get the list of measurement federations
    my $fedString = $cfgHash->{"pundit-agent"}{"measurement_federations"};
    $fedString =~ s/,/ /g;
    my @fedList = split(/\s+/, $fedString);

    if (!@fedList)
    {
        $logger->error("Empty federation list! Corrupt/invalid configuration file.");
        return undef;
    }

    my %detHash = ();
    foreach my $fed (@fedList)
    {
        $logger->info("Creating Detection Object: $fed");
        my $detectionModule = new PuNDIT::Agent::Detection($cfgHash, $fed);
        
        if (!$detectionModule)
        {
            $logger->error("Couldn't init detection object for federation $fed. Quitting.");    
            return undef;
        }
        
        $detHash{$fed} = $detectionModule;
    }

    ##########################
    #  Moved from Scheduler  #
    ##########################    

    # TODO temporarily disable this feature
    # initialise check mk reporter to periodically write stats
    # my $checkMkReporter = new PuNDIT::Agent::InfileScheduler::CheckMkReporter($cfgHash);

    # debug flags 
    #my $saveProblems = $cfgHash->{"pundit-agent"}{"owamp_data"}{"save_problems"};
    #my $saveProblemsPath = $cfgHash->{"pundit-agent"}{"owamp_data"}{"save_problems_path"};
	


	# Get the hostname of this agent.
	# if the hostname is different from that in the conf file
	# (i.e agent and perfsonar are not on the same host)
	# then use the hostname in the conf file.
    my $hostId = PuNDIT::Utils::HostInfo::getHostId();

    if ($hostId ne $cfgHash->{'pundit-agent'}{'src_host'}){
		$hostId = $cfgHash->{'pundit-agent'}{'src_host'};
	}
	$logger->info($hostId);		


    my $self = {
        '_fedList' => \@fedList,
        '_detHash' => \%detHash,
        '_mqIn' => $mqIn,

        ##########################
        #  Moved from Scheduler  #
        ##########################    
        _hostId => $hostId,
       
		# TODO 
		#Check if src_hostname is ddiferentew.
		
        # flag to indicate whether or not owps with problems will be saved
        #_saveProblems => $saveProblems, 
        #_saveProblemsPath => $saveProblemsPath, # path where owps with detected problems will be saved
        
        # flag that indicates whether a traceroute should be run after a problem is detected
        _runTrace => 0, 

        #_checkMkReporter => $checkMkReporter,
    };

    bless $self, $class;
    return $self;
}

# Top-level exit for event receiver
sub DESTROY
{

   my ($self) = @_;

	$self->{'_mqIn'}->disconnect;
}

sub run
{
    my ($self) = @_;    

    while (my $dataIn = $self->{'_mqIn'}->recv(0)) {
        $logger->debug("A message received from RabbitMQ(in).");
        $self->_processMsg($dataIn);
    }
}


sub _processMsg
{
    my ($self, $dataIn) = @_;

	#$dataIn contains data sent from pscheduler archiver via rabbitmq in string
	#'body' contains the result of the test in a json(string) format
 	my $raw_json = decode_json($dataIn->{'body'});

	#TODO WHEN IS TRACEROUTE test result USED?
	#Will skip if this test is not latencybg i.e traceroute and others will not be processed here.
	if ($raw_json->{'measurement'}{'test'}{'type'} ne "latencybg") {
		$logger->info("Not latencybg data, skipping");
		return 0;
	}
		   
    while (my ($fedName, $detObj) = each (%{$self->{'_detHash'}}))
    {

        # the following two lines could kill performance.
        my ($srcHost, $dstHost, $timeseries, $sessionMinDelay) = $self->_parseJSON($raw_json); 
		$logger->info("Parsed: " . $srcHost . " / " . $dstHost . " / " . $sessionMinDelay);

        # continue if either srcHost or dstHost is not a member of federation
		if ($detObj->isNotInFederation($srcHost, $dstHost)) {
             next;
        }

        # $return - the number of problems detected, 0
        # $stats - status summary generated from this file
        my ($stats, $return) = $detObj->_detection($timeseries, $dstHost,  $sessionMinDelay); 
		$logger->info("return: ", $return);
        # # One or more problems were detected
        # if ($return > 0) {
        #     #$logger->debug("$fedName analysis: $return problems for " . $stats->{'srcHost'} . " to "  . $stats->{'dstHost'});
        #     $logger->info("$fedName analysis: $return problems for " . $stats->{'srcHost'} . " to "  . $stats->{'dstHost'});
                 
            # run trace if runTrace option is enabled
            # if ($self->{'runTrace'})
            # {
            #     if ($stats->{'srcHost'} eq $self->{'_hostId'})
            #     {
            #         $logger->debug('runTrace enabled. Running trace to ' . $stats->{'dstHost'});
                
            #         my $tr_helper = new PuNDIT::Agent::LocalizationTraceroute($self->{'_cfgHash'}, $fedName, time, $stats->{'srcHost'});
            #         $tr_helper->runTrace($stats->{'dstHost'});
            #     }
            #     else
            #     {
            #         $logger->debug("runTrace enabled. Can't run trace on this host: It is the destination");
            #     }
            # }
            
            # user wants to save the problems
            # if ($self->{'_saveProblems'})
            # {
            #     # copy the problematic file to this directory
            #     my($filename, $dirs, $suffix) = fileparse($filePath);
            #     my $savePath = $self->{'_saveProblemsPath'} . $fedName . '/';
                
            #     $logger->debug("Saving problematic owp file $filePath to $savePath");
                
            #     if (!-d $savePath)
            #     {
            #         $logger->debug("Creating path $savePath for savedProblems");
            #         mkdir($savePath);
            #     }
            #     copy($filePath, $savePath . $filename . $suffix);
          
            #     # write the stats in a corresponding txt file
            #     my $statFile = $savePath . $filename . ".txt";
            #     open my $statFh, ">", $statFile; 
            #     print $statFh Dumper( $stats );
            #     close $statFh;
            # }
       # }
    }
    
    return 0; # return ok 
}

# entry point for external functions
# returns undef if not valid
# reads an archiver json file
sub _parseJSON
{
	# $owampResult is $raw_json
	# kept the name to make it easier to compare with the old codebase
    my ($self, $owampResult) = @_;    
     
    # The output variables
    my @timeseries = ();
    my $sessionMinDelay;
    
    # variables used to overwrite delays due to self queueing 
    my ($prevTS, $prevDelay);
    
    my $lost_count;
     
    # TODO WHAT DOES IT DO?
    # Print individual packet delays, with Unix timestamps, using millisecond granularity
    # open(FILE, "<", $inputFile) or die;
    
    # error check the result
    my ($srcHost) = $owampResult->{'measurement'}{'test'}{'spec'}{'source'};
    my ($dstHost) = $owampResult->{'measurement'}{'test'}{'spec'}{'dest'};

	# $entry is a hash
    foreach my $entry (@{$owampResult->{'measurement'}{'result'}{'raw-packets'}})
    {
    	my $unsyncFlag = 0;
        my $lostFlag = 0;
        
        # Send timestamp
        my $sendTs = owptime2exacttime($entry->{"src-ts"});
        my $recvTs = -1;
        my $delay = -1.0;
        
        # Mark lost or unsynced packets differently
        if ($entry->{"dst-ts"} == 0)
        {
            $lostFlag = 1;
        }
        elsif (($entry->{"dst-clock-sync"} == 0) || 
               ($entry->{"src-clock-sync"} == 0))
        {
            # no point calculating delays if unsynced
            $unsyncFlag = 1;
        }
        else # not lost or unsynced
        {
            $recvTs = owptime2exacttime($entry->{"dst-ts"});
            $delay = ($recvTs - $sendTs) * 1000; # convert to milliseconds
            
            # guard against negative values
            if ($delay < 0.0)
            {
                $delay = 0.0;
            }
            
            # fix self-queueing
            # TODO global requires explicit error
            #if ((($sendTs - $prevTs) < 100e-6) && defined($prevDelay))
            #{
            #    $delay = $prevDelay;
            #}
            
            # update for the next loop
            $prevDelay = $delay;
        #TODO global requires explicit error
            #$prevTs = $sendTs;
        }
        
        # store the entry in the timeseries array
        my %elem = (
            'ts' => $sendTs,
            'rcvts' => $recvTs,
            'seq' => int($entry->{"seq-num"}),
            'lost' => $lostFlag,
            'unsync' => $unsyncFlag,
            'delay' => $delay,
        );
        push(@timeseries, \%elem);
        
        # update the minimum delay in this session
        if (($delay > 0.0) && 
            (!defined $sessionMinDelay || $delay < $sessionMinDelay))
        {
            $sessionMinDelay = $delay;
        }
    }

    # sort the timeseries by seq no
    @timeseries = sort { $a->{seq} <=> $b->{seq} } @timeseries;
    
    return ($srcHost, $dstHost, \@timeseries, $sessionMinDelay);
}

sub owptime2exacttime {
    my $bigtime     = new Math::BigInt $_[0];
    my $mantissa    = $bigtime % $scale;
    my $significand = ( $bigtime / $scale ) - JAN_1970;
    return ( $significand . "." . $mantissa );
}

1;
