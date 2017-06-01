#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

USER=pundit
PASSWORD=`openssl rand -base64 12`
DATABASE=pundit

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

