#!/bin/bash


# Open port 5672 for use
iptables -I INPUT 1 -p tcp --dport 5672 -j ACCEPT

# Start rabbitmq-server
service rabbitmq-server start


# Create a new user credential
USER=pundit
RAND_STRING='date | md5sum'
PASSWORD=rabbit
#PASSWORD='echo ${RAND_STRING:0:14}'

echo "* Creating rabbitmq user $USER with password $PASSWORD"
rabbitmqctl add_user $USER $PASSWORD
rabbitmqctl set_permissions -p / $USER "." "." ".*"
rabbitmqctl set_user_tags $USER administrator
service rabbitmq-server restart

