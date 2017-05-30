#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Clean build directory if present
rm -rf build
mkdir build
mkdir build/pundit-central

# Copy all components
cp -r bin build/pundit-central
cp -r etc build/pundit-central
cp -r lib build/pundit-central
cp -r system build/pundit-central

# Create tarball
cd build
tar -zcf pundit-central.tar.gz pundit-central

# Copy to rpmbuild/SOURCES
cd ../..
cp pundit-central/build/pundit-central.tar.gz rpmbuild/SOURCES
