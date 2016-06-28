#!/usr/bin/python

import mysql.connector
import time

cnx = mysql.connector.connect(user='root', password='pythiaRush!', database='pythia_new')

cursor = cnx.cursor(buffered=True)

createStatusProcessing = """CREATE TABLE `statusProcessing` (
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

switchStatusStagingAndProcessing = """RENAME TABLE statusStaging TO statusTmp,
   statusProcessing TO statusStaging,
   statusTmp TO statusProcessing"""

addMissingSrcHosts = """INSERT INTO node (ip, name, site) SELECT DISTINCT "" AS ip, srchost AS name, REVERSE(SUBSTRING_INDEX(REVERSE(srchost), '.', 2)) AS site FROM statusProcessing WHERE srchost NOT IN (SELECT name FROM node)"""

addMissingDstHosts = """INSERT INTO node (ip, name, site) SELECT DISTINCT "" AS ip, dsthost AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dsthost), '.', 2)) AS site FROM statusProcessing WHERE dsthost NOT IN (SELECT name FROM node)"""

convertStatusEntries = """INSERT INTO status SELECT FROM_UNIXTIME(startTime) AS startTime, FROM_UNIXTIME(endTime) AS endTime, src.nodeId AS srcId, dst.nodeId AS dstId, baselineDelay AS baselineDelay, detectionCode AS detectionCode, queueingDelay AS queueingDelay, lossRatio AS lossRatio, reorderMetric AS reorderMetric FROM statusProcessing, node AS src, node AS dst WHERE statusProcessing.srchost = src.name AND statusProcessing.dsthost = dst.name"""

removeStatusProcessing = """DROP TABLE statusProcessing;"""

start = time.time();
cursor.execute(createStatusProcessing);
cursor.execute(switchStatusStagingAndProcessing);
print "Adding missing hosts"
cursor.execute(addMissingSrcHosts);
cursor.execute(addMissingDstHosts);
print "Converting status entries"
cursor.execute(convertStatusEntries);
cursor.execute(removeStatusProcessing);
end = time.time();
print "Done in %s s" %(str(end-start));
