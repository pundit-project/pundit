#!perl -w
#
# Copyright 2012 Georgia Institute of Technology
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

require 'symptomdiag.pl';

sub diagnosisTree {
	my $diagstr = "";

	if ( DelayExist() == 1 ) {
		if ( LargeTriangle() == 1 ) {
			$diagstr .= "ContextSwitch<BR>";
		}
		if ( UnipointPeaks() == 2 ) {
			if ( LargeTriangle() == 2 ) {
				if ( LossExist() == 2 ) {
					if ( DelayLevelShift() == 2 ) {
						if ( HighDelayIQR() == 1 ) {
							$diagstr .= "LargeBuffer<BR>";
						}
					}
				}
				if ( DelayLevelShift() == 2 ) {
					if ( HighDelayIQR() == 2 ) {
						if ( HighUtil() == 1 ) {
							if ( BurstyDelays() == 1 ) {
								$diagstr .= "CongestionBursty<BR>";
							}
							if ( BurstyDelays() == 2 ) {
								$diagstr .= "CongestionOverload<BR>";
							}
						}
					}
				}
				if ( DelayLevelShift() == 1 ) {
					$diagstr .= "RouteNTPChange<BR>";
				}
				if ( LossExist() == 1 ) {
					if ( DelayLevelShift() == 2 ) {
						if ( HighDelayIQR() == 1 ) {
							if ( DelayLossCorr() == 1 ) {
								$diagstr .= "LargeBuffer<BR>";
							}
						}
						if ( DelayLossCorr() == 1 ) {
							if ( LowDelayIQR() == 1 ) {
								$diagstr .= "SmallBuffer<BR>";
							}
						}
					}
				}
			}
		}
		if ( UnipointPeaks() == 1 ) {
			$diagstr .= "EndHostNoise<BR>";
		}
	}
	if ( LossExist() == 1 ) {
		if ( DelayLossCorr() == 1 ) {
			$diagstr .= "DelayCorrelatedLoss<BR>";
		}
		if ( DelayLossCorr() == 2 ) {
			$diagstr .= "RandomLoss<BR>";
		}
		if ( LossEventSmallDur() == 1 ) {
			$diagstr .= "ShortOutage<BR>";
		}
	}
	if ( ReorderShift() == 1 ) {
		if ( ReorderExist() == 1 ) {
			$diagstr .= "ReorderUnstable<BR>";
		}
	}
	if ( ReorderShift() == 2 ) {
		if ( ReorderExist() == 1 ) {
			$diagstr .= "ReorderPersistent<BR>";
		}
	}
	$diagstr = "Unknown<BR>" if $diagstr =~ /^$/;
	return $diagstr;
}

1;