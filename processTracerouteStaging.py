#!/usr/bin/python

import mysql.connector
import time

cnx = mysql.connector.connect(user='root', password='pythiaRush!', database='pythia_new')

cursor = cnx.cursor(buffered=True)

resetProcessingTable = """DROP TABLE IF EXISTS tracerouteProcessing"""

createTracerouteProcessing = """CREATE TABLE `tracerouteProcessing` (
  `ts` int(32) NOT NULL,
  `src` varchar(256) DEFAULT NULL,
  `dst` varchar(256) DEFAULT NULL,
  `hop_no` int(32) NOT NULL,
  `hop_ip` varchar(256) DEFAULT NULL,
  `hop_name` varchar(256) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1"""

switchTracerouteStagingAndProcessing = """RENAME TABLE tracerouteStaging TO tracerouteTmp,
   tracerouteProcessing TO tracerouteStaging,
   tracerouteTmp TO tracerouteProcessing"""

addMissingSrcHosts = """INSERT INTO node (ip, name, site) SELECT DISTINCT "" AS ip, src AS name, REVERSE(SUBSTRING_INDEX(REVERSE(src), '.', 2)) AS site FROM tracerouteProcessing WHERE src NOT IN (SELECT name FROM node)"""

addMissingDstHosts = """INSERT INTO node (ip, name, site) SELECT DISTINCT "" AS ip, dst AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dst), '.', 2)) AS site FROM tracerouteProcessing WHERE dst NOT IN (SELECT name FROM node)"""

addMissingHopHosts = """INSERT INTO node (ip, name, site) SELECT DISTINCT hop_ip AS ip, hop_name AS name, REVERSE(SUBSTRING_INDEX(REVERSE(hop_name), '.', 2)) AS site FROM tracerouteProcessing LEFT JOIN node ON (node.name = tracerouteProcessing.hop_name AND node.ip = tracerouteProcessing.hop_ip) WHERE node.ip IS NULL"""

readTraceRoutesWithIds = """select src.nodeId AS srcId, dst.nodeId AS dstId, tracerouteProcessing.hop_no AS hopNumber, FROM_UNIXTIME(ts) AS timestamp, hop.nodeId AS nodeId from tracerouteProcessing, node AS src, node AS dst, node as hop WHERE tracerouteProcessing.src = src.name AND src.ip = "" AND tracerouteProcessing.dst = dst.name AND dst.ip = "" AND tracerouteProcessing.hop_ip = hop.ip AND tracerouteProcessing.hop_name = hop.name ORDER BY srcId, dstId, timestamp, hopNumber;"""

addTraceroute = """INSERT INTO traceroute (srcId, dstId) VALUES (%s, %s)"""

addTraceHop = """INSERT INTO tracehop (tracerouteId, hopNumber, nodeId) VALUES (%s, %s, %s)"""

addTracerouteHistory = """INSERT INTO tracerouteHistory (tracerouteId, timestamp) VALUES (%s, %s)"""

removeStatusProcessing = """DROP TABLE statusProcessing;"""

start = time.time();
cursor.execute(resetProcessingTable);
cursor.execute(createTracerouteProcessing);
cursor.execute(switchTracerouteStagingAndProcessing);
cursor.execute(addMissingSrcHosts);
cursor.execute(addMissingDstHosts);
cursor.execute(addMissingHopHosts);
#cursor.execute();

#read all hops
#Read a route
#  If new src/dst, refresh cache
#  If new route, write to DB
#  Add route to routehistory

routeCache = {};
cursor2 = cnx.cursor(buffered=True)
cursor.execute(readTraceRoutesWithIds);
row = cursor.fetchone()

def nextRoute():
   global row;
   if row is None:
      return None;
   route = {}
   route["src"] = row[0];
   route["dst"] = row[1];
   route["timestamp"] = row[3];
   route["hopNumbers"] = [row[2]];
   route["hopNodes"] = [row[4]];
   while True:
      row = cursor.fetchone();
      if row is None:
         return route;
      if (row[0] != route["src"] or row[1] != route["dst"] or row[3] != route["timestamp"]):
         return route;
      route["hopNumbers"].append(row[2]);
      route["hopNodes"].append(row[4]);

def insertRoute(route):
   global counter;
   global cursor2;
   cursor2.execute(addTraceroute, (route["src"], route["dst"]));
   tracerouteId = cursor2.lastrowid;
   for iHop in range(len(route["hopNodes"])):
      cursor2.execute(addTraceHop, (tracerouteId, route["hopNumbers"][iHop], route["hopNodes"][iHop]));
   print "INSERT route %s as %s" %(route, tracerouteId);
   return tracerouteId;

def insertRouteInstance(timestamp, routeId):
   global cursor2;
   cursor2.execute(addTracerouteHistory, (routeId, timestamp));
   print "INSERT instance %s at %s" %(timestamp, routeId);

while row != None:
   route = nextRoute();
   if route != None:
      if tuple(route["hopNodes"]) not in routeCache:
         routeId = insertRoute(route);
         routeCache[tuple(route["hopNodes"])] = routeId;
      else:
         routeId = routeCache[tuple(route["hopNodes"])];
         #print "Found route %s as %s" %(route, routeId);
      insertRouteInstance(route["timestamp"], routeId);



#routeCache[tuple([1,2,3,4])]=23;
#routeCache[(2,3,4,5,6)]=42;
#print routeCache[(1,2,3,4)]
#print routeCache[(2,3,4,5,6)]

end = time.time();
print "Done in %s s" %(str(end-start));
