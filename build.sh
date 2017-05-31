#!/bin/bash

# Build requirements:
# - spectool
# - rpmbuild
# - yum install librabbitmq

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

echo Building pundit-central...
./pundit-central/build.sh

echo Building pundit-ui...
./pundit-ui/build.sh

echo Building rpms...
./rpmbuild/build.sh

echo Collecting rpm dependencies...
cd rpmbuild/RPMS/
# Take minimal Erlang as created for RabbitMQ
wget https://github.com/rabbitmq/erlang-rpm/releases/download/v19.3.4/erlang-19.3.4-1.el6.x86_64.rpm
# Take RabbitMQ
wget https://github.com/rabbitmq/rabbitmq-server/releases/download/rabbitmq_v3_6_10/rabbitmq-server-3.6.10-1.el6.noarch.rpm
