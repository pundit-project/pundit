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

package PuNDIT::Agent::Detection;

use strict;
use Log::Log4perl qw(get_logger);
use JSON::XS;

use PuNDIT::Agent::Detection::Reporter;
use PuNDIT::Agent::RelayTraceroute;
use PuNDIT::Utils::HostInfo;
use Data::Dumper;
# used for time conversion
use Math::BigInt;
use Math::BigFloat;
use constant JAN_1970 => 0x83aa7e80;    # offset in seconds
my $scale = new Math::BigInt 2**32; # this is also a constant

my $logger = get_logger(__PACKAGE__);

sub new
{
    my ($class, $cfgHash, $fedName) = @_;

    # federation info
    my $hostId = PuNDIT::Utils::HostInfo::getHostId();
    
    my $peer_monitor_string = $cfgHash->{"pundit-agent"}{$fedName}{"peers"};
    $peer_monitor_string =~ s/,/ /g;
    my @peer_monitors = split(/\s+/, $peer_monitor_string);

    # owamp parameters
    my $sampleCount = $cfgHash->{"pundit-agent"}{$fedName}{"owamp_params"}{"sample_count"};
    my $packetInterval = $cfgHash->{"pundit-agent"}{$fedName}{"owamp_params"}{"packet_interval"};
    
    # detection parameters
    my ($delayVal, $delayType) = _parseTimeOrPercentage($cfgHash->{"pundit-agent"}{$fedName}{"detection"}{"delay_max"});
    my ($delayThresh) = _parsePercentage($cfgHash->{"pundit-agent"}{$fedName}{"detection"}{"delay_threshold"});
    my ($lossThresh) = _parsePercentage($cfgHash->{"pundit-agent"}{$fedName}{"detection"}{"loss_threshold"});
    if (!(defined($delayVal)&&defined($delayThresh)&&defined($lossThresh)))
    {
        $logger->critical("Detection Parameters not defined. Can't continue");
        return undef;
    }

    # debug flags 
    my $saveProblems = $cfgHash->{"pundit-agent"}{"owamp_data"}{"save_problems"};
    
    # initalize reporting here as well
    my $reporter = new PuNDIT::Agent::Detection::Reporter($cfgHash, $fedName); 
    
    my $self = {
        '_cfgHash' => $cfgHash,
        '_fedName' => $fedName,
        
        '_hostId' => $hostId,
        '_peers' => \@peer_monitors,
        '_sampleCount' => $sampleCount,
        '_packetInterval' => $packetInterval,
        
        '_reporter' => $reporter,
        
        '_delayVal' => $delayVal,
        '_delayType' => $delayType,
        '_delayThresh' => $delayThresh,
        
        '_lossThresh' => $lossThresh,
        '_routeChangeThresh' => 0.6, ## TODO: Seprarte config
        
        '_windowSize' => 5, # window size in seconds
        '_windowPackets' => 50, # expected number of packets in a window (fix this later)
        
        '_incompleteBinHash' => {}, # hash for holding incomplete bins
        '_incompleteBinCullThresh' => 30, # incomplete bins older than X minutes will be culled 
        '_incompleteBinCullTime' => 0, # last time incomplete entries were culled
        
        '_contextSwitchThresh' => 0.0001, # gaps smaller than this for context switch detection (in s)
        '_contextSwitchConsecPkts' => 5, # number of consecutive packets to consider as context switch
        
        '_routeChangeThresh' => 50, # route change level shift detection threshold (in ms)

        # flag to indicate whether or not owps with problems will be saved
        _saveProblems => $saveProblems, 
    };
    
    bless $self, $class;
    return $self;
}

my $previous_trace;

