#!/bin/python

import mysql.connector
import time
import ConfigParser
from datetime import datetime, timedelta

class TraceroutePeriod:
  def __init__(self, cnx):
    self.cursor = cnx.cursor(buffered=True)
    self.traceroutesBetweenHosts = [];
    self.initEmptyPeriod()
    self.updated = 0
    self.closed = 0
    self.opened = 0

  def initEmptyPeriod(self):
    self.startTime = None;
    self.endTime = None;
    self.tracerouteId = None;
    self.toUpdate = False;

  def createClosedPeriod(self):
    self.cursor.execute("INSERT INTO traceroutePeriod (tracerouteId, startTime, endTime) VALUES (%s, %s, %s)", (self.tracerouteId, self.startTime, self.endTime))
    self.updated += 1
    self.closed += 1
    self.opened +=1

  def createOpenPeriod(self):
    self.cursor.execute("INSERT INTO traceroutePeriod (tracerouteId, startTime) VALUES (%s, %s)", (self.tracerouteId, self.startTime))
    self.updated += 1
    self.opened +=1

  def closePeriod(self):
    self.cursor.execute("UPDATE traceroutePeriod SET endTime = %s WHERE tracerouteId = %s AND startTime = %s", (self.endTime, self.tracerouteId, self.startTime))
    self.updated += 1
    self.closed += 1

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
    self.cursor.execute("SELECT traceroutePeriod.tracerouteId, startTime, endTime FROM traceroutePeriod, traceroute AS t1, traceroute AS t2 WHERE t1.tracerouteId = %s AND t1.srcId = t2.srcId AND t1.dstId = t2.dstId AND traceroutePeriod.tracerouteID = t2.tracerouteId AND endTime IS NULL", (tracerouteEvent["tracerouteId"],))
    row = self.cursor.fetchone()
    if row is None:
      self.newPeriod(tracerouteEvent)
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
    self.toUpdate = False

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
    startProcessing = time.time()
    self.cursor.execute(newDataQuery)
    for newRow in self.cursor:
      newData = dict(zip(self.cursor.column_names, newRow))
      self.period.processEvent(newData)
    self.period.savePeriod()
    endProcessing = time.time()
    print "TraceroutePeriods aggregated in %s s - %s periods udpated - %s closed - %s opened" %(str(endProcessing - startProcessing), str(self.period.updated), str(self.period.closed), str(self.period.opened))

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


  def addTracerouteEntry(self, timestamp, routeId):
    self.cursor.execute("INSERT INTO newTracerouteEntry (tracerouteId, timestamp) VALUES (%s, %s)", (routeId, timestamp));
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
      print "Next route %s - %s - %s (%s) (%s)" %(route["src"], route["dst"], route["timestamp"], str(route["hopNumbers"]), str(route["hopNodes"]))
      if route != None:
        self.refreshCache(route);
        if tuple(route["hopNodes"]) not in self.routeCache:
          routeId = self.createTraceroute(route);
          self.routeCache[tuple(route["hopNodes"])] = routeId;
        else:
          routeId = self.routeCache[tuple(route["hopNodes"])];
          #print "Found route %s as %s" %(route, routeId);
        self.addTracerouteEntry(route["timestamp"], routeId);
    endProcessing = time.time()
    print "Traceroutes processed in %s s - %s entries processes - %s new routes found" %(str(endProcessing - startProcessing), str(self.newTracerouteEntries), str(self.newTraceroutes))

