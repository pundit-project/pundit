#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Clean the Yum repository
ssh root@pundit rm -rf /var/www/html/yum-repo
ssh root@pundit mkdir /var/www/html/yum-repo

# Copy all the rpms
rsync -r rpmbuild/RPMS/ --include '*/' --include '*.rpm' --exclude '*' root@pundit:/var/www/html/yum-repo
rsync -r rpmbuild/SRPMS/ --include '*/' --include '*.rpm' --exclude '*' root@pundit:/var/www/html/yum-repo

# Create the yum repository
ssh root@pundit createrepo --database /var/www/html/yum-repo

# Update yum repo file
rsync pundit.repo root@pundit:/var/www/html