# entry point for external functions
# returns undef if not valid
sub processFile
{
    my ($self, $dataIn) = @_;
    
    # $dataIn contains data (in str format) sent from pscheduler archiver via rabbitmq
    #'body' contains the result of the test in a json(string) format
    my $raw_json = decode_json($dataIn->{'body'});
    my $toolname = $raw_json->{'measurement'}{'tool'}{'name'}; 
    $logger->debug("Tool name: " . $toolname);

    # forward paris-traceroute results
    if ($toolname eq "paris-traceroute") {
        my $tr_helper = new PuNDIT::Agent::RelayTraceroute($self->{'_cfgHash'}, $self->{'_fedName'});
        $previous_trace = $tr_helper->relayTrace($raw_json, $previous_trace);

        return 0; # return ok
    }
    if ($toolname ne "powstream") {
        $logger->debug("Unrecognized toolname.");
        return 0;
    }
           
    my ($srcHost, $dstHost, $timeseries, $sessionMinDelay) = $self->_readJson($raw_json); 
    $logger->debug("Parsed: " . $srcHost . " / " . $dstHost . " / " . $sessionMinDelay);
    
    if ($srcHost ne $self->{'_hostId'})
    {
        $logger->debug("Skipping $srcHost. Not from this host " . $self->{'_hostId'});
        return (-1, undef);
    }
    
    # filter out destinations not in the current federation
    #TODO: Figure out how to get the data out of the owp files
    if (!grep( /^$dstHost$/, @{$self->{'_peers'}} ) )
    {
        $logger->debug("Skipping $dstHost. Not in peerlist");
        return (-1, undef);
    }
    
    # perform detection and return a summary
    my ($summary, $problemFlags) = $self->_detection($timeseries, $dstHost, $sessionMinDelay);

    my $startTime = _roundOff($timeseries->[0]{ts});
    my $statusMsg = {
        'srcHost' => $srcHost,
        'dstHost' => $dstHost,
        'startTime' => $startTime,
        'endTime' => _roundOff($timeseries->[-1]{ts}),
        'duration' => ($timeseries->[-1]{ts} - $timeseries->[0]{ts}),
        'baselineDelay' => $sessionMinDelay,
        'entries' => $summary,
    };

    my $publishedMsg = $self->{'_reporter'}->writeStatus($statusMsg);
    $logger->info ("Published: $publishedMsg"); 
    
    # user wants to save the problems
    if ($problemFlags gt 0 && $self->{'_saveProblems'} eq 1) {
        _saveProblems($problemFlags, $publishedMsg, $statusMsg, $timeseries, $summary);       
    }    
    
    return ($problemFlags, $statusMsg);
}

sub owptime2exacttime {
    my $bigtime     = new Math::BigInt $_[0];
    my $mantissa    = $bigtime % $scale;
    $mantissa = ($mantissa . "") / (2**32);
    my $significand = ( $bigtime / $scale ) - JAN_1970;
    return ( ($significand . ".") + $mantissa );
}

sub _saveProblems {

    my ($problemFlags, $publishedMsg, $statusMsg, $timeseries, $summary) = @_;
    my $srcHost = $statusMsg->{'srcHost'};
    my $dstHost = $statusMsg->{'dstHost'};
    my $startTime = $statusMsg->{'startTime'};

    my $loggerStr = undef;
    $loggerStr .= "\n*Published(raw): $publishedMsg \n";
    $loggerStr .= "*Path: $srcHost > $dstHost\n";
    $loggerStr .= "\t$problemFlags problems at " . scalar(localtime($startTime)) . "($startTime) \n";
    $loggerStr .= "*Summary for each 5-sec window: \n";

    foreach my $eachWindow (@{$summary}) {
        my $firstTs = %{$eachWindow}->{"firstTimestamp"};
        my $lastTs = %{$eachWindow}->{"lastTimestamp"};

        my $windowContent = undef;
        while(my($key, $value) = each %{$eachWindow}){
            if ($key ne "firstTimestamp" && $key ne "lastTimestamp") {
                $windowContent .= "\t$key: $value\n";
            }
        }
        my $packetContent = "\tpackets: \n";
        foreach my $eachHash (@{$timeseries}) {
            if (%{$eachHash}->{"ts"} ge $firstTs && %{$eachHash}->{"rcvts"} lt $lastTs && %{$eachHash}->{"ts"} lt ($firstTs + 5)) {
                $packetContent .= "\t seq: " . %{$eachHash}->{"seq"} . ", delay: " . %{$eachHash}->{"delay"} . ", ts: " . %{$eachHash}->{"ts"} . ", rcvTs: " . %{$eachHash}->{"rcvts"} . "\n";
            }
        }                

        $loggerStr .= " -Packet win from ";
        $loggerStr .= $firstTs . " (" . _formattime($firstTs) . ") to $lastTs \n";
        $loggerStr .= $windowContent . $packetContent;
    }

    my $src = $statusMsg->{"srcHost"} =~ /[^.]*/g;
    my $dst = $statusMsg->{"dstHost"} =~ /[^.]*/g;
    my $savePath = "/var/log/perfsonar/savedProblems";

    if (!-d $savePath) {
        mkdir ($savePath);
    }       

    my $statFile = $savePath . "/" . $srcHost . "_" . $dstHost . "_" . $statusMsg->{"startTime"};
    open my $statFh, ">", $statFile; 
        print $statFh $loggerStr;
    close $statFh;        

    my $rawFile = $savePath . "/" . $srcHost . "_" . $dstHost . "_" . $statusMsg->{"startTime"} . ".raw";
    open my $rawFh, ">", $rawFile; 
        print $rawFh Dumper( $timeseries);
    close $rawFh;        

}

