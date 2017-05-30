#!/bin/bash

# Build requirements:
# - spectool
# - rpmbuild

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

echo Building pundit-central...
./pundit-central/build.sh

echo Building pundit-ui...
./pundit-ui/build.sh

echo Building rpms...
./rpmbuild/build.sh

 
