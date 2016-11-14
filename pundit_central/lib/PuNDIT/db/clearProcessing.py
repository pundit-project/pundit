#!/usr/bin/python

import mysql.connector
from utility import PunditDBUtil

cnx = PunditDBUtil.createConnection()

cursor = cnx.cursor(buffered=True)

cursor.execute("DROP TABLE IF EXISTS statusProcessing");
cursor.execute("DROP TABLE IF EXISTS localizationEventProcessing");
cursor.execute("DROP TABLE IF EXISTS tracerouteProcessing");