sub _formattime {
    my ($time) = @_;
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
    my $formattedTs = sprintf("%02d:%02d:%02d", $hour, $min, $sec);    

    return $formattedTs;
}

# parses the config variable for the value
sub _parseTimeOrPercentage
{
    my ($input) = @_;
    my $val;
    my $type;
    
    if ($input =~ /^(\d+)\s?ms$/)
    {
        $val = $1;
        $type = "absolute";
    }
    elsif ($input =~ /^(\d+)%$/)
    {
        $val = $1;
        $type = "relative";
    }
    else
    {
        print "unknown value $input";
    }
    
    return ($val, $type);
}

# fake rounding function, so we don't need to include posix
sub _roundOff
{
    my ($val) = @_;
    
    # different rounding whether positive or negative
    if ($val >= 0)
    {
        return int($val + 0.5);
    }
    else
    {
        return int($val - 0.5);
    }
}

sub _parsePercentage
{
    my ($input) = @_;
    my $val;
    
    if ($input =~ /^(\d+)%$/)
    {
        $val = $1 * 1.0;
    }
    else
    {
        print "unknown value $input";
    }
    return ($val);
}

sub _parseInt
{
    my ($input) = @_;
    my $val;
    
    if ($input =~ /^(\d+)$/)
    {
        $val = $1;
    }
    else
    {
        print "unknown value $input";
    }
    return ($val);
}

