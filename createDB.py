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

createNode = """CREATE TABLE `node` (
  `nodeId` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `ip` varchar(45) NOT NULL,
  `name` varchar(256) NOT NULL,
  `site` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`nodeId`),
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
  `reorderMetric` float unsigned DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

cursor.execute("CREATE DATABASE " + dbName);
cursor.execute("USE " + dbName);
cursor.execute(createStatusStaging)
cursor.execute(createNode)
cursor.execute(createStatus)
