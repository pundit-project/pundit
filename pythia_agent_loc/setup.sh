#!/bin/bash
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

cd GaussianKernelEstimate
sh run.sh

cd owamp-3.3
sh run.sh

yum install perl-DBI.x86_64
yum install graphviz-perl.x86_64 perl-GraphViz.noarch
yum install perl-GDGraph.noarch

#perl events.pl $file $starttime $endtime