# returns undef if not valid
# reads + parses an archiver json file 
sub _readJson
{
    # $owampResult is $raw_json
    # kept the name to make it easier to compare with the old codebase
    my ($self, $owampResult) = @_;    
     
    # The output variables
    my @timeseries = ();
    my $sessionMinDelay;
    
    # variables used to overwrite delays due to self queueing 
    my ($prevTs, $prevDelay);
    
    my $lost_count;
     
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
            if ((($sendTs - $prevTs) < 100e-6) && defined($prevDelay))
            {
                $delay = $prevDelay;
            }
            
            # update for the next loop
            $prevDelay = $delay;
            $prevTs = $sendTs;
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



# Calculates the bin of this timestamp
# only used in version 1 of detection
sub _calcBin
{
    my ($self, $timestamp) = @_;
    return int(int($timestamp)/$self->{'_windowSize'}) * $self->{'_windowSize'}
}

# Version 1: Bin the elements into 5 second intervals
sub _detection
{
    my ($self, $timeseries, $dstHost, $sessionMinDelay) = @_;
    
    # Flag whether to combine consecutive sessions or not
    my $combineSessions = 0; 
    
    # index of the start of a 5 sec window and the corresponding timestamp
    my $windowStart = 0;
    my $problemCount = 0;
    my $currentBin = $self->_calcBin($timeseries->[0]{ts});
    
    # min delay in the window
    my $windowMinDelay = $timeseries->[0]{delay};
    
    # array that holds the per 5 second detection results
    my @results = ();
    
    # loop over timeseries
    for (my $i=0; $i < @$timeseries; $i++)
    {
        # if timeseries window is full
        if ((int($timeseries->[$i]{ts}) - $currentBin) >= $self->{'_windowSize'})
        {
            # calculate event here
            my $tsSlice = [@$timeseries[$windowStart .. ($i - 1)]]; # this is the subset of the timeseries used for processing
            
#            print "tsSlice is " . scalar(@$tsSlice) . "\n";  # debug
            
            # combining bins at edge of measurements
            # store the first window if too few packets
            if ($windowStart == 0)
            {
#                print "First bin is incomplete " . scalar(@$tsSlice) ."\n";
                
                # check whether there's a matching bin in the incomplete bin hash
                if ($combineSessions &&
                    exists $self->{'_incompleteBinHash'}{$dstHost} &&
                    defined $self->{'_incompleteBinHash'}{$dstHost}{$currentBin})
                {
#                    print "Found remainder in incompleteBinHash\n";
                    
                    my $incSlice = $self->{'_incompleteBinHash'}{$dstHost}{$currentBin};
                    
#                    print "incSlice " . @$incSlice . " tsSlice " . @$tsSlice . "\n";
                    
                    push(@$incSlice, @$tsSlice); # combine the 2 arrays
                    undef $tsSlice;
                    delete $self->{'_incompleteBinHash'}{$dstHost}{$currentBin};
                    $tsSlice = $incSlice;
                    
                    my ($windowSummary, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay, $currentBin, $currentBin + $self->{'_windowSize'});
                    # Store summary in result
                    push(@results, $windowSummary);
                    
                    $problemCount += $windowProblemCount;
                }
                elsif ((scalar(@$tsSlice)/$self->{'_windowPackets'}) >= 0.8) # process if greater than 80% full ## TODO: Change to time range
                {
                    my ($windowSummary, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay, $currentBin, $currentBin + $self->{'_windowSize'});
                    # Store summary in result
                    push(@results, $windowSummary);
                    
                    $problemCount += $windowProblemCount;
                }
                elsif ($combineSessions) # store it in the incompleteBinHash if not enough samples
                {
#                    print "Adding first packet to incompleteBinHash\n";
                    $self->{'_incompleteBinHash'}{$dstHost}{$currentBin} = $tsSlice;
                }
            }
            else
            {
                my ($windowSummary, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay, $currentBin, $currentBin + $self->{'_windowSize'});
                # Store summary in result
                push(@results, $windowSummary);
                
                $problemCount += $windowProblemCount;
            }
            
            $windowStart = $i; # update the window for the next loop
            $currentBin += $self->{'_windowSize'};
            $windowMinDelay = $timeseries->[$i]{delay}; # reset the value for the next loop
        }
        
        # get the min across the windows
        elsif (!defined($windowMinDelay) || ($timeseries->[$i]{delay} && (($windowMinDelay > $timeseries->[$i]{delay}))))
        {
            $windowMinDelay = $timeseries->[$i]{delay}; 
        }
    }
    
    # process leftover entries
    if ($windowStart < (@$timeseries - 1))
    {
        my $tsSlice = [@$timeseries[$windowStart .. (@$timeseries - 1)]]; # this is the subset of the timeseries used for processing
        
#        print "LAST: tsSlice is " . scalar(@$tsSlice) . "\n";
        
        # check whether there's a matching bin in the incomplete bin hash
        if ($combineSessions &&
            exists $self->{'_incompleteBinHash'}{$dstHost} &&
            defined $self->{'_incompleteBinHash'}{$dstHost}{$currentBin})
        {
#            print "Found remainder in incompleteBinHash\n";
            
            my $incSlice = $self->{'_incompleteBinHash'}{$dstHost}{$currentBin};
            
#            print "incSlice " . @$incSlice . " tsSlice " . @$tsSlice . "\n";
            
            push(@$tsSlice, @$incSlice); # combine the 2 arrays
            undef $incSlice;
            delete $self->{'_incompleteBinHash'}{$dstHost}{$currentBin};
            
            my ($windowSummary, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay, $currentBin, $currentBin + $self->{'_windowSize'});
            # Store summary in result
            push(@results, $windowSummary);
            
            $problemCount += $windowProblemCount;
        }
        elsif ((scalar(@$tsSlice)/$self->{'_windowPackets'}) >= 0.8 ) # process if greater than 80% full
        {
            my ($windowSummary, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay, $currentBin, $currentBin + $self->{'_windowSize'});
            # Store summary in result
            push(@results, $windowSummary);
            
            $problemCount += $windowProblemCount;
        }
        elsif ($combineSessions) # store it in the incompleteBinHash 
        {
#            print "Adding last packet to incompleteBinHash\n";
            $self->{'_incompleteBinHash'}{$dstHost}{$currentBin} = $tsSlice;
        }        
                
        # reset vars at the end
        $windowStart = (@$timeseries - 1); 
        undef $windowMinDelay;
    }
    
    return (\@results, $problemCount);
}

# Version 2: bin the results to an integer number of bins, each approximately windowSize large
sub _detection2
{
    my ($self, $timeseries, $dstHost, $sessionMinDelay) = @_;
    
    ### Output variables
    # min delay in the window
    my $windowMinDelay = $timeseries->[0]{delay};
    # array that holds the per 5 second detection results
    my @results = ();
    
    # duration of the session
    my $sessionDuration = $timeseries->[-1]{ts} - $timeseries->[0]{ts};
    if ($sessionDuration == 0)
    {
        return (undef, 0);
    }
    
    # number of windows of approximately windowSize
    my $windowCount = _roundOff($sessionDuration/$self->{'_windowSize'});
    if ($windowCount == 0)
    {
        return (undef, 0);
    }
    
    # The actual width of each window to use
    my $windowDuration = $sessionDuration / $windowCount;
    
    # index of the start of a window and the corresponding timestamp
    my $windowStart = 0;
    my $problemCount = 0;
    
    # loop over timeseries
    for (my $i=0; $i < @$timeseries; $i++)
    {
        # if timeseries window is full
        if (($timeseries->[$i]{ts} - $timeseries->[$windowStart]{ts}) >= $windowDuration)
        {
            # calculate event here
            my $tsSlice = [@$timeseries[$windowStart .. ($i - 1)]]; # this is the subset of the timeseries used for processing
            
#            print "tsSlice is " . scalar(@$tsSlice) . "\n";
            
            my ($windowSummary, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay, $tsSlice->[0]->{'ts'}, $tsSlice->[-1]->{'ts'});
            # Store summary in result
            push(@results, $windowSummary);
            
            $problemCount += $windowProblemCount;
            
            $windowStart = $i; # update the window for the next loop
            
            $windowMinDelay = $timeseries->[$i]{delay}; # reset the value for the next loop
        }
        
        # get the min across the windows
        elsif ($timeseries->[$i]{delay} && (($windowMinDelay > $timeseries->[$i]{delay})|| !defined($windowMinDelay)))
        {
            $windowMinDelay = $timeseries->[$i]{delay};
            if ($windowMinDelay < $sessionMinDelay)
            {
                $sessionMinDelay = $windowMinDelay;
            } 
        }
    }
    
    # process leftover entries
    if ($windowStart < (@$timeseries - 1))
    {
        my $tsSlice = [@$timeseries[$windowStart .. (@$timeseries - 1)]]; # this is the subset of the timeseries used for processing
        
#        print "LAST: tsSlice is " . scalar(@$tsSlice) . "\n";
        
        my ($windowSummary, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay, $tsSlice->[0]->{'ts'}, $tsSlice->[-1]->{'ts'});
        # Store summary in result
        push(@results, $windowSummary);
        
        $problemCount += $windowProblemCount;
                
        # reset vars at the end
        $windowStart = (@$timeseries - 1); 
        undef $windowMinDelay;
    }
    
    return (\@results, $problemCount);
}


# runs the whole suite of detection algorithms on a 5 second window
# add additional algorithms here
sub _detection_suite
{
    my ($self, $timeseries, $windowMinDelay, $sessionMinDelay, $startTimestamp, $endTimestamp) = @_;
    
    my $windowSummary = {
        'delayProblem' => 0,
        'lossProblem' => 0,
        'reorderProblem' => 0,
        'contextSwitch' => 0,
        'unsyncedClocks' => 0,
        'routeChange' => 0,
        
        'detectionCode' => 0,
        
        'firstTimestamp' => $startTimestamp,
        'lastTimestamp' => $endTimestamp,
        
        'packetCount' => 0,
        'windowMinDelay' => $windowMinDelay,
        
        'delayLimit' => 0,
        'delayAvg' => 0,
        'delayPerc' => 0,
        
        'lossCount' => 0,
        'lossPerc' => 0
         };
    
    my $problemCount = $self->_detectLossLatencyReordering($timeseries, $windowSummary, $sessionMinDelay);
    
    # Route change detection
    my ($routeChange) = $self->route_change_detect2($timeseries);
    if ($routeChange == 1)
    {
        $windowSummary->{'routeChange'} = 1;
    }
    
    # Call these functions only if there is a problem in this window
    if ($problemCount > 0)
    {
        # Context switch detection
        my ($contextSwitch) = $self->_detectContextSwitch($timeseries);
        if ($contextSwitch == 1)
        {
            $windowSummary->{'contextSwitch'} = 1;
            # reset problemcount here. Issues are due to context switch
            $problemCount = 0;
        }
    }
    
    # generate the detection code for output
    $windowSummary->{'detectionCode'} = $windowSummary->{'delayProblem'} << 1 | 
                                        $windowSummary->{'lossProblem'} << 2 |
                                        $windowSummary->{'routeChange'} << 4 |  
                                        $windowSummary->{'contextSwitch'} << 7 |
                                        $windowSummary->{'unsyncedClocks'} << 8;
    return ($windowSummary, $problemCount);
}

# detects problems in a 5 second window
# this is the base for detection
sub _detectLossLatencyReordering
{
    my ($self, $timeseries, $windowSummary, $sessionMinDelay) = @_;
    my $delayProblemCount = 0;
    my $lossProblemCount = 0;
    my $unsyncedClockCount = 0;
    my $delaySum = 0.0;
    
    if (scalar(@$timeseries) == 0)
    {
        return 0;
    }
    
    my $delayLimit;
    if (!defined($sessionMinDelay))
    {
        $delayLimit = 9999999999;
    }
    elsif ($self->{"_delayType"} eq "absolute")
    {
        $delayLimit = $sessionMinDelay + $self->{"_delayVal"}; 
    }
    elsif ($self->{"_delayType"} eq "relative")
    {
        $delayLimit = $sessionMinDelay * (1.0 + $self->{"_delayVal"});
    }
#    print $delayLimit . "\n";
    foreach my $item (@$timeseries)
    {
#        print Dumper($item);
#        print $item->{"delay"} . "\n";
        if ($item->{"lost"} == 1)
        {
            $lossProblemCount++;
        }
        elsif ($item->{"unsync"} == 1)
        {
            $unsyncedClockCount++;
        }
        else
        {
            if ($item->{"delay"} > $delayLimit)
            {
                $delayProblemCount++;
            }
            $delaySum += (1.0 * $item->{"delay"});
        }
    }
    
    # Processs delays in this window
    my $delayProblemFlag = 0;
    my $delayPerc = 0.0;
    my $delayAvg = 0.0;
    my $queueingDelay = 0.0;
    
    # Get the number of non-lost synchronised packets
    my $nonLostSyncCount = scalar(@$timeseries) - $lossProblemCount - $unsyncedClockCount; 
    if ($nonLostSyncCount > 0)
    {
        $delayPerc = ($delayProblemCount * 100.0)/$nonLostSyncCount;
        if ($delayPerc > $self->{"_delayThresh"})
        {
            $delayProblemFlag = 1;
        }
        
        $delayAvg = $delaySum/(scalar(@$timeseries) - $lossProblemCount);
        
        # TODO: We use the session minimum delay here. Need to check if this is sane to use after a route change
        if (defined($sessionMinDelay))
        {
            $queueingDelay = $delayAvg - $sessionMinDelay;
        }
        else
        {
            $queueingDelay = 0.0;
        }
    }
        
    # Process losses in this window
    my $lossProblemFlag = 0;
    my $lossPerc = ($lossProblemCount * 100.0)/scalar(@$timeseries);
    if ($lossPerc > $self->{"_lossThresh"})
    {
        $lossProblemFlag = 1;
    }
    
    # Process reordering in this window
    my $reorderProblemFlag = 0;
    # TODO: Use RFC method of calculating reordering 
    
    my $unsyncedClockFlag = 0;
    if ($unsyncedClockCount > 0)
    {
        $unsyncedClockFlag = 1;
    }
    
    # Update stats
    $windowSummary->{'delayProblem'} = $delayProblemFlag;
    $windowSummary->{'lossProblem'} = $lossProblemFlag;
    $windowSummary->{'reorderProblem'} = $reorderProblemFlag;
    $windowSummary->{'unsyncedClocks'} = $unsyncedClockFlag;
    
    $windowSummary->{'queueingDelay'} = $queueingDelay;
        
    $windowSummary->{'packetCount'} = scalar(@$timeseries);
        
    $windowSummary->{'delayLimit'} = $delayLimit;
    $windowSummary->{'delayAvg'} = $delayAvg;
    $windowSummary->{'delayPerc'} = $delayPerc;
        
    $windowSummary->{'lossCount'} = $lossProblemCount;
    $windowSummary->{'lossPerc'} = $lossPerc;
    
    # Note: Unsynced clocks is not a problem worth reporting (change if necessary)
    return ($delayProblemFlag + $lossProblemFlag + $reorderProblemFlag); 
}

# uses a histogram approach
sub route_change_detect
{
    my ($self, $in_timeseries) = @_;
    
    # filter the input timeseries to omit lost packets
    my @timeseries = map { $_->{'lost'} == 0 ? $_ : () } @{$in_timeseries};
    
    # Calculate bin size using Freedman-Diaconis rule
    my @sor = sort {$a->{"delay"} <=> $b->{"delay"}} @timeseries;
   
    my $nq1 = $sor[int(@timeseries/4)]->{"delay"};  # 1st quartile
    my $nq2 = $sor[int((3*@timeseries)/4)]->{"delay"}; # 3rd quartile
    my $bin_size = 2 * ($nq2 - $nq1) / int(@timeseries ** (1/3));

    # safety in case bin size is 0 for some reason    
    if ($bin_size == 0.0)
    {
        $bin_size = ($sor[-1]->{"delay"} - $sor[0]->{"delay"}) / 2;
    }
    
    # bin the results
    my $curr_bin = 0;
    my @bin_hist = ();
    my $bin_max = $sor[0]->{"delay"} + $bin_size;
    for (my $i = 0; $i < @sor; $i++)
    {
        next if ($sor[$i]->{"delay"} eq "");
        while ($bin_max < ($sor[$i]->{"delay"} * 1.0))
        {
            $curr_bin += 1;
            $bin_max += $bin_size;
        }
            
        $bin_hist[$curr_bin] += 1;
    }
#    print $curr_bin . " " . $sor[0]->{"delay"} . " " . $bin_size . "\n";
#    print Dumper(\@bin_hist);
#    print \@bin_hist;
    
    # get the max from the 2 largest bins
    my $max1 = 0;
    my $max1_idx;
    my $max2 = 0;
    my $max2_idx;
    for my $i (0 .. $#bin_hist)
    {
        my $bin_count = $bin_hist[$i];
        next if (!$bin_count);
        
        if ($bin_count > $max1)
        {
            if ($max1 > $max2)
            {
                $max2 = $max1; # save the old max in max2
                $max2_idx = $max1_idx;
            }
            $max1 = $bin_count;
            $max1_idx = $i;
        }
        elsif ($bin_count > $max2)
        {
            $max2 = $bin_count;
            $max2_idx = $i;
        }
    }
    
    if ($max1_idx && $max2_idx && abs($max2_idx - $max1_idx) != 1)
    {
        if (($max1 + $max2) / $#sor > $self->{"_routeChangeThresh"})
        {
            return 1;
        } 
    }
    return 0;
}

# uses a more traditional timeseries approach
# described in "On the Predictability of Large Transfer TCP Throughput" pg 152
# naive implementation, to be optimised
sub route_change_detect2
{
    my ($self, $in_timeseries) = @_;
    
    # Helper function that takes an array as input and outputs the median, min, max
    sub medianMinMax
    {
        my ($inArr) = @_;
        
        my @vals = sort {$a->{'delay'} <=> $b->{'delay'}} @{$inArr};
        my $len = scalar(@vals);
        my $med;
        if($len % 2 == 1) # odd
        {
            $med = $vals[int($len/2)]->{'delay'};
        }
        else # even
        {
            $med = ($vals[int($len/2)-1]->{'delay'} + $vals[int($len/2)]->{'delay'})/2;
        }
        return ($med, $vals[0]->{'delay'}, $vals[-1]->{'delay'});
    }
    
    # filter the input timeseries to omit lost packets
    my @timeseries = map { $_->{'lost'} == 0 ? $_ : () } @{$in_timeseries};
    
    # skip empty or short timeseries
    return 0 if (scalar(@timeseries) < 10);

    # loop over the timeseries until n-2
    for my $i (1.. (scalar(@timeseries) - 3))
    {
        my $tsSlice1 = [@timeseries[0 .. ($i - 1)]];
        my $tsSlice2 = [@timeseries[$i .. (scalar(@timeseries)-1) ]];
        
        my ($med1, $min1, $max1) = medianMinMax($tsSlice1);
        my ($med2, $min2, $max2) = medianMinMax($tsSlice2);
        
        # Conditions:
        # 1. All of region 2 is less than region 1 or all of region 2 is greater than region 1
        # 2. Difference in median for both is greater than threshold 
        if (($min1 > $max2 || $max1 < $min2) && 
            (abs($med1 - $med2) > $self->{'_routeChangeThresh'}))
        {
            $logger->debug("Route change detected. Magnitude: " . abs($med1 - $med2));
            return 1;
        }
    }
    return 0;
}

# detects context switches
# Works by detecting receiver timestamps being very close together,
# suggesting that the receiver is pulling packets out of a local 
# recieve buffer in memory
sub _detectContextSwitch
{
    my ($self, $timeseries) = @_;
    
    my $lastRcv = $timeseries->[0]{'rcvts'};
    my $counter = 0;
    for my $i (1.. scalar(@{$timeseries}))
    {
        my $rcvTs = $timeseries->[$i]{'rcvts'};
        
        next if (!defined($rcvTs));
        
        my $timediff = $rcvTs - $lastRcv;
        
        # increase counter if time difference is unrealistically small (1 microsecond)
        if ($timediff > 0 && $timediff < $self->{'_contextSwitchThresh'})
        {
            $counter += 1;
        }
        else # reset the counter
        {
            $counter = 0;
        }
        
        if ($counter > $self->{'_contextSwitchConsecPkts'})
        {
            $logger->debug("Context switch detected with $counter consecutive packets");
            return 1;
        }
        $lastRcv = $rcvTs;
    }
    return 0;
}

# removes very old incomplete bins
# used by detection algorithm
sub _purgeOldIncompleteBins
{
    my ($self) = @_;
    
    my $currtime = time;
    if ($currtime - $self->{'_incompleteBinsCullTime'} > 60) # more than a minute ago
    {
        print $self->{'_incompleteBinCullThresh'};
        
        $self->{'_incompleteBinsCullTime'} = $currtime;
    }
}

1;

