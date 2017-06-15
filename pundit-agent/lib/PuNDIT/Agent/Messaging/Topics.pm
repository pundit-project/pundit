#Copyright 2016 Georgia Institute of Technology
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

package PuNDIT::Agent::Messaging::Topics;

# Module to set up a message queuing system using Net::AMQP::RabbitMQ.
# The messaging scheme used here is based on a topic exchange.

use strict;

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);
