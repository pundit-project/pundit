#!/usr/bin/python

import mysql.connector
import time

cnx = mysql.connector.connect(user='root', password='pythiaRush!', database='pythia_new')

cursor = cnx.cursor(buffered=True)

resetProcessingTable = """DROP TABLE IF EXISTS tracerouteProcessing"""

createTracerouteProcessing = """CREATE TABLE `tracerouteProcessing` (
  `ts` int(32) NOT NULL,
  `src` varchar(256) DEFAULT NULL,
  `dst` varchar(256) DEFAULT NULL,
  `hop_no` int(32) NOT NULL,
  `hop_ip` varchar(256) DEFAULT NULL,
  `hop_name` varchar(256) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

switchTracerouteStagingAndProcessing = """RENAME TABLE tracerouteStaging TO tracerouteTmp,
   tracerouteProcessing TO tracerouteStaging,
   tracerouteTmp TO tracerouteProcessing"""

addMissingSrcHosts = """INSERT INTO node (ip, name, site) SELECT DISTINCT "" AS ip, src AS name, REVERSE(SUBSTRING_INDEX(REVERSE(src), '.', 2)) AS site FROM tracerouteProcessing WHERE src NOT IN (SELECT name FROM node)"""

addMissingDstHosts = """INSERT INTO node (ip, name, site) SELECT DISTINCT "" AS ip, dst AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dst), '.', 2)) AS site FROM tracerouteProcessing WHERE dst NOT IN (SELECT name FROM node)"""

convertStatusEntries = """INSERT INTO status SELECT FROM_UNIXTIME(startTime) AS startTime, FROM_UNIXTIME(endTime) AS endTime, src.nodeId AS srcId, dst.nodeId AS dstId, baselineDelay AS baselineDelay, detectionCode AS detectionCode, queueingDelay AS queueingDelay, lossRatio AS lossRatio, reorderMetric AS reorderMetric FROM statusProcessing, node AS src, node AS dst WHERE statusProcessing.srchost = src.name AND statusProcessing.dsthost = dst.name"""

removeStatusProcessing = """DROP TABLE statusProcessing;"""

start = time.time();
cursor.execute(resetProcessingTable);
cursor.execute(createTracerouteProcessing);
cursor.execute(switchTracerouteStagingAndProcessing);
cursor.execute(addMissingSrcHosts);
cursor.execute(addMissingDstHosts);
#cursor.execute();
end = time.time();
print "Done in %s s" %(str(end-start));
