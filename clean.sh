#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Clean build directories
rm -rf pundit-central/build
rm -rf pundit-ui/build

# Clean all intermedite files from rpmbuild
cd rpmbuild
git clean -xdf