class Problem:
  def __init__(self, cnx, pType):
    self.cursor = cnx.cursor(buffered=True)
    self.traceroutesBetweenHosts = [];
    self.initEmptyProblem()
    self.pType = pType
    self.updated = 0
    self.closed = 0
    self.opened = 0

  def initEmptyProblem(self):
    self.startTime = None
    self.endTime = None
    self.srcId = None
    self.dstId = None
    self.info = 0
    self.toUpdate = False

  def infoString(self):
    if (self.pType == "delay"):
      return "%s ms" % self.info
    if (self.pType == "pLoss"):
      return "%s%%" % self.info
    raise Exception('Unkown problem type' + self.pType)

  def createClosedProblem(self):
    #print "Create closed problem from %s to %s - (%s - %s) - info %s" %(self.srcId, self.dstId, self.startTime, self.endTime, self.info)
    self.cursor.execute("INSERT INTO problem (startTime, endTime, srcId, dstId, type, info) VALUES (%s, %s, %s, %s, %s, %s)", (self.startTime, self.endTime, self.srcId, self.dstId, self.pType, self.infoString()))
    self.updated += 1
    self.closed += 1
    self.opened +=1

  def createOpenProblem(self):
    #print "Open problem from %s to %s - (%s - %s) - info %s" %(self.srcId, self.dstId, self.startTime, self.endTime, self.info)
    self.cursor.execute("INSERT INTO problem (startTime, srcId, dstId, type, info) VALUES (%s, %s, %s, %s, %s)", (self.startTime, self.srcId, self.dstId, self.pType, self.infoString()))
    self.updated += 1
    self.opened +=1

  def closeProblem(self):
    #print "Close problem from %s to %s - (%s - %s) - info %s" %(self.srcId, self.dstId, self.startTime, self.endTime, self.info)
    self.cursor.execute("UPDATE problem SET info = %s, endTime = %s WHERE srcId = %s AND dstID = %s AND type = %s AND endTime IS NULL", (self.infoString(), self.endTime, self.srcId, self.dstId, self.pType))
    self.updated += 1
    self.closed += 1

  def updateOpenProblem(self):
    #print "Update problem from %s to %s - (%s - %s) - info %s" %(self.srcId, self.dstId, self.startTime, self.endTime, self.info)
    self.cursor.execute("UPDATE problem SET info = %s WHERE srcId = %s AND dstID = %s AND type = %s AND endTime IS NULL", (self.infoString(), self.srcId, self.dstId, self.pType))
    self.updated += 1

  def saveOpenProblem(self):
    if (self.startTime is None):
      return
    if (self.toUpdate):
      self.updateOpenProblem()
    else:
      self.createOpenProblem()

  def saveClosedProblem(self):
    if (self.startTime is None):
      return
    if (self.toUpdate):
      self.closeProblem()
    else:
      self.createClosedProblem()

  def infoFromDB(self, info):
    if info.endswith(" ms"):
      return float(info[:-3])
    if info.endswith("%"):
      return float(info[:-1])
    return 0

  def detectionCode(self):
    if (self.pType == "delay"):
      return 2
    if (self.pType == "pLoss"):
      return 4
    return 0

  def pFlag(self):
    if (self.pType == "delay"):
      return "hasDelay"
    if (self.pType == "pLoss"):
      return "hasLoss"
    return ""

  def hostsChanged(self, statusEvent):
    return self.srcId != statusEvent["srcId"] or self.dstId != statusEvent["dstId"]

  def initProblem(self, statusEvent):
      self.initEmptyProblem()
      self.srcId = statusEvent["srcId"]
      self.dstId = statusEvent["dstId"]

  def loadLastProblem(self, statusEvent):
    self.cursor.execute("SELECT * FROM problem WHERE srcId = %s AND dstID = %s AND type = %s AND endTime IS NULL", (statusEvent["srcId"], statusEvent["dstId"], self.pType))
    row = self.cursor.fetchone()
    if row is None:
      self.initProblem(statusEvent)
    else:
      status = dict(zip(self.cursor.column_names, row))
      self.startTime = status["startTime"]
      self.endTime = None
      self.srcId = status["srcId"]
      self.dstId = status["dstId"]
      self.info = self.infoFromDB(status["info"])
      self.toUpdate = True
      # Retrieve last time for open problem
      self.cursor.execute("SELECT startTime FROM status WHERE srcId=%s AND dstId=%s AND detectionCode & %s <> 0 ORDER BY startTime DESC LIMIT 1", (self.srcId, self.dstId, self.detectionCode()))
      row = self.cursor.fetchone()
      if row is None:
        self.endTime = self.startTime
      else:
        self.endTime = row[0]

  def newProblem(self, statusEvent):
    self.startTime = statusEvent["startTime"]
    self.endTime = statusEvent["startTime"]
    self.srcId = statusEvent["srcId"]
    self.dstId = statusEvent["dstId"]
    self.info = statusEvent[self.pType]
    self.toUpdate = False
    #print "Current problem from %s to %s - (%s - %s) - info %s" %(self.srcId, self.dstId, self.startTime, self.endTime, self.info)

  def updateProblem(self, statusEvent):
    if statusEvent[self.pFlag()] != 0:
      # Problem is continuing
      self.endTime = statusEvent["startTime"]
      self.info = max(self.info, statusEvent[self.pType])
    else:
      if (statusEvent["startTime"] > self.endTime + timedelta(hours=1)):
        self.saveClosedProblem()
        self.initProblem(statusEvent)

  def processEvent(self, statusEvent):
    if self.hostsChanged(statusEvent):
      self.saveOpenProblem()
      self.loadLastProblem(statusEvent)
      #print "New host pair %s - %s" %(self.srcId, self.dstId)
    if self.startTime is None:
      # No current problem. Check if a new one has started.
      if statusEvent[self.pFlag()] != 0:
        self.newProblem(statusEvent)
    else:
      # Update current problem
      self.updateProblem(statusEvent)

