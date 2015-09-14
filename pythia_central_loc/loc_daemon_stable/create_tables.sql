#!/usr/bin/perl
#
# Copyright 2015 Georgia Institute of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# create_tables.sql
#
# Run this to create the tables needed for pythia's normal operation
#

create database pythia;
use pythia;

# Detection/Diagnosis events

create table events (
	sendTS int(11),
	recvTS int(11),
	srchost VARCHAR(256),
	dsthost VARCHAR(256),
	diagnosis VARCHAR(256),
	CSRate float,
	filename VARCHAR(512),
	plot blob
);

create table reorderevents (
	sendTS int(11),
	recvTS int(11),
	srchost VARCHAR(256),
	dsthost VARCHAR(256),
	diagnosis VARCHAR(256)
);

# Localization data and events

create table localizationdata (
	srchost VARCHAR(256),
	dsthost VARCHAR(256),
	startTime int(11),
	delayMetric double,
	lossMetric int(1)
);

# Traceroute table for holding traces collected by each agent

CREATE TABLE traceroutes (
    ts int(32) NOT NULL, 
    src VARCHAR(256), 
    dst VARCHAR(256), 
    hop_no int(32) NOT NULL, 
    hop_ip VARCHAR(256), 
    hop_name VARCHAR(256)
);

