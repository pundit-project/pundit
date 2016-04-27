#!/usr/bin/perl -w
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

use strict;

use Carp;
use Getopt::Long;
use English '-no_match_vars';
use Fcntl qw(:DEFAULT :flock);
use Log::Log4perl qw(:easy);
use POSIX qw(setsid);
use Config::General;
use FindBin qw( $RealBin );

use lib "$RealBin/../lib";

use PuNDIT::Central::Master;

my $CONFIG_FILE = "$RealBin/../etc/pundit_central.conf";
my $PID_DIR  = "/var/run";
my $PID_FILE = "pundit_central.pid";
my $LOGGER_CONF;
my $DEBUGFLAG;
my $DAEMONIZE;
my $USER;
my $GROUP;
my $HELP;
my $LOGFILE;

my ( $status, $cfgHash );
my $pid_file;
my $logger;

$status = GetOptions(
    'config=s'    => \$CONFIG_FILE,
    'pidfile=s'   => \$PID_FILE,
    'user=s'      => \$USER,
    'group=s'     => \$GROUP,
    'piddir=s'    => \$PID_DIR,
    'logger=s'    => \$LOGGER_CONF,
    'daemonize'   => \$DAEMONIZE,
    'verbose'     => \$DEBUGFLAG,
    'help'        => \$HELP,
    'logfile=s'   => \$LOGFILE,
);

# Check for an existing instance before we drop privileges
if ($DAEMONIZE) {
   $pid_file = lockPIDFile( $PID_DIR, $PID_FILE );
}

# Drop the privileges early so that we know the logging, etc. will be writeable
# after we've dropped privileges.
if ( $USER and $GROUP ) {
    if ( setids( USER => $USER, GROUP => $GROUP ) != 0 ) {
        print "Error: Couldn't drop privileges\n";
        exit( -1 );
    }
}
elsif ( $USER or $GROUP ) {
    # they need to specify both the user and group
    print "Error: You need to specify both the user and group if you specify either\n";
    exit( -1 );
}

($status, $cfgHash) = parseConfig($CONFIG_FILE);
if ($status != 0) {
    $logger->error("Problem parsing configuration file: $CONFIG_FILE");
    exit(-1);
}

unless ( $LOGFILE ) {
    $LOGFILE = $cfgHash->{'pundit_central'}{'log'}{'filename'};
}

unless ( $LOGGER_CONF ) {
    use Log::Log4perl qw(:easy);

    my %logger_opts = (
        level  => ($DEBUGFLAG?$DEBUG:$ERROR),
        layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
    );
    
    if ($LOGFILE)
    {
        $logger_opts{'file'} = ">$LOGFILE";
    }

    Log::Log4perl->easy_init( \%logger_opts );
}
else {
    use Log::Log4perl qw(get_logger :levels);

    Log::Log4perl->init( $LOGGER_CONF );
}

$logger = get_logger( "PuNDIT" );

# Before daemonizing, set die and warn handlers so that any Perl errors or
# warnings make it into the logs.
my $insig = 0;
$SIG{__WARN__} = sub {
    $logger->warn("Warned: ".join( '', @_ ));
    return;
};

$SIG{__DIE__} = sub {                       ## still dies upon return
    die @_ if $^S;                      ## see perldoc -f die perlfunc
    die @_ if $insig;                   ## protect against reentrance.
    $insig = 1;
    $logger->error("Died: ".join( '', @_ ));
    $insig = 0;
    return;
};
    
if ($DAEMONIZE) {
   daemonize();

   unlockPIDFile($pid_file);
}

my $master = new PuNDIT::Central::Master($cfgHash);
if (!$master)
{
    $logger->error("Problem initializing PuNDIT Central Server, master couldn't be initialized");
    exit(-1);
}

$master->run();

=head2 daemonize
Sends the program to the background by eliminating ties to the calling terminal.
=cut

sub daemonize {
    chdir '/' or croak "Can't chdir to /: $!";
    open STDIN,  '/dev/null'   or croak "Can't read /dev/null: $!";
    open STDOUT, '>>/dev/null' or croak "Can't write to /dev/null: $!";
    open STDERR, '>>/dev/null' or croak "Can't write to /dev/null: $!";
    defined( my $pid = fork ) or croak "Can't fork: $!";
    exit if $pid;
    setsid or croak "Can't start a new session: $!";
    umask 0;
    return;
}


