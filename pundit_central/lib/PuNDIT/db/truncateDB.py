#!/usr/bin/python

import mysql.connector
from utility import PunditDBUtil

cnx = PunditDBUtil.createConnection()

cursor = cnx.cursor(buffered=True)

cursor.execute("TRUNCATE TABLE hop");
cursor.execute("TRUNCATE TABLE host");
cursor.execute("TRUNCATE TABLE localizationEvent");
cursor.execute("TRUNCATE TABLE localizationEventStaging");
cursor.execute("TRUNCATE TABLE problem");
cursor.execute("TRUNCATE TABLE status");
cursor.execute("TRUNCATE TABLE statusStaging");
cursor.execute("TRUNCATE TABLE tracehop");
cursor.execute("TRUNCATE TABLE traceroute");
cursor.execute("TRUNCATE TABLE traceroutePeriod");
cursor.execute("TRUNCATE TABLE tracerouteStaging");
