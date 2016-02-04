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
package InfileScheduler;

require "check_mk_reporter.pm";

use Data::Dumper;
use File::Find;
use File::Copy;
use File::Basename;
        
# creates a new infile scheduler, which calls the detection object on the files in the specified path 
sub new
{
    # TODO: If we want to support multiple measurement federations, we should change this to take a hash mapping sites to detObj
    # The corresponding endpoint names to sites should be available in the config file 
    my ($class, $cfg, $detObj) = @_;
    
    # initialise check mk reporter to periodically write stats
    my $checkMkReporter = new CheckMkReporter($cfg);
    
    my %cfgHash = Config::General::ParseConfig($cfg);
    
    my ($owampPath) = $cfgHash{"pundit_agent"}{"owamp_data"}{"path"};
    
    my $self = {
        _det => $detObj,
        _owampPath => $owampPath,
        
        _saveProblems => 1, # flag to indicate whether or not owps with problems will be saved
        _saveProblemsPath => "/opt/pythia/savedProblems", # path where owps with detected problems will be saved
        
        _runTrace => 0, # flag that indicates 
        
        _checkMkReporter => $checkMkReporter,
    };
    
    bless $self, $class;
    return $self;
}

# Public Method. Runs a single iteration of the schedule 
# Call this only in a loop with a sleep() operation 
sub runSchedule
{
    my ($self) = @_;
    
    my $infiles = $self->_getFiles();
    
    # no files. just quit
    return if (!@$infiles);
    
    my $processCount = $self->_processFiles($infiles);
    
    print "processed " . $processCount . " files\n";
    $self->{'_checkMkReporter'}->reportProcessedCount($processCount);
}


# Scans the owamp directory to find owp files for processing
# Returns the list of files sorted from oldest to newest
sub _getFiles
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

sub _processFiles
{
    my ($self, $infiles) = @_;
       
    my $processCount = 0;
    
    foreach my $filename (@$infiles)
    {
        my $return = $self->_processOwpfile($filename);
        
        # TODO: Handle problematic files here (i.e., those that return nonzero values)
        
        $processCount += 1;
    }
    return $processCount;
}

sub _processOwpfile
{
    my ($self, $filepath) = @_;
    
    # sanity check
    if (!-e $filepath)
    {
        print "$filepath doesn't exist! Bailing...\n";
        return -1;
    }

    # bail if file is still open 
    if (`lsof $filepath`)
    {
        print "$filepath is still open. Bailing...\n";
        return -2;
    }
    
    # TODO: Find the matching measurement federation and call the processFile function of that corresponding object
    print time . " Processing $filepath...\n";
    my $return = $self->{'_det'}->processFile($filepath); # returns the number of problems detected
    
    if ($return != 0 && $self->{'runTrace'})
    {
        # TODO: Run the trace here, either by calling bwctl or by running the traceroute manually
    }
     
    if ($return != 0 && $self->{'_saveProblems'})
    {
        # save the file somewhere
        my($filename, $dirs, $suffix) = fileparse($filepath);
        
        move($filepath, $self->{'_saveProblemsPath'} . '/' . $filename . $suffix);
    }
    else # delete it
    {
        unlink $filepath;
    }
    return 0; # return ok 
}

1;