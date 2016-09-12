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
) ENGINE=InnoDB DEFAULT CHARSET=latin1"""

switchTracerouteStagingAndProcessing = """RENAME TABLE tracerouteStaging TO tracerouteTmp,
   tracerouteProcessing TO tracerouteStaging,
   tracerouteTmp TO tracerouteProcessing"""

addMissingSrcHosts = """INSERT INTO host (name, site) SELECT DISTINCT src AS name, REVERSE(SUBSTRING_INDEX(REVERSE(src), '.', 2)) AS site FROM tracerouteProcessing WHERE src NOT IN (SELECT name FROM host)"""

addMissingDstHosts = """INSERT INTO host (name, site) SELECT DISTINCT dst AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dst), '.', 2)) AS site FROM tracerouteProcessing WHERE dst NOT IN (SELECT name FROM host)"""

addMissingHopHosts = """INSERT INTO hop (ip, name) SELECT DISTINCT hop_ip AS ip, hop_name AS name FROM tracerouteProcessing LEFT JOIN hop ON (hop.name = tracerouteProcessing.hop_name AND hop.ip = tracerouteProcessing.hop_ip) WHERE hop.ip IS NULL"""

readTraceRoutesWithIds = """select src.hostId AS srcId, dst.hostId AS dstId, tracerouteProcessing.hop_no AS hopNumber, FROM_UNIXTIME(ts) AS timestamp, hop.hopId AS nodeId from tracerouteProcessing, host AS src, host AS dst, hop WHERE tracerouteProcessing.src = src.name AND tracerouteProcessing.dst = dst.name AND tracerouteProcessing.hop_ip = hop.ip AND tracerouteProcessing.hop_name = hop.name ORDER BY srcId, dstId, timestamp, hopNumber;"""

getTraceroutesBetweenHosts = """SELECT traceRouteId, nodeId FROM tracehop NATURAL JOIN traceroute WHERE srcId = %s AND dstId = %s ORDER BY tracerouteID, hopNumber"""

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
routeCacheSrc = -1;
routeCacheDst = -1;
cursor2 = cnx.cursor(buffered=True)
cursor.execute(readTraceRoutesWithIds);
row = cursor.fetchone()

def refreshCache(route):
   global cursor2;
   global routeCache;
   global routeCacheSrc;
   global routeCacheDst;
   if (route["src"] == routeCacheSrc and route["dst"] == routeCacheDst):
      return;
   print "Refreshing Cache";
   routeCacheSrc = route["src"];
   routeCacheDst = route["dst"];
   cursor2.execute(getTraceroutesBetweenHosts, (route["src"],route["dst"]));
   routeCache = {};
   row = cursor2.fetchone();
   currentTraceRoute = -1;
   hopNodes = None;
   while row is not None:
      if currentTraceRoute != row[0]:
         if currentTraceRoute != -1:
            routeCache[tuple(hopNodes)] = currentTraceRoute;
            print "Found route %s" %(hopNodes);
         currentTraceRoute = row[0];
         hopNodes = [row[1]];
      else:
         hopNodes.append(row[1]);
      row = cursor2.fetchone();
   if currentTraceRoute != -1:
      routeCache[tuple(hopNodes)] = currentTraceRoute;
      print "Found route %s" %(hopNodes);

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
      refreshCache(route);
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
