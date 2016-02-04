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

package Detection;

use strict;

#use myConfig;
use Config::General;
use Data::Dumper;
require "detection_reporter.pm";

sub new
{
    my ($class, $cfg, $sitename) = @_;
    
    my %cfgHash = Config::General::ParseConfig($cfg);
    
    my ($delayVal, $delayType) = _parseTimeOrPercentage($cfgHash{"pundit_agent"}{$sitename}{"detection"}{"delay_max"});
    my ($delayThresh) = _parsePercentage($cfgHash{"pundit_agent"}{$sitename}{"detection"}{"delay_threshold"});
    my ($lossThresh) = _parsePercentage($cfgHash{"pundit_agent"}{$sitename}{"detection"}{"loss_threshold"});
    
    # initalize reporting here as well
    my $reporter = new Detection::Reporter($cfg, $sitename); 
    
    my $self = {
        '_reporter' => $reporter,
        
        '_delayVal' => $delayVal,
        '_delayType' => $delayType,
        '_delayThresh' => $delayThresh,
        
        '_lossThresh' => $lossThresh,
        '_routeChangeThresh' => 0.6,
        
        '_windowSize' => 5, # window size in seconds
        '_windowPackets' => 50, # expected number of packets in a window (fix this later)
        
        '_incompleteBinHash' => {}, # hash for holding incomplete bins
        '_incompleteBinCullThresh' => 30, # incomplete bins older than X minutes will be culled 
        '_incompleteBinCullTime' => 0, # last time incomplete entries were culled
    };
    
    bless $self, $class;
    return $self;
}


