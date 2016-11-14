#!/usr/bin/python

from utility import PunditDBUtil

cnx = PunditDBUtil.createConnection()
PunditDBUtil.processTracerouteStaging(cnx)
cnx.commit()
