#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Open port 5672 for use
iptables -I INPUT 1 -p tcp --dport 5672 -j ACCEPT
/sbin/service iptables save

# Start rabbitmq-server
service rabbitmq-server start

# Create a new user credential
CENTRAL_HOST=`hostname`
CENTRAL_USER=pundit-central
CENTRAL_PASSWORD=`openssl rand -base64 12 | sed -e 's/[\/+&]/A/g'`
AGENT_USER=pundit-agent
AGENT_PASSWORD=`openssl rand -base64 12 | sed -e 's/[\/+&]/A/g'`

echo "* Creating rabbitmq user $CENTRAL_USER with password $CENTRAL_PASSWORD"
rabbitmqctl add_user $CENTRAL_USER $CENTRAL_PASSWORD
rabbitmqctl set_permissions -p / $CENTRAL_USER "." "." ".*"
rabbitmqctl set_user_tags $CENTRAL_USER administrator
echo "* Creating rabbitmq user $AGENT_USER with password $AGENT_PASSWORD"
rabbitmqctl add_user $AGENT_USER $AGENT_PASSWORD
rabbitmqctl set_permissions -p / $AGENT_USER "." "." ".*"
service rabbitmq-server restart

echo "* Saving rabbitmq username and password in configuration file"

cat ../etc/pundit-central.conf.template | sed "s/<replace-rabbitmq-host-here>/$CENTRAL_HOST/g" | sed "s/<replace-rabbitmq-user-here>/$CENTRAL_USER/g" | sed "s/<replace-rabbitmq-user-password-here>/$CENTRAL_PASSWORD/g" > ../etc/pundit-central.conf
chmod 600 ../etc/pundit-central.conf

