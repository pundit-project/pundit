#!/bin/bash

# Make sure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

cd ../lib/PuNDIT/db
./processStatusStaging.py
./processTracerouteStaging.py
./processLocalizationEventStaging.py



