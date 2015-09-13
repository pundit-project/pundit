package myConfig;

use strict;

use Exporter;
use base 'Exporter';
our @EXPORT = qw($minWlen $maxWlen $dfield $tfield $sfield $rsfield $minProbDelay $maxInterProbGap $minProbDuration $minBinWidth $baseDensityThresh $minLowModeFrac $DATADIR $MINSCANDUR $peer_monitors $oldOwampThreshold $reportingDuration $tr_frequency);


### config
our $diagEnabled = 0; # 1 to enable diagnosis, 0 to disable
our $plotGraph = 0; # 1 to enable graph generation, 0 to disable

our $minWlen = 5; #s
our $maxWlen = 60; #s

our $minProbDelay = 5; #ms
our $maxInterProbGap = 1; #s
our $minProbDuration = 10; #s
our $minLowModeFrac = 0.3; # %

our $minBinWidth = 0.1; #ms
our $baseDensityThresh = 0.2; #density of lowest mode

our $dfield = 2; #s
our $tfield = 3; #s
our $sfield = 1; #s
our $rsfield = 4; #s
###

our $psVersion = "3.4";

if ($psVersion == "3.3")
{
	# perfSONAR 3.3-specific options
	our $DATADIR = "/var/lib/owamp/hierarchy/root/regular/";
	use lib '/opt/perfsonar_ps/perfsonarbuoy_ma/lib/';
}
else
{
	# perfSONAR 3.4-specific options
	our $DATADIR = "/var/lib/perfsonar/regular_testing/";
	use lib "/opt/perfsonar_ps/regular_testing/lib/";
}

our $MINSCANDUR = 300; #s

# More configuration options

# traceroute frequency in seconds
our $tr_frequency =  900;

# hostnames of peer monitors
our $peer_monitors = ["mon1", "mon2", "mon3"];

# When starting up, this is the number of hours in the backlogged owamp measurements to process. All older files will be deleted.
our $oldOwampThreshold = 0;

# The duration between updates for periodically reported check_mk variables 
our $reportingDuration = 60;

1;

