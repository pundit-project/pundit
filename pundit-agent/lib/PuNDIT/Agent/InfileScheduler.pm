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

# handles input file detection and queueing
package PuNDIT::Agent::InfileScheduler;

use strict;
use Log::Log4perl qw(get_logger);
use File::Find;
use File::Copy;
use File::Basename;
use Data::Dumper; # used for dumping stats

#use PuNDIT::Agent::InfileScheduler::CheckMkReporter;
# TODO NEXT
#use PuNDIT::Agent::LocalizationTraceroute;
use PuNDIT::Utils::HostInfo;

my $logger = get_logger(__PACKAGE__);

# creates a new infile scheduler, which calls the detection object on the files in the specified path 
sub new
{
    my ($class, $cfgHash, $detHash) = @_;
    
    # initialise check mk reporter to periodically write stats
    # my $checkMkReporter = new PuNDIT::Agent::InfileScheduler::CheckMkReporter($cfgHash);
    
    #my $owampPath = $cfgHash->{"pundit_agent"}{"owamp_data"}{"path"};
    
    # debug flags 
    # my $saveProblems = $cfgHash->{"pundit_agent"}{"owamp_data"}{"save_problems"};
    # my $saveProblemsPath = $cfgHash->{"pundit_agent"}{"owamp_data"}{"save_problems_path"};
    
    # sanity check the owamp path
    # if (!($owampPath && -e $owampPath))
    # {
    #     $logger->error("owamp_data:path doesn't exist or is invalid. Quitting!");
    #     return undef;
    # }
    
    my $hostId = PuNDIT::Utils::HostInfo::getHostId();

    my $self = {        
        _hostId => $hostId,

        _detHash => $detHash,
        # _owampPath => $owampPath,
        
        # flag to indicate whether or not owps with problems will be saved
        # _saveProblems => $saveProblems, 
        # _saveProblemsPath => $saveProblemsPath, # path where owps with detected problems will be saved
        
        # flag that indicates whether a traceroute should be run after a problem is detected
        _runTrace => 0, 
        
        # _checkMkReporter => $checkMkReporter,
    };
    
    bless $self, $class;
    return $self;
}

# Public Method. Runs a single iteration of the schedule 
# Call this only in a loop with a sleep() operation 
sub runSchedule
{
    my ($self, $dataIn) = @_;
    
    # my $owpFiles = $self->_getOwpFiles();
    
    # no files. just quit
    # return if (!@$owpFiles);
    
    # my $processCount = $self->_processFiles($owpFiles);
    $self->_processFiles($dataIn);
    # $logger->debug("processed " . $processCount . " files");
    # $self->{'_checkMkReporter'}->reportProcessedCount($processCount);
}

# No longer processes "files" after adopting rabbitmq
# it processes a message as it arrives.
sub _processFiles
{
    # my ($self, $infiles) = @_;
    my ($self, $dataIn) = @_;
       
    # my $processCount = 0;
    
    # foreach my $filename (@$infiles)
    # {
    #   my $return = $self->_processOwpfile($filename);
        
        # $processCount += 1;
    # }
    # return $processCount;

    my $return = $self->_processOwpfile($dataIn);
}

# processes an owamp file here. Deletes the file when done with it.
sub _processOwpfile
{
    my ($self, $dataIn) = @_;
    
    $logger->debug("Processing $dataIn");
    
    while (my ($fedName, $detObj) = each (%{$self->{'_detHash'}}))
    {
        # each detobj will know whether the owamp file belongs to the federation
        # $return - the number of problems detected, 0 or -1 (not a member of federation)
        # $stats - status summary generated from this file
        # my ($return, $stats) = $detObj->processFile($filePath); 
        my ($return, $stats) = $detObj->processFile($dataIn); 
        
        # One or more problems were detected
        if ($return > 0)
        {
            $logger->info("$fedName analysis: $return problems for " . $stats->{'srcHost'} . " to "  . $stats->{'dstHost'});

            
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
        }
    }

    # we're done with the owamp file. Delete it.    
    #unlink $filePath;
    
    return 0; # return ok 
}

# This function is comparable to _processOwpfile
sub _processMsg
{
    my ($self, $dataIn) = @_;


}


sub _processLatency {

    my ($self, $raw_json) = @_;

    while (my ($fedName, $detObj) = each (%{$self->{'_detHash'}})) {

        # the following two lines could kill performance.
        my ($srcHost, $dstHost, $timeseries, $sessionMinDelay) = $self->_parseJson($raw_json); 
        $logger->debug("Parsed: " . $srcHost . " / " . $dstHost . " / " . $sessionMinDelay);

        # continue if either srcHost or dstHost is not a member of federation
        if ($detObj->isNotInFederation($srcHost, $dstHost)) {
             next;
        }

        # $return - the number of problems detected, 0
        # $stats - status summary generated from this file
        my ($summary, $problemFlags) = $detObj->_detection($timeseries, $dstHost,  $sessionMinDelay); 
        $logger->debug("problemFlags: ", $problemFlags);

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

        # Report the result to the pundit-central.
        ${$self->{'_reporterHash'}}{$fedName}->writeStatus($statusMsg);
   
        # One or more problems were detected
        if ($problemFlags > 0) {
            $logger->info("$fedName analysis: $problemFlags problems for " . $statusMsg->{'srcHost'} . " to "  . $statusMsg->{'dstHost'});
            foreach (@{$summary}) {
                $logger->debug(Dumper($_));
            }
        }         
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

    return 0;
}


# TODO possible removal
# Scans the owamp directory to find owp files for processing
# Returns the list of files sorted from oldest to newest
sub _getOwpFiles
{
    my ($self) = @_;

    my @owpfiles = glob($self->{"_owampPath"} . "owamp_*/*.owp"); # get all owp files in the regular testing directory

    # multi-operation sort. Order of precedence is from innermost to outermost
    my @result =     
        map  { $_->[1] }                # Step 3: Discard the sort value and get the original value back
        sort { $a->[0] <=> $b->[0] }    # Step 2: Sort arrayrefs numerically on the sort value
        map  { /\/(\d+?)_\d+?\.owp$/; [$1, $_] } # Step 1: Build arrayref of the sort value and orig pairs
        @owpfiles;
        
    return \@result;
}

# Scans the owamp directory to find json files for processing
# Returns the list of files sorted from oldest to newest
#sub _getJsonFiles
#{
#    my ($self) = @_;

#    my @jsonFiles = glob($self->{"_owampPath"} . "/*.json"); # get all json files in the archiver directory
    
    # multi-operation sort. Order of precedence is from innermost to outermost
#    my @result =     
#        map  { $_->[1] }                # Step 3: Discard the sort value and get the original value back
#        sort { $a->[0] <=> $b->[0] }    # Step 2: Sort arrayrefs numerically on the sort value
#        map  { /\/(\d+?)_[\d\w\-]+?\.json$/; [$1, $_] } # Step 1: Build arrayref of the sort value and orig pairs
#        @owpfiles;
        
#    return \@jsonFiles;
#}

