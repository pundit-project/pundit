#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

HOSTNAME="$1"

if [ -z "$HOSTNAME" ]
then
  echo "Usage: release.sh <hostname>"
  exit 1
fi

# Clean the Yum repository
ssh root@$HOSTNAME rm -rf /var/www/html/yum-repo
ssh root@$HOSTNAME mkdir /var/www/html/yum-repo

# Copy all the rpms
rsync -r rpmbuild/RPMS/ --include '*/' --include '*.rpm' --exclude '*' root@$HOSTNAME:/var/www/html/yum-repo
rsync -r rpmbuild/SRPMS/ --include '*/' --include '*.rpm' --exclude '*' root@$HOSTNAME:/var/www/html/yum-repo

# Create the yum repository
ssh root@$HOSTNAME createrepo --database /var/www/html/yum-repo

# Update yum repo file
rsync pundit.repo root@$HOSTNAME:/var/www/html/pundit.repo.template
ssh root@$HOSTNAME "cat /var/www/html/pundit.repo.template | sed \"s/<hostname>/$HOSTNAME/g\" > /var/www/html/pundit.repo"
