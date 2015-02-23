package myConfig;

use strict;

use Exporter;
use base 'Exporter';
our @EXPORT = qw($minWlen $maxWlen $dfield $tfield $sfield $rsfield $minProbDelay $maxInterProbGap $minProbDuration $minBinWidth $baseDensityThresh $minLowModeFrac $DATADIR $MINSCANDUR);


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
	# perfSONAR 3.3
	our $DATADIR = "/var/lib/owamp/hierarchy/root/regular/";
	use lib '/opt/perfsonar_ps/perfsonarbuoy_ma/lib/';
}
else
{
	# perfSONAR 3.4
	our $DATADIR = "/var/lib/perfsonar/regular_testing/";
	use lib "/opt/perfsonar_ps/regular_testing/lib/";
}

#our $DATADIR = "/tmp/owp/";
our $MINSCANDUR = 300; #s


1;

