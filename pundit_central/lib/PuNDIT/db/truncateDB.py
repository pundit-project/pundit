#!/usr/bin/python

import mysql.connector
from utility import PunditDBUtil

cnx = PunditDBUtil.createConnection()
PunditDBUtil.truncateDB(cnx)
