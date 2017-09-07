#!/bin/bash
#
# Reinstalls PuNDIT-Agent
#  -  Commands originally from Eulyeon Ko
#
# Shawn McKee <smckee@umich.edu> Sep 7, 2017
#=============================================

echo "Reinstalling the PuNDIT Agent...stopping any relevant running services..."
sudo service pundit-agent stop
sudo service rabbitmq-server stop

echo " Removing packages..."
sudo yum -y remove pundit-agent rabbitmq-server

cd

echo " Cleaning up any remnants..."
sudo rm -rf /var/lib/rabbitmq
sudo rm -rf /opt/pundit-agent
sudo rm -f /var/log/perfsonar/pundit-agent.log*
sudo rm -rf /var/log/perfsonar/savedProblems/

echo " Reinstall packages..."
sudo yum --enablerepo=pundit clean metadata 
# Note pundit-agent depends upon rabbitmq-server and its install will install both
sudo yum -y install pundit-agent

echo " Start rabbitmq-server..."
chown -R rabbitmq.rabbitmq /var/log/rabbitmq
sudo service rabbitmq-server start

echo " Initialize PuNDIT-Agent..."
sudo /opt/pundit-agent/bin/initialize-pundit-agent.sh http://pundit.aglt2.org:8080/pundit-agent.credentials

echo " Checking pundit-agent.log..."
tail -n200 /var/log/perfsonar/pundit-agent.log

echo "Finished!"
exit

