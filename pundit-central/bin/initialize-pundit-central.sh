#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Create Database user
######################

USER=pundit
PASSWORD=`openssl rand -base64 12 | sed -e 's/[\/+&]/A/g'`
DATABASE=pundit

echo "* Making sure mysql is running and chkconfig is on"
chkconfig mysqld on
service mysqld start

echo "* Creating mysql user $USER with password $PASSWORD"

echo "* Please enter mysql root password..."
echo "CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON $DATABASE.* TO '$USER'@'localhost';" | mysql -u root -p

if [ $? -eq 0 ]
then
  echo "* Account created."
else
  echo "* Trying to DROP USER first. Please enter mysql root password again..."
  echo "DROP USER 'pundit'@'localhost'; CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON $DATABASE.* TO '$USER'@'localhost';" | mysql -u root -p

  if [ $? -eq 0 ]
  then
    echo "* Account created."
  else
    echo "Couldn't create the account"
    exit 1
  fi
fi

# Create RabbitMQ users

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

CENTRAL_HOST=`hostname`
CENTRAL_USER=pundit-central
CENTRAL_PASSWORD=`openssl rand -base64 12 | sed -e 's/[\/+&]/A/g'`
AGENT_USER=pundit-agent
AGENT_PASSWORD=`openssl rand -base64 12 | sed -e 's/[\/+&]/A/g'`

echo "* Creating rabbitmq user $CENTRAL_USER with password $CENTRAL_PASSWORD"
rabbitmqctl add_user $CENTRAL_USER $CENTRAL_PASSWORD
if [ $? -eq 0 ]
then
  echo "* Account created."
else
  echo "* Trying to delete user first."
  rabbitmqctl delete_user $CENTRAL_USER
  rabbitmqctl add_user $CENTRAL_USER $CENTRAL_PASSWORD
  if [ $? -eq 0 ]
  then
    echo "* Account created."
  else
    echo "Couldn't create the account"
    exit 1
  fi
fi
rabbitmqctl set_permissions -p / $CENTRAL_USER "." "." ".*"
rabbitmqctl set_user_tags $CENTRAL_USER administrator
echo "* Creating rabbitmq user $AGENT_USER with password $AGENT_PASSWORD"
rabbitmqctl add_user $AGENT_USER $AGENT_PASSWORD
if [ $? -eq 0 ]
then
  echo "* Account created."
else
  echo "* Trying to delete user first."
  rabbitmqctl delete_user $AGENT_USER
  rabbitmqctl add_user $AGENT_USER $AGENT_PASSWORD
  if [ $? -eq 0 ]
  then
    echo "* Account created."
  else
    echo "Couldn't create the account"
    exit 1
  fi
fi
rabbitmqctl set_permissions -p / $AGENT_USER "." "." ".*"
service rabbitmq-server restart

# Update credentials in all configuration files
###############################################

echo "* Write agent credentials into a configuration file"
echo "agent-user=$AGENT_USER" > ../etc/pundit-agent.credentials
chmod 600 ../etc/pundit-agent.credentials
echo "agent-password=$AGENT_PASSWORD" >> ../etc/pundit-agent.credentials


echo "* Configuring database scripts"
cat ../etc/pundit_db_scripts.conf.template | sed "s/<replace-mysql-database-here>/$DATABASE/g" | sed "s/<replace-mysql-user-here>/$USER/g" | sed "s/<replace-mysql-user-password-here>/$PASSWORD/g" > ../etc/pundit_db_scripts.conf
chmod 600 ../etc/pundit_db_scripts.conf

echo "* Configuring pundit-ui"
if [ -d "../../pundit-ui" ]
then
  service glassfish4 stop
  cat ../../pundit-ui/diirt/conf/datasources/jdbc/jdbc.xml.template | sed "s/<replace-mysql-database-here>/$DATABASE/g" | sed "s/<replace-mysql-user-here>/$USER/g" | sed "s/<replace-mysql-user-password-here>/$PASSWORD/g" > ../../pundit-ui/diirt/conf/datasources/jdbc/jdbc.xml
  chmod 600 ../../pundit-ui/diirt/conf/datasources/jdbc/jdbc.xml
  chown glassfish:glassfish ../../pundit-ui/diirt/conf/datasources/jdbc/jdbc.xml
  service glassfish4 start
else
  echo "NOTE: pundit-ui was not found. You'll need to edit its configuration manually"
fi

echo "* Configuring pundit-central daemon"
cat ../etc/pundit-central.conf.template | sed "s/<replace-rabbitmq-host-here>/$CENTRAL_HOST/g" | sed "s/<replace-rabbitmq-user-here>/$CENTRAL_USER/g" | sed "s/<replace-rabbitmq-user-password-here>/$CENTRAL_PASSWORD/g" | sed "s/<replace-mysql-database-here>/$DATABASE/g" | sed "s/<replace-mysql-user-here>/$USER/g" | sed "s/<replace-mysql-user-password-here>/$PASSWORD/g" > ../etc/pundit-central.conf
chmod 600 ../etc/pundit-central.conf

# Create the database
#####################

echo "* Creating database"
cd ../lib/PuNDIT/db
./createDB.py



