#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Pscheduler archiver setting
setuparchiver() {
cat > $FILE  << EOF
{
    	"archiver": "rabbitmq",
	    "data": {
        "_url": "amqp://guest:guest@localhost:5672/",
        "routing-key": "perfsonar.perfdata",
	       "exchange": "perfdata",
	       "template": {
	       "measurement": "__RESULT__"
	     },
	     "retry-policy": [
	     	{ "attempts": 5,  "wait": "PT1S" },
	        { "attempts": 5,  "wait": "PT3S" }
	     ]
	    },
	    "ttl": "PT1H"
}
EOF
}

FILE=/etc/pscheduler/default-archives/pscheduler-archiver-pundit
echo "Setting up an archiver..."
echo "Archiver config path: $FILE"
if [ -f $FILE ]; then
	while true; do
		read -p "an archiver configuration for pundit already exists, overwrite?" yn
		case $yn in
			[Yy]* ) setuparchiver; break;;
			[Nn]* ) break;
		esac
	done
else
	setuparchiver
fi


# RabbitMQ
echo "* Open port 5672 for use"
iptables -I INPUT 1 -p tcp --dport 5672 -j ACCEPT
/sbin/service iptables save


# TODO pundit-central configuration
PERF_HOST=""
#CENTRAL_HOST=punditdev3.aglt2.org
#CENTRAL_USER=pundit-agent
#CENTRAL_PASSWORD=agentpass
read -p "Enter central hostname: " CENTRAL_HOST
echo $CENTRAL_HOST
read -p "Enter rabbitmq user id: " CENTRAL_USER
echo $CENTRAL_USER
read -p "Enter rabbitmq user password: " CENTRAL_PASSWORD
echo $CENTRAL_PASSWORD

# pundit-agent.conf
echo "* Configuring pundit-agent daemon"
cat ../etc/pundit-agent.conf.template-dev | sed "s/<add-src-host-here>/$PERF_HOST/g" | sed "s/<add-consumer-host-name-here>/$CENTRAL_HOST/g" | sed "s/<replace-rabbitmq-user-here>/$CENTRAL_USER/g" | sed "s/<replace-rabbitmq-password-here>/$CENTRAL_PASSWORD/g"  > ../etc/pundit-agent.conf


service pundit-agent start
