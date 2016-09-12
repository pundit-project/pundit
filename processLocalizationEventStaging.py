#!/usr/bin/python

import mysql.connector
import time

cnx = mysql.connector.connect(user='root', password='pythiaRush!', database='pythia_new')

cursor = cnx.cursor(buffered=True)

createLocalizationEventProcessing = """CREATE TABLE `localizationEventProcessing` (
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `link_ip` int(10) unsigned DEFAULT NULL,
  `link_name` varchar(256) DEFAULT NULL,
  `det_code` tinyint(3) unsigned DEFAULT NULL,
  `val1` int(10) unsigned DEFAULT NULL,
  `val2` int(10) unsigned DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1"""

switchStagingAndProcessing = """RENAME TABLE localizationEventStaging TO localizationEventTmp,
   localizationEventProcessing TO localizationEventStaging,
   localizationEventTmp TO localizationEventProcessing"""

addMissingHopHosts = """INSERT INTO hop (ip, name) SELECT DISTINCT link_ip AS ip, link_name AS name FROM localizationEventProcessing LEFT JOIN hop ON (hop.name = localizationEventProcessing.link_name AND hop.ip = localizationEventProcessing.link_ip) WHERE hop.ip IS NULL"""

convertLocalizationEventEntries = """INSERT INTO localizationEvent SELECT ts AS timestamp, node.hopId AS nodeId, det_code AS detectionCode, val1 AS val1, val2 AS val2 FROM localizationEventProcessing, hop AS node WHERE localizationEventProcessing.link_name = node.name AND localizationEventProcessing.link_ip = node.ip"""

removeLocalizationEventProcessing = """DROP TABLE localizationEventProcessing;"""

start = time.time();
cursor.execute(createLocalizationEventProcessing);
cursor.execute(switchStagingAndProcessing);
print "Adding missing hosts"
cursor.execute(addMissingHopHosts);
print "Converting localization_event entries"
cursor.execute(convertLocalizationEventEntries);
cursor.execute(removeLocalizationEventProcessing);
cnx.commit();
end = time.time();
print "Done in %s s" %(str(end-start));