# entry point for external functions
sub processFile
{
    my ($self, $inputFile) = @_;
    
    # read the file
    my ($srchost, $dsthost, $timeseries, $sessionMinDelay) = $self->_readFile($inputFile);
    
    # perform detection and return a summary
    my ($summary, $problemFlags) = $self->_detection2($timeseries, $dsthost, $sessionMinDelay);

    my $startTime = _roundOff($timeseries->[0]{ts});
    my $statusMsg = {
        'srchost' => $srchost,
        'dsthost' => $dsthost,
        'startTime' => $startTime,
        'duration' => ($timeseries->[-1]{ts} - $timeseries->[0]{ts}),
        'baselineDelay' => $sessionMinDelay,
        'entries' => $summary,
    };

    $self->{'_reporter'}->writeStatus($statusMsg);
    
    return $problemFlags;
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
        $val = $1 / 100.0;
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

# reads an input owamp file
sub _readFile
{
    my ($self, $inputFile) = @_;
#    my ($self, $inputFile, $fileStartTime, $fileEndTime) = @_;
    
    my @timeseries = ();
    my $sessionMinDelay;
    
    # variabled used to overwrite delays due to self queueing 
    my ($prevTS, $prevDelay);
    
    my $srchost;
    my $dsthost;
    my $reorder_metric;
    my $lost_count;
    
    if (substr($inputFile, -3) eq "owp")
    {
        open(IN, "owstats -v -U $inputFile |") or die;
    }
    else # text file for debugging
    {
        open(IN, "$inputFile") or die;
    }
    
    while(my $line = <IN>)
    {
        if ($line =~/^--- owping statistics from \[(.+?)\]:\d+ to \[(.+?)\]\:\d+ ---$/)
        {
            $srchost = $1;
            $dsthost = $2;           
        }
        
        # grab a reordering metric if any. We calculate our own, so no need to preserve all values
        $reorder_metric = $1 if ($line =~/^\d*-reordering = ([0-9]*\.?[0-9]*)/);
        
        # grab the number of lost packets
        $lost_count = $1 if ($line =~ /^\d*\ssent, (\d*) lost/);
        
        # skip lines that are not owamp measurements
        next if $line !~ /^seq_no/; 
        
        chomp $line;
        
        # replace equals and tabs with spaces, then split on space
        $line =~ s/=/ /g; 
        $line =~ s/\t/ /g;
        my @obj = split(/\s+/, $line);

        # check for lost packet
        my $lost_flag = 0;
        my $delay = -1.0;
        if($line !~ /LOST/)
        {
#            # skip values that are out of range
#            next if $fileStartTime && $obj[10] < $fileStartTime;
#            last if $fileEndTime && $obj[10] > $fileEndTime;

            # Delay
            $delay = $obj[3] * 1.0; # This converts from scientific notation to decimal
            
            # update the minimum delay in this session
            if (!defined $sessionMinDelay || $delay < $sessionMinDelay)
            {
                $sessionMinDelay = $delay;
            }
        }
        else
        {
            # note sequence number of loss
            $lost_flag = 1;
        }
        
        my %elem = ();
        $elem{ts} = $obj[10] * 1.0; # sender timestamp
        $elem{rcvts} = $obj[12] * 1.0; # receiver timestamp
        $elem{seq} = $obj[1]; # original seq
        $elem{lost} = $lost_flag;
        
        # If 2 packets are sent too close to each other, likely induced self queueing 
        if (@timeseries > 0 && ($elem{ts} - $prevTS < 100e-6))
        {
            $elem{delay} = $prevDelay;
        }
        else
        {
            $elem{delay} = $delay;
        }
        
        # keep track of values to overwrite self queueing
        $prevDelay = $delay;
        $prevTS = $elem{ts};
        
        push(@timeseries, \%elem);
    }
    close IN;
    
    return ($srchost, $dsthost, \@timeseries, $sessionMinDelay);
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
    my ($self, $timeseries, $dsthost, $sessionMinDelay) = @_;
    
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
            
            print "tsSlice is " . scalar(@$tsSlice) . "\n";
            
            # combining bins at edge of measurements
            # store the first window if too few packets
            if ($windowStart == 0)
            {
                print "First bin is incomplete " . scalar(@$tsSlice) ."\n";
                
                # check whether there's a matching bin in the incomplete bin hash
                if (exists $self->{'_incompleteBinHash'}{$dsthost} &&
                    defined $self->{'_incompleteBinHash'}{$dsthost}{$currentBin})
                {
                    print "Found remainder in incompleteBinHash\n";
                    
                    my $incSlice = $self->{'_incompleteBinHash'}{$dsthost}{$currentBin};
                    
                    print "incSlice " . @$incSlice . " tsSlice " . @$tsSlice . "\n";
                    
                    push(@$incSlice, @$tsSlice); # combine the 2 arrays
                    undef $tsSlice;
                    delete $self->{'_incompleteBinHash'}{$dsthost}{$currentBin};
                    $tsSlice = $incSlice;
                    
                    my ($stats, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay);
                    # Store summary in result
                    push(@results, $stats);
                    
                    $problemCount += $windowProblemCount;
                }
                elsif ((scalar(@$tsSlice)/$self->{'_windowPackets'}) > 0.8) # process if greater than 80% full
                {
                    my ($stats, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay);
                    # Store summary in result
                    push(@results, $stats);
                    
                    $problemCount += $windowProblemCount;
                }
                else # store it in the incompleteBinHash if not enough samples
                {
                    print "Adding first packet to incompleteBinHash\n";
                    $self->{'_incompleteBinHash'}{$dsthost}{$currentBin} = $tsSlice;
                }
            }
            else
            {
                my ($stats, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay);
                # Store summary in result
                push(@results, $stats);
                
                $problemCount += $windowProblemCount;
            }
            
            $windowStart = $i; # update the window for the next loop
            $currentBin += $self->{'_windowSize'};
            $windowMinDelay = $timeseries->[$i]{delay}; # reset the value for the next loop
        }
        
        # get the min across the windows
        elsif ($timeseries->[$i]{delay} && ($windowMinDelay > $timeseries->[$i]{delay}))
        {
            $windowMinDelay = $timeseries->[$i]{delay}; 
        }
    }
    
    # process leftover entries
    if ($windowStart < (@$timeseries - 1))
    {
        my $tsSlice = [@$timeseries[$windowStart .. (@$timeseries - 1)]]; # this is the subset of the timeseries used for processing
        
        print "LAST: tsSlice is " . scalar(@$tsSlice) . "\n";
        
        # check whether there's a matching bin in the incomplete bin hash
        if (exists $self->{'_incompleteBinHash'}{$dsthost} &&
            defined $self->{'_incompleteBinHash'}{$dsthost}{$currentBin})
        {
            print "Found remainder in incompleteBinHash\n";
            
            my $incSlice = $self->{'_incompleteBinHash'}{$dsthost}{$currentBin};
            
            print "incSlice " . @$incSlice . " tsSlice " . @$tsSlice . "\n";
            
            push(@$tsSlice, @$incSlice); # combine the 2 arrays
            undef $incSlice;
            delete $self->{'_incompleteBinHash'}{$dsthost}{$currentBin};
            
            my ($stats, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay);
            # Store summary in result
            push(@results, $stats);
            
            $problemCount += $windowProblemCount;
        }
        elsif ((scalar(@$tsSlice)/$self->{'_windowPackets'}) > 0.8 ) # process if greater than 80% full
        {
            my ($stats, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay);
            # Store summary in result
            push(@results, $stats);
            
            $problemCount += $windowProblemCount;
        }
        else # store it in the incompleteBinHash 
        {
            print "Adding last packet to incompleteBinHash\n";
            $self->{'_incompleteBinHash'}{$dsthost}{$currentBin} = $tsSlice;
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
    my ($self, $timeseries, $dsthost, $sessionMinDelay) = @_;
    
    ### Output variables
    # min delay in the window
    my $windowMinDelay = $timeseries->[0]{delay};
    # array that holds the per 5 second detection results
    my @results = ();
    
    # duration of the session
    my $sessionDuration = $timeseries->[-1]{ts} - $timeseries->[0]{ts};
    # number of windows of approximately windowSize
    my $windowCount = _roundOff($sessionDuration/$self->{'_windowSize'});
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
            
            my ($stats, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay);
            # Store summary in result
            push(@results, $stats);
            
            $problemCount += $windowProblemCount;
            
            $windowStart = $i; # update the window for the next loop
            
            $windowMinDelay = $timeseries->[$i]{delay}; # reset the value for the next loop
        }
        
        # get the min across the windows
        elsif ($timeseries->[$i]{delay} && ($windowMinDelay > $timeseries->[$i]{delay}))
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
        
        my ($stats, $windowProblemCount) = $self->_detection_suite($tsSlice, $windowMinDelay, $sessionMinDelay);
        # Store summary in result
        push(@results, $stats);
        
        $problemCount += $windowProblemCount;
                
        # reset vars at the end
        $windowStart = (@$timeseries - 1); 
        undef $windowMinDelay;
    }
    
    return (\@results, $problemCount);
}


