#!/bin/python

import mysql.connector
import time

class TraceroutePeriod:
  def __init__(self, cnx):
    self.cursor = cnx.cursor(buffered=True)
    self.traceroutesBetweenHosts = [];
    self.initEmptyPeriod()

  def initEmptyPeriod(self):
    self.startTime = None;
    self.endTime = None;
    self.tracerouteId = None;
    self.toUpdate = False;

  def createClosedPeriod(self):
    self.cursor.execute("INSERT INTO traceroutePeriod (tracerouteId, startTime, endTime) VALUES (%s, %s, %s)", (self.tracerouteId, self.startTime, self.endTime))

  def createOpenPeriod(self):
    self.cursor.execute("INSERT INTO traceroutePeriod (tracerouteId, startTime) VALUES (%s, %s)", (self.tracerouteId, self.startTime))

  def closePeriod(self):
    self.cursor.execute("UPDATE traceroutePeriod SET endTime = %s WHERE tracerouteId = %s AND startTime = %s", (self.endTime, self.tracerouteId, self.startTime))

  def savePeriod(self):
    if (self.startTime is None):
      return
    if (self.toUpdate):
      if (self.endTime is None):
        return
      else:
        self.closePeriod()
    else:
      if (self.endTime is None):
        self.createOpenPeriod()
      else:
        self.createClosedPeriod()

  def hostsChanged(self, tracerouteEvent):
    return not (tracerouteEvent["tracerouteId"] in self.traceroutesBetweenHosts)

  def refreshTraceroutesBetweeHosts(self, tracerouteEvent):
    self.traceroutesBetweenHosts = [];
    self.cursor.execute("SELECT t2.tracerouteId AS tracerouteId FROM traceroute AS t1, traceroute AS t2 WHERE t1.tracerouteID = %s AND t1.srcId = t2.srcId AND t1.dstId = t2.dstId", (tracerouteEvent["tracerouteId"],))
    for row in self.cursor:
      self.traceroutesBetweenHosts.append(row[0])

  def initPeriod(self, tracerouteEvent):
    self.cursor.execute("SELECT tracerouteId, startTime, endTime FROM traceroutePeriod WHERE tracerouteId = %s AND endTime IS NULL", (tracerouteEvent["tracerouteId"],))
    row = self.cursor.fetchone()
    if row is None:
      self.initEmptyPeriod()
    else:
      period = dict(zip(self.cursor.column_names, row))
      self.startTime = period["startTime"]
      self.endTime = None
      self.tracerouteId = period["tracerouteId"]
      self.toUpdate = True

  def newPeriod(self, tracerouteEvent):
    self.tracerouteId = tracerouteEvent["tracerouteId"]
    self.startTime = tracerouteEvent["timestamp"]
    self.endTime = None

  def updatePeriod(self, tracerouteEvent):
    if tracerouteEvent["tracerouteId"] == self.tracerouteId:
      return
    else:
      self.endTime = tracerouteEvent["timestamp"]
      self.savePeriod()
      self.newPeriod(tracerouteEvent)

  def processEvent(self, tracerouteEvent):
    if self.hostsChanged(tracerouteEvent):
      self.savePeriod()
      self.refreshTraceroutesBetweeHosts(tracerouteEvent)
      self.initPeriod(tracerouteEvent)
    self.updatePeriod(tracerouteEvent)

class PeriodAggregator:

  def __init__(self, cnx):
    self.cursor = cnx.cursor(buffered=True)
    self.period = TraceroutePeriod(cnx)

  def processNewData(self, newDataQuery):
    self.cursor.execute(newDataQuery)
    for newRow in self.cursor:
      newData = dict(zip(self.cursor.column_names, newRow))
      self.period.processEvent(newData)
    self.period.savePeriod()

