#!/usr/bin/python

import mysql.connector
import time
from utility import PunditDBUtil

cnx = PunditDBUtil.createConnection()
PunditDBUtil.processLocalizationEventStaging(cnx)
cnx.commit()
