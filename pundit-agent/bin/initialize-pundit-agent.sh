#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Argument checking
if [ $# -ne 1 ]; then
	echo "* This script takes in only 1 argument(URL or filename)"
	echo "* Example: initialize-pundit-agent.sh http://pundit.aglt2.org/pundit-agent.credentials"
	exit 1
fi

filename=$1
isUrl=false
#Check whether the given argument is a valid url, if not assume it is a local filepath.
regex='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
if [[ $1 =~ $regex ]]; then
	filename="${1##*/}"
	wget "$1"
	isUrl=true
	mv $filename /tmp/$filename
	filename=/tmp/$filename
fi

if [ -f $filename ]; then 
	CENTRAL_HOSTNAME=$(awk -F"=" /\central-hostname/'{print $2}' $filename)
	#rabbitmq user/pass assigned to the agent for use by the central host.
	CENTRAL_USER=$(awk -F"=" /\agent-user/'{print $2}' $filename)
	CENTRAL_PASSWORD=$(awk -F"=" /\agent-password/'{print $2}' $filename)
	AGENT_PEERS=$(awk -F"=" /\agent-peers/'{print $2}' $filename)
	
	if [ "$isUrl" = true ]; then
		rm $filename
	fi
else
	echo "* Couldn't open $filename"
	exit 1
fi

PERFSONAR_HOSTNAME="$HOSTNAME"
CHANNEL=3
ROUTING_KEY='pundit.status'
EXCHANGE=status
# pundit-agent.conf
echo "* Configuring pundit-agent daemon"
cat ../etc/pundit-agent.conf.template | sed "s/<add-src-host-here>/$PERFSONAR_HOSTNAME/g" | sed "s/<add-consumer-host-name-here>/$CENTRAL_HOSTNAME/g" | sed "s/<add-rabbitmq-user-here>/$CENTRAL_USER/g" | sed "s/<add-rabbitmq-user-password-here>/$CENTRAL_PASSWORD/g" | sed "s/<add-channel-number-here>/$CHANNEL/g" | sed "s/<add-routing-key-here>/$ROUTING_KEY/g" | sed "s/<add-exchange-name-here>/$EXCHANGE/g" | sed "s/<add-comma-delimited-list-of-hostnames-here>/$AGENT_PEERS/g" > ../etc/pundit-agent.conf
chmod 644 ../etc/pundit-agent.conf

#Setting up rabbitmq user
LOCAL_USER=pundit-agent
LOCAL_PASSWORD=`openssl rand -base64 12 | sed -e 's/[\/+&]/A/g'`


# Check RabbitMQ iptable rule
iptables-save | grep -- "-A INPUT -p tcp -m tcp --dport 5672 -j ACCEPT" > /dev/null
if [ $? -eq 0 ]
then
  echo "* Found iptables rule for RabbitMQ"
else
  echo "* Adding iptables rule for RabbitMQ"
  iptables -I INPUT 1 -p tcp --dport 5672 -j ACCEPT
  /sbin/service iptables save
fi

echo "* Make user rabbitmq-server is running"
service rabbitmq-server start

echo "* Creating rabbitmq user $LOCAL_USER with password $LOCAL_PASSWORD"
rabbitmqctl add_user $LOCAL_USER $LOCAL_PASSWORD
if [ $? -eq 0 ]
then
  echo "* Account created."
else
  echo "* Trying to delete user first."
  rabbitmqctl delete_user $LOCAL_USER
  rabbitmqctl add_user $LOCAL_USER $LOCAL_PASSWORD
  if [ $? -eq 0 ]
  then
    echo "* Account created."
  else
    echo "Couldn't create the account"
    exit 1
  fi
fi
rabbitmqctl set_permissions -p / $LOCAL_USER "." "." ".*"
rabbitmqctl set_user_tags $LOCAL_USER administrator
service rabbitmq-server restart

# Pscheduler archiver setting
cat ../etc/pscheduler-archiver-pundit.template | sed "s/<add-rabbitmq-user-here>/$LOCAL_USER/g" | sed "s/<add-rabbitmq-user-password-here>/$LOCAL_PASSWORD/g"  > /etc/pscheduler/default-archives/pscheduler-archiver-pundit


service pundit-agent start