class TracerouteProcessor:

  def __init__(self, cnx):
    self.dataCursor = cnx.cursor(buffered=True)
    self.cursor = cnx.cursor(buffered=True)
    self.routeCache = {}
    self.routeCacheSrc = -1
    self.routeCacheDst = -1
    self.newTraceroutes = 0
    self.newTracerouteEntries = 0


  def createTraceroute(self, route):
    self.cursor.execute("INSERT INTO traceroute (srcId, dstId) VALUES (%s, %s)", (route["src"], route["dst"]))
    tracerouteId = self.cursor.lastrowid;
    for iHop in range(len(route["hopNodes"])):
      self.cursor.execute("INSERT INTO tracehop (tracerouteId, hopNumber, nodeId) VALUES (%s, %s, %s)", (tracerouteId, route["hopNumbers"][iHop], route["hopNodes"][iHop]));
    #print "INSERT route %s as %s" %(route, tracerouteId);
    self.newTraceroutes += 1
    return tracerouteId


  def addTracerouteInstance(self, timestamp, routeId):
    self.cursor.execute("INSERT INTO tracerouteHistory (tracerouteId, timestamp) VALUES (%s, %s)", (routeId, timestamp));
    #print "INSERT instance %s at %s" %(timestamp, routeId);
    self.newTracerouteEntries += 1

  def readNextRoute(self):
    if self.row is None:
      return None;
    route = {}
    route["src"] = self.row[0];
    route["dst"] = self.row[1];
    route["timestamp"] = self.row[3];
    route["hopNumbers"] = [self.row[2]];
    route["hopNodes"] = [self.row[4]];
    while True:
      self.row = self.dataCursor.fetchone();
      if self.row is None:
         return route;
      if (self.row[0] != route["src"] or self.row[1] != route["dst"] or self.row[3] != route["timestamp"]):
         return route;
      route["hopNumbers"].append(self.row[2]);
      route["hopNodes"].append(self.row[4]);

  def refreshCache(self, route):
    if (route["src"] == self.routeCacheSrc and route["dst"] == self.routeCacheDst):
      return;
    #print "Refreshing Cache";
    self.routeCacheSrc = route["src"];
    self.routeCacheDst = route["dst"];
    self.cursor.execute("SELECT traceRouteId, nodeId FROM tracehop NATURAL JOIN traceroute WHERE srcId = %s AND dstId = %s ORDER BY tracerouteID, hopNumber", (route["src"], route["dst"]));
    self.routeCache = {};
    row = self.cursor.fetchone();
    currentTraceRoute = -1;
    hopNodes = None;
    while row is not None:
      if currentTraceRoute != row[0]:
        if currentTraceRoute != -1:
          self.routeCache[tuple(hopNodes)] = currentTraceRoute;
          #print "Found route %s" %(hopNodes);
        currentTraceRoute = row[0];
        hopNodes = [row[1]];
      else:
        hopNodes.append(row[1]);
      row = self.cursor.fetchone();
    if currentTraceRoute != -1:
      self.routeCache[tuple(hopNodes)] = currentTraceRoute;
      #print "Found route %s" %(hopNodes);

  def processNewData(self, newDataQuery):
    startProcessing = time.time()
    self.dataCursor.execute(newDataQuery)
    self.row = self.dataCursor.fetchone()
    while self.row != None:
      route = self.readNextRoute();
      if route != None:
        self.refreshCache(route);
        if tuple(route["hopNodes"]) not in self.routeCache:
          routeId = self.createTraceroute(route);
          self.routeCache[tuple(route["hopNodes"])] = routeId;
        else:
          routeId = self.routeCache[tuple(route["hopNodes"])];
          #print "Found route %s as %s" %(route, routeId);
        self.addTracerouteInstance(route["timestamp"], routeId);
    endProcessing = time.time()
    print "Traceroutes processed in %s s - %s entries processes - %s new routes found" %(str(endProcessing - startProcessing), str(self.newTracerouteEntries), str(self.newTraceroutes))


class PunditDBUtil:
  @staticmethod
  def createConnection():
    return mysql.connector.connect(user='root', password='pythiaRush!', database='pythia_new')

  @staticmethod
  def regenerateTraceroutePeriod(cnx):
    print "Regenerating traceroutePeriod table"
    cursor = cnx.cursor(buffered=True)
    cursor.execute("TRUNCATE traceroutePeriod")
    aggregator = PeriodAggregator(cnx)
    aggregator.processNewData("SELECT * FROM traceroute, tracerouteHistory WHERE traceroute.tracerouteID = tracerouteHistory.tracerouteId ORDER BY traceroute.srcId ASC, traceroute.dstId ASC, tracerouteHistory.timestamp ASC")

  @staticmethod
  def processTracerouteStaging(cnx):
    print "Processing tracerouteStaging table"
    cursor = cnx.cursor(buffered=True)
    cursor.execute("""CREATE TABLE `tracerouteProcessing` (
  `ts` int(32) NOT NULL,
  `src` varchar(256) DEFAULT NULL,
  `dst` varchar(256) DEFAULT NULL,
  `hop_no` int(32) NOT NULL,
  `hop_ip` varchar(256) DEFAULT NULL,
  `hop_name` varchar(256) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("RENAME TABLE tracerouteStaging TO tracerouteTmp, tracerouteProcessing TO tracerouteStaging, tracerouteTmp TO tracerouteProcessing")
    cursor.execute("INSERT INTO host (name, site) SELECT DISTINCT src AS name, REVERSE(SUBSTRING_INDEX(REVERSE(src), '.', 2)) AS site FROM tracerouteProcessing WHERE src NOT IN (SELECT name FROM host)")
    cursor.execute("INSERT INTO host (name, site) SELECT DISTINCT dst AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dst), '.', 2)) AS site FROM tracerouteProcessing WHERE dst NOT IN (SELECT name FROM host)")
    cursor.execute("INSERT INTO hop (ip, name) SELECT DISTINCT hop_ip AS ip, hop_name AS name FROM tracerouteProcessing LEFT JOIN hop ON (hop.name = tracerouteProcessing.hop_name AND hop.ip = tracerouteProcessing.hop_ip) WHERE hop.ip IS NULL")
    processor = TracerouteProcessor(cnx)
    processor.processNewData("select src.hostId AS srcId, dst.hostId AS dstId, tracerouteProcessing.hop_no AS hopNumber, FROM_UNIXTIME(ts) AS timestamp, hop.hopId AS nodeId from tracerouteProcessing, host AS src, host AS dst, hop WHERE tracerouteProcessing.src = src.name AND tracerouteProcessing.dst = dst.name AND tracerouteProcessing.hop_ip = hop.ip AND tracerouteProcessing.hop_name = hop.name ORDER BY srcId, dstId, timestamp, hopNumber;")
    cursor.execute("DROP TABLE tracerouteProcessing")
