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

