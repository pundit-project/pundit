#!/usr/bin/python

import mysql.connector

cnx = mysql.connector.connect(user='root', password='pythiaRush!', database='pythia_new')

cursor = cnx.cursor(buffered=True)

cursor.execute("TRUNCATE TABLE status");
cursor.execute("TRUNCATE TABLE tracerouteHistory");
cursor.execute("TRUNCATE TABLE traceroute");
cursor.execute("TRUNCATE TABLE tracehop");
cursor.execute("TRUNCATE TABLE node");