# runs the whole suite of detection algorithms
sub _detection_suite
{
    my ($self, $timeseries, $windowMinDelay, $sessionMinDelay) = @_;
    
    my ($stats, $problemCount) = $self->_detect_problems($timeseries, $windowMinDelay, $sessionMinDelay);
            
        # disabled
#       my ($ret) = $self->route_change_detect($tsSlice);
#       print $ret . "\n";
    return ($stats, $problemCount);
}

# detects problems in a 5 second window
sub _detect_problems
{
    my ($self, $timeseries, $windowMinDelay, $sessionMinDelay) = @_;
    my $delayProblemCount = 0;
    my $lossProblemCount = 0;
    my $delaySum = 0.0;
    
    if (scalar(@$timeseries) == 0)
    {
        return ({
        'delayProblem' => 0,
        'lossProblem' => 0,
        'reorderProblem' => 0,
        
        'firstTimestamp' => 0,
        'lastTimestamp' => 0,
        
        'packetCount' => 0,
        'windowMinDelay' => $windowMinDelay,
        
        'delayLimit' => 0,
        'delayAvg' => 0,
        'delayPerc' => 0,
        
        'lossCount' => 0,
        'lossPerc' => 0
         }, 
         0);
    }
    
    my $delayLimit;
    if ($self->{"_delayType"} eq "absolute")
    {
        $delayLimit = $windowMinDelay + $self->{"_delayVal"}; 
    }
    elsif ($self->{"_delayType"} eq "relative")
    {
        $delayLimit = $windowMinDelay * (1.0 + $self->{"_delayVal"});
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
    if ((scalar(@$timeseries) - $lossProblemCount) > 0) # only count non-lost packets
    {
        $delayPerc = ($delayProblemCount * 1.0)/(scalar(@$timeseries) - $lossProblemCount);
        if ($delayPerc > $self->{"_delayThresh"})
        {
            $delayProblemFlag = 1;
        }
        
        $delayAvg = $delaySum/(scalar(@$timeseries) - $lossProblemCount);
        
        # TODO: We use the session minimum delay here. Need to check if this is sane to use after a route change
        $queueingDelay = $delayAvg - $sessionMinDelay;
    }
        
    # Process losses in this window
    my $lossProblemFlag = 0;
    my $lossPerc = ($lossProblemCount * 1.0)/scalar(@$timeseries);
    if ($lossPerc > $self->{"_lossThresh"})
    {
        $lossProblemFlag = 1;
    }
    
    # Process reordering in this window
    my $reorderProblemFlag = 0;
    # TODO: Use RFC method of calculating reordering 
    
    # Summarise stats
    my $stats = {
        'delayProblem' => $delayProblemFlag,
        'lossProblem' => $lossProblemFlag,
        'reorderProblem' => $reorderProblemFlag,
        
        'queueingDelay' => $queueingDelay,
        
        'firstTimestamp' => $timeseries->[0]->{'ts'},
        'lastTimestamp' => $timeseries->[-1]->{'ts'},
        
        'packetCount' => scalar(@$timeseries),
        'windowMinDelay' => $windowMinDelay,
        
        'delayLimit' => $delayLimit,
        'delayAvg' => $delayAvg,
        'delayPerc' => $delayPerc,
        
        'lossCount' => $lossProblemCount,
        'lossPerc' => $lossPerc
         };
    
    return ($stats, $delayProblemFlag + $lossProblemFlag + $reorderProblemFlag); 
}

# uses a histogram approach
sub route_change_detect
{
    my ($self, $timeseries) = @_;
    
    # Calculate bin size using Freedman-Diaconis rule
    my @sor=sort {$a->{"delay"} <=> $b->{"delay"}} @{$timeseries};
    while ($sor[0]->{"delay"} eq "") # filter off losses
    {
        shift @sor;
    }
    my $nq1=$sor[int(@$timeseries/4)]->{"delay"};  # 1st quartile
    my $nq2=$sor[int((3*@$timeseries)/4)]->{"delay"}; # 3rd quartile
    my $bin_size = 2 * ($nq2 - $nq1) / int(@$timeseries ** (1/3));

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
sub route_change_detect2
{
    
}

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
