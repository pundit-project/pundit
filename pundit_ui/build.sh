#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Clean build directory if present
rm -rf build
mkdir build
mkdir build/pundit-ui

# Copy diirt web app and configutaion
cp -r diirt build/pundit-ui

# Copy web ui
cp -r web-ui/public_html/ build/pundit-ui/
mv build/pundit-ui/public_html build/pundit-ui/web-ui

# Create tarball
cd build
tar -zcf pundit-ui.tar.gz pundit-ui

# Copy to rpmbuild/SOURCES
cd ../..
cp pundit_ui/build/pundit-ui.tar.gz rpmbuild/SOURCES
