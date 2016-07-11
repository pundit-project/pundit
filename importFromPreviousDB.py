#!/usr/bin/python

import mysql.connector
import time

cnx = mysql.connector.connect(user='root', password='pythiaRush!')

cursor = cnx.cursor(buffered=True)

importStatusEntries = """INSERT INTO pythia_new.statusStaging SELECT * FROM pythia.status;"""

importTracerouteEntries = """INSERT INTO pythia_new.tracerouteStaging SELECT * FROM pythia.traceroutes;"""

importLocalizationEventEntries = """INSERT INTO pythia_new.localizationEventStaging SELECT * FROM pythia.localization_events;"""

start = time.time();
print "Importing status entries"
cursor.execute(importStatusEntries);
print "Importing traceroutes entries"
cursor.execute(importTracerouteEntries);
print "Importing localization_events entries"
cursor.execute(importLocalizationEventEntries);
end = time.time();
print "Done in %s s" %(str(end-start));
