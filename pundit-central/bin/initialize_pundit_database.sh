#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

USER=pundit
RAND_STRING=`date | md5sum`
PASSWORD=`echo ${RAND_STRING:0:14}`
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

echo "* Saving username and password in configuration file"

cat ../etc/pundit_db_scripts.conf.template | sed "s/<replace-mysql-database-here>/$DATABASE/g" | sed "s/<replace-mysql-user-here>/$USER/g" | sed "s/<replace-mysql-user-password-here>/$PASSWORD/g" > ../etc/pundit_db_scripts.conf
chmod 600 ../etc/pundit_db_scripts.conf

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

echo "* Creating database"
cd ../lib/PuNDIT/db
./createDB.py


