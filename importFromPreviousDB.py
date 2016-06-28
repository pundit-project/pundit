#!/usr/bin/python

import mysql.connector

cnx = mysql.connector.connect(user='root', password='pythiaRush!')

cursor = cnx.cursor(buffered=True)

importStatusEntries = """INSERT INTO pythia_new.statusStaging SELECT * FROM pythia.status;"""

print "Importing Status entries"
cursor.execute(importStatusEntries);
print "Done"
