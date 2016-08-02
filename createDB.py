#!/usr/bin/python

import mysql.connector

cnx = mysql.connector.connect(user='root', password='pythiaRush!')

cursor = cnx.cursor(buffered=True)

dbName = "pythia_new"

createStatusStaging = """CREATE TABLE `statusStaging` (
  `startTime` int(11) DEFAULT NULL,
  `endTime` int(11) DEFAULT NULL,
  `srchost` varchar(256) DEFAULT NULL,
  `dsthost` varchar(256) DEFAULT NULL,
  `baselineDelay` float DEFAULT NULL,
  `detectionCode` int(11) DEFAULT NULL,
  `queueingDelay` float DEFAULT NULL,
  `lossRatio` float DEFAULT NULL,
  `reorderMetric` float DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createTracerouteStaging = """CREATE TABLE `tracerouteStaging` (
  `ts` int(32) NOT NULL,
  `src` varchar(256) DEFAULT NULL,
  `dst` varchar(256) DEFAULT NULL,
  `hop_no` int(32) NOT NULL,
  `hop_ip` varchar(256) DEFAULT NULL,
  `hop_name` varchar(256) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createLocalizationEventStaging = """CREATE TABLE `localizationEventStaging` (
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `link_ip` int(10) unsigned DEFAULT NULL,
  `link_name` varchar(256) DEFAULT NULL,
  `det_code` tinyint(3) unsigned DEFAULT NULL,
  `val1` int(10) unsigned DEFAULT NULL,
  `val2` int(10) unsigned DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createHop = """CREATE TABLE `hop` (
  `hopId` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `ip` varchar(45) NOT NULL,
  `name` varchar(256) NOT NULL,
  PRIMARY KEY (`hopId`),
  KEY `name_idx` (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;"""

createHost = """CREATE TABLE `host` (
  `hostId` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `site` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`hostId`),
  KEY `name_idx` (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;"""

createStatus = """CREATE TABLE `status` (
  `startTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `endTime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `srcId` smallint(5) unsigned NOT NULL,
  `dstId` smallint(5) unsigned NOT NULL,
  `baselineDelay` float unsigned DEFAULT NULL,
  `detectionCode` bit(8) DEFAULT NULL,
  `queueingDelay` float unsigned DEFAULT NULL,
  `lossRatio` float unsigned DEFAULT NULL,
  `reorderMetric` float unsigned DEFAULT NULL,
  KEY `src_dst_time_idx` (`srcId`, `dstId`, `startTime`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createTracehop = """CREATE TABLE `tracehop` (
  `tracerouteId` int(10) unsigned NOT NULL,
  `hopNumber` tinyint(3) unsigned NOT NULL,
  `nodeId` smallint(5) unsigned NOT NULL,
  KEY `trace_hop_idx` (`tracerouteId`, `hopNumber`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createTraceroute = """CREATE TABLE `traceroute` (
  `tracerouteId` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `srcId` smallint(5) unsigned NOT NULL,
  `dstId` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`tracerouteId`),
  KEY `src_dst_idx` (`srcId`, `dstId`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createTracerouteHistory = """CREATE TABLE `tracerouteHistory` (
  `tracerouteId` int(10) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY `traceroute_timestamp_idx` (`tracerouteId`,`timestamp`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createLocalizationEvent = """CREATE TABLE `localizationEvent` (
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `nodeId` smallint(5) unsigned NOT NULL,
  `detectionCode` bit(8) NOT NULL,
  `val1` float unsigned DEFAULT NULL,
  `val2` float unsigned DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

createProblem = """CREATE TABLE IF NOT EXISTS `problem` (
  `startTime` TIMESTAMP NOT NULL,
  `endTime` TIMESTAMP NULL DEFAULT NULL,
  `srcId` smallint(5) unsigned NOT NULL,
  `dstId` smallint(5) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `info` varchar(10) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

cursor.execute("CREATE DATABASE " + dbName);
cursor.execute("USE " + dbName);
cursor.execute(createTracerouteStaging)
cursor.execute(createStatusStaging)
cursor.execute(createLocalizationEventStaging)
cursor.execute(createHop)
cursor.execute(createHost)
cursor.execute(createStatus)
cursor.execute(createTracehop)
cursor.execute(createTraceroute)
cursor.execute(createTracerouteHistory)
cursor.execute(createLocalizationEvent)
cursor.execute(createProblem)
