#!/usr/bin/python

from utility import PunditDBUtil

cnx = PunditDBUtil.createConnection()
PunditDBUtil.processStatusStaging(cnx)
cnx.commit()
