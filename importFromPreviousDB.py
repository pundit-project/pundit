#!/usr/bin/python

import mysql.connector
import time

cnx = mysql.connector.connect(user='root', password='pythiaRush!')

cursor = cnx.cursor(buffered=True)

importStatusEntries = """INSERT INTO pythia_new.statusStaging SELECT * FROM pythia.status;"""

importTraceroutEntries = """INSERT INTO pythia_new.tracerouteStaging SELECT * FROM pythia.traceroutes;"""

start = time.time();
print "Importing status entries"
cursor.execute(importStatusEntries);
print "Importing traceroutes entries"
cursor.execute(importTraceroutEntries);
end = time.time();
print "Done in %s s" %(str(end-start));
