#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Clean build directory if present
rm -rf build
mkdir build
mkdir build/pundit-agent

# Copy all components
cp -r bin build/pundit-agent
cp -r etc build/pundit-agent
cp -r lib build/pundit-agent
cp -r savedProblems build/pundit-agent
cp -r system build/pundit-agent

# Create tarball
cd build
tar -zcf pundit-agent.tar.gz pundit-agent

# Copy to rpmbuild/SOURCES
cd ../..
cp pundit-agent/build/pundit-agent.tar.gz rpmbuild/SOURCES