class ProblemAggregator:

  def __init__(self, cnx):
    self.cursor = cnx.cursor(buffered=True)
    self.delayProblem = Problem(cnx, "delay")
    self.lossProblem = Problem(cnx, "pLoss")

  def processNewData(self, newDataQuery):
    startProcessing = time.time()
    self.cursor.execute(newDataQuery)
    for newRow in self.cursor:
      newData = dict(zip(self.cursor.column_names, newRow))
      self.delayProblem.processEvent(newData)
      self.lossProblem.processEvent(newData)
    self.delayProblem.saveOpenProblem()
    self.lossProblem.saveOpenProblem()
    endProcessing = time.time()
    print "Problems aggregated in %s s - %s delayProblems udpated - %s closed - %s opened\n                                       - %s lossProblems udpated - %s closed - %s opened" %(str(endProcessing - startProcessing), str(self.delayProblem.updated), str(self.delayProblem.closed), str(self.delayProblem.opened), str(self.lossProblem.updated), str(self.lossProblem.closed), str(self.lossProblem.opened))

class PunditDBUtil:
  @staticmethod
  def readDBConfiguration():
    Config = ConfigParser.ConfigParser()
    Config.read("../../../etc/pundit_db_scripts.conf")
    return dict(Config.items("DB"))

  @staticmethod
  def createConnection():
    return mysql.connector.connect(**PunditDBUtil.readDBConfiguration())

  @staticmethod
  def createDB():
    dbConf = PunditDBUtil.readDBConfiguration()
    dbName = dbConf.pop("database", None)
    cnx = mysql.connector.connect(**dbConf)
    cursor = cnx.cursor(buffered=True)
    cursor.execute("CREATE DATABASE " + dbName);
    cursor.execute("USE " + dbName);
    cursor.execute("""CREATE TABLE `statusStaging` (
    `startTime` int(11) DEFAULT NULL,
    `endTime` int(11) DEFAULT NULL,
    `srchost` varchar(256) DEFAULT NULL,
    `dsthost` varchar(256) DEFAULT NULL,
    `baselineDelay` float DEFAULT NULL,
    `detectionCode` int(11) DEFAULT NULL,
    `queueingDelay` float DEFAULT NULL,
    `lossRatio` float DEFAULT NULL,
    `reorderMetric` float DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `tracerouteStaging` (
    `ts` int(32) NOT NULL,
    `src` varchar(256) DEFAULT NULL,
    `dst` varchar(256) DEFAULT NULL,
    `hop_no` int(32) NOT NULL,
    `hop_ip` varchar(256) DEFAULT NULL,
    `hop_name` varchar(256) DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `localizationEventStaging` (
    `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `link_ip` int(10) unsigned DEFAULT NULL,
    `link_name` varchar(256) DEFAULT NULL,
    `det_code` tinyint(3) unsigned DEFAULT NULL,
    `val1` int(10) unsigned DEFAULT NULL,
    `val2` int(10) unsigned DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `hop` (
    `hopId` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
    `ip` varchar(45) NOT NULL,
    `name` varchar(256) NOT NULL,
    PRIMARY KEY (`hopId`),
    KEY `name_idx` (`name`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `host` (
    `hostId` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
    `name` varchar(256) NOT NULL,
    `site` varchar(32) DEFAULT NULL,
    PRIMARY KEY (`hostId`),
    KEY `name_idx` (`name`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `status` (
    `startTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `endTime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    `srcId` smallint(5) unsigned NOT NULL,
    `dstId` smallint(5) unsigned NOT NULL,
    `baselineDelay` float unsigned DEFAULT NULL,
    `detectionCode` bit(8) DEFAULT NULL,
    `queueingDelay` float unsigned DEFAULT NULL,
    `lossRatio` float unsigned DEFAULT NULL,
    `reorderMetric` float unsigned DEFAULT NULL,
    KEY `src_dst_time_idx` (`srcId`, `dstId`, `startTime`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `tracehop` (
    `tracerouteId` int(10) unsigned NOT NULL,
    `hopNumber` tinyint(3) unsigned NOT NULL,
    `nodeId` smallint(5) unsigned NOT NULL,
    KEY `trace_hop_idx` (`tracerouteId`, `hopNumber`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `traceroute` (
    `tracerouteId` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `srcId` smallint(5) unsigned NOT NULL,
    `dstId` smallint(5) unsigned NOT NULL,
    PRIMARY KEY (`tracerouteId`),
    KEY `src_dst_idx` (`srcId`, `dstId`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `tracerouteHistory` (
      `tracerouteId` int(10) unsigned NOT NULL,
      `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      KEY `traceroute_timestamp_idx` (`tracerouteId`,`timestamp`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `traceroutePeriod` (
    `tracerouteId` int(10) unsigned NOT NULL,
    `startTime` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `endTime` TIMESTAMP NULL DEFAULT NULL,
    KEY `traceroute_starttime_idx` (`tracerouteId`,`startTime`)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE `localizationEvent` (
    `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `nodeId` smallint(5) unsigned NOT NULL,
    `detectionCode` bit(8) NOT NULL,
    `val1` float unsigned DEFAULT NULL,
    `val2` float unsigned DEFAULT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    cursor.execute("""CREATE TABLE IF NOT EXISTS `problem` (
    `startTime` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `endTime` TIMESTAMP NULL DEFAULT NULL,
    `srcId` smallint(5) unsigned NOT NULL,
    `dstId` smallint(5) unsigned NOT NULL,
    `type` varchar(32) NOT NULL,
    `info` varchar(10) NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1""")

  @staticmethod
  def truncateDB(cnx):
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
      cursor.execute("TRUNCATE TABLE tracerouteHistory");
      cursor.execute("TRUNCATE TABLE tracerouteStaging");

  @staticmethod
  def resetDB():
      cnx = PunditDBUtil.createConnection()
      PunditDBUtil.truncateDB(cnx)
      cursor = cnx.cursor(buffered=True)
      cursor.execute("DROP DATABASE IF EXISTS " + PunditDBUtil.readDBConfiguration()["database"])
      cnx.close
      PunditDBUtil.createDB()

  @staticmethod
  def createTracerouteProcessing(cursor):
    cursor.execute("""CREATE TABLE `tracerouteProcessing` (
  `ts` int(32) NOT NULL,
  `src` varchar(256) DEFAULT NULL,
  `dst` varchar(256) DEFAULT NULL,
  `hop_no` int(32) NOT NULL,
  `hop_ip` varchar(256) DEFAULT NULL,
  `hop_name` varchar(256) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1""")

  @staticmethod
  def regenerateTraceroutePeriod(cnx):
    print "Regenerating traceroutePeriod table"
    cursor = cnx.cursor(buffered=True)
    # Create processing table to stop parallel processing
    PunditDBUtil.createTracerouteProcessing(cursor)
    cursor.execute("TRUNCATE traceroutePeriod")
    aggregator = PeriodAggregator(cnx)
    aggregator.processNewData("SELECT * FROM traceroute, tracerouteHistory WHERE traceroute.tracerouteID = tracerouteHistory.tracerouteId ORDER BY traceroute.srcId ASC, traceroute.dstId ASC, tracerouteHistory.timestamp ASC")
    cursor.execute("DROP TABLE tracerouteProcessing")
  
  @staticmethod
  def processTracerouteStaging(cnx):
    print "Processing tracerouteStaging table"
    cursor = cnx.cursor(buffered=True)
    PunditDBUtil.createTracerouteProcessing(cursor)
    cursor.execute("RENAME TABLE tracerouteStaging TO tracerouteTmp, tracerouteProcessing TO tracerouteStaging, tracerouteTmp TO tracerouteProcessing")
    cursor.execute("INSERT INTO host (name, site) SELECT DISTINCT src AS name, REVERSE(SUBSTRING_INDEX(REVERSE(src), '.', 2)) AS site FROM tracerouteProcessing WHERE src NOT IN (SELECT name FROM host)")
    cursor.execute("INSERT INTO host (name, site) SELECT DISTINCT dst AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dst), '.', 2)) AS site FROM tracerouteProcessing WHERE dst NOT IN (SELECT name FROM host)")
    cursor.execute("INSERT INTO hop (ip, name) SELECT DISTINCT hop_ip AS ip, hop_name AS name FROM tracerouteProcessing LEFT JOIN hop ON (hop.name = tracerouteProcessing.hop_name AND hop.ip = tracerouteProcessing.hop_ip) WHERE hop.ip IS NULL")
    cursor.execute("""CREATE TABLE `newTracerouteEntry` (
  `tracerouteId` int(10) unsigned NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY `traceroute_timestamp_idx` (`tracerouteId`,`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    processor = TracerouteProcessor(cnx)
    processor.processNewData("select src.hostId AS srcId, dst.hostId AS dstId, tracerouteProcessing.hop_no AS hopNumber, FROM_UNIXTIME(ts) AS timestamp, hop.hopId AS nodeId from tracerouteProcessing, host AS src, host AS dst, hop WHERE tracerouteProcessing.src = src.name AND tracerouteProcessing.dst = dst.name AND tracerouteProcessing.hop_ip = hop.ip AND tracerouteProcessing.hop_name = hop.name ORDER BY srcId, dstId, timestamp, hopNumber;")
    aggregator = PeriodAggregator(cnx)
    aggregator.processNewData("SELECT * FROM traceroute, newTracerouteEntry WHERE traceroute.tracerouteID = newTracerouteEntry.tracerouteId ORDER BY traceroute.srcId ASC, traceroute.dstId ASC, newTracerouteEntry.timestamp ASC")
    cursor.execute("INSERT INTO tracerouteHistory SELECT * FROM newTracerouteEntry")
    cursor.execute("DROP TABLE newTracerouteEntry")
    cursor.execute("DROP TABLE tracerouteProcessing")

  @staticmethod
  def processStatusStaging(cnx):
    print "Processing statusStaging table"
    cursor = cnx.cursor(buffered=True)
    # Create processsing table
    cursor.execute("""CREATE TABLE `statusProcessing` (
  `startTime` int(11) DEFAULT NULL,
  `endTime` int(11) DEFAULT NULL,
  `srchost` varchar(256) DEFAULT NULL,
  `dsthost` varchar(256) DEFAULT NULL,
  `baselineDelay` float DEFAULT NULL,
  `detectionCode` int(11) DEFAULT NULL,
  `queueingDelay` float DEFAULT NULL,
  `lossRatio` float DEFAULT NULL,
  `reorderMetric` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1""")
    # Atomically switch staging with processing
    cursor.execute("RENAME TABLE statusStaging TO statusTmp, statusProcessing TO statusStaging, statusTmp TO statusProcessing")
    print "Adding missing hosts"
    # Add missing src hosts
    cursor.execute("INSERT INTO host (name, site) SELECT DISTINCT srchost AS name, REVERSE(SUBSTRING_INDEX(REVERSE(srchost), '.', 2)) AS site FROM statusProcessing WHERE srchost NOT IN (SELECT name FROM host)")
    # Add missing dst hosts
    cursor.execute("INSERT INTO host (name, site) SELECT DISTINCT dsthost AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dsthost), '.', 2)) AS site FROM statusProcessing WHERE dsthost NOT IN (SELECT name FROM host)")
    # Create temporary table with normalized new status entries
    print "Importing new entries"
    cursor.execute("CREATE TABLE newStatus SELECT FROM_UNIXTIME(startTime) AS startTime, FROM_UNIXTIME(endTime) AS endTime, src.hostId AS srcId, dst.hostId AS dstId, baselineDelay AS baselineDelay, detectionCode AS detectionCode, queueingDelay AS queueingDelay, lossRatio AS lossRatio, reorderMetric AS reorderMetric FROM statusProcessing, host AS src, host AS dst WHERE statusProcessing.srchost = src.name AND statusProcessing.dsthost = dst.name")
    # Add new status entries
    cursor.execute("INSERT INTO status SELECT * FROM newStatus")
    # Process problems for new status entries
    print "Analizing problems"
    aggregator = ProblemAggregator(cnx)
    aggregator.processNewData("SELECT srcId, dstId, startTime, endTime, detectionCode & 2 <> 0 AS hasDelay, detectionCode & 4 <> 0 AS hasLoss, queueingDelay AS delay, lossRatio AS pLoss from newStatus ORDER BY srcId, dstId, startTime")
    # Cleanup
    cursor.execute("DROP TABLE newStatus")
    cursor.execute("DROP TABLE statusProcessing")