=head2 setids
Sets the user/group for the daemon to run as. Returns 0 on success and -1 on
failure.
=cut

sub setids {
    my ( %args ) = @_;
    my ( $uid,  $gid );
    my ( $unam, $gnam );

    $uid = $args{'USER'}  if exists $args{'USER'}  and $args{'USER'};
    $gid = $args{'GROUP'} if exists $args{'GROUP'} and $args{'GROUP'};
    return -1 unless $uid;

    # Don't do anything if we are not running as root.
    return if ( $EFFECTIVE_USER_ID != 0 );

    # set GID first to ensure we still have permissions to.
    if ( $gid ) {
        if ( $gid =~ /\D/ ) {

            # If there are any non-digits, it is a groupname.
            $gid = getgrnam( $gnam = $gid );
            if ( not $gid ) {
                print "Can't getgrnam($gnam): $!\n" ;
                return -1;
            }
        }
        elsif ( $gid < 0 ) {
            $gid = -$gid;
        }

        if ( not getgrgid( $gid ) ) {
            $logger->error( "Invalid GID: $gid" );
            return -1;
        }

        $EFFECTIVE_GROUP_ID = "$gid $gid";
        $REAL_GROUP_ID = $gid;
    }

    # Now set UID
    if ( $uid =~ /\D/ ) {

        # If there are any non-digits, it is a username.
        $uid = getpwnam( $unam = $uid );
        if ( not $uid ) {
            $logger->error( "Can't getpwnam($unam): $!" );
            return -1;
        }
    }
    elsif ( $uid < 0 ) {
        $uid = -$uid;
    }

    if ( not getpwuid( $uid ) ) {
        $logger->error( "Invalid UID: $uid" );
        return -1;
    }

    $EFFECTIVE_USER_ID = $REAL_USER_ID = $uid;

    return 0;
}

=head2 parseConfig($cfgPath);
Simple configuration parser
=cut
sub parseConfig
{
    my ($configFile) = @_;
    my %cfgHash = Config::General::ParseConfig($configFile);

    # do sanity check that the config file exists
    if ( ! -e "$configFile" || !%cfgHash) {
        return (-1, undef);
    }
    
    return (0, \%cfgHash);    
}

=head2 lockPIDFile($piddir, $pidfile);
The lockPIDFile function checks for the existence of the specified file in the
specified directory. If found, it checks to see if the process in the file still
exists. If there is no running process, it returns the filehandle for the open
pidfile that has been flock(LOCK_EX).
=cut

sub lockPIDFile {
    my ( $piddir, $pidfile ) = @_;
    croak "Can't write pidfile: $piddir/$pidfile\n" unless -w $piddir;
    $pidfile = $piddir . "/" . $pidfile;
    sysopen( PIDFILE, $pidfile, O_RDWR | O_CREAT ) or croak( "Couldn't open pidfile" );
    flock( PIDFILE, LOCK_EX ) or croak( "Couldn't lock pidfile" );
    my $p_id = <PIDFILE>;
    chomp( $p_id ) if $p_id;

    if ( $p_id and kill( 0, $p_id )) {
        croak "$PROGRAM_NAME already running: $p_id\n";
    }

    # write the current process in if we're locking it, and then unlock the PID
    # file so that others can try their luck. XXX: there's a minor race
    # condition during the 'daemonize' call.

    truncate( PIDFILE, 0 );
    seek( PIDFILE, 0, 0 );
    print PIDFILE "$PROCESS_ID\n";
    flock( PIDFILE, LOCK_UN );

    return *PIDFILE;
}

=head2 unlockPIDFile
This file writes the pid of the call process to the filehandle passed in,
unlocks the file and closes it.
=cut

sub unlockPIDFile {
    my ( $filehandle ) = @_;

    flock( PIDFILE, LOCK_EX ) or croak( "Couldn't lock pidfile" );

    truncate( $filehandle, 0 );
    seek( $filehandle, 0, 0 );
    print $filehandle "$PROCESS_ID\n";
    flock( $filehandle, LOCK_UN );
    close( $filehandle );

    $logger->debug( "Unlocked pid file" );

    return;
}

