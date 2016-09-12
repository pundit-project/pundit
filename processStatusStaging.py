#!/usr/bin/python

import mysql.connector
import time

cnx = mysql.connector.connect(user='root', password='pythiaRush!', database='pythia_new')

cursor = cnx.cursor(buffered=True)

createStatusProcessing = """CREATE TABLE `statusProcessing` (
  `startTime` int(11) DEFAULT NULL,
  `endTime` int(11) DEFAULT NULL,
  `srchost` varchar(256) DEFAULT NULL,
  `dsthost` varchar(256) DEFAULT NULL,
  `baselineDelay` float DEFAULT NULL,
  `detectionCode` int(11) DEFAULT NULL,
  `queueingDelay` float DEFAULT NULL,
  `lossRatio` float DEFAULT NULL,
  `reorderMetric` float DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1"""

switchStatusStagingAndProcessing = """RENAME TABLE statusStaging TO statusTmp,
   statusProcessing TO statusStaging,
   statusTmp TO statusProcessing"""

addMissingSrcHosts = """INSERT INTO host (name, site) SELECT DISTINCT srchost AS name, REVERSE(SUBSTRING_INDEX(REVERSE(srchost), '.', 2)) AS site FROM statusProcessing WHERE srchost NOT IN (SELECT name FROM host)"""

addMissingDstHosts = """INSERT INTO host (name, site) SELECT DISTINCT dsthost AS name, REVERSE(SUBSTRING_INDEX(REVERSE(dsthost), '.', 2)) AS site FROM statusProcessing WHERE dsthost NOT IN (SELECT name FROM host)"""

convertStatusEntries = """INSERT INTO status SELECT FROM_UNIXTIME(startTime) AS startTime, FROM_UNIXTIME(endTime) AS endTime, src.hostId AS srcId, dst.hostId AS dstId, baselineDelay AS baselineDelay, detectionCode AS detectionCode, queueingDelay AS queueingDelay, lossRatio AS lossRatio, reorderMetric AS reorderMetric FROM statusProcessing, host AS src, host AS dst WHERE statusProcessing.srchost = src.name AND statusProcessing.dsthost = dst.name"""

removeStatusProcessing = """DROP TABLE statusProcessing;"""

start = time.time();
cursor.execute(createStatusProcessing);
cursor.execute(switchStatusStagingAndProcessing);
print "Adding missing hosts"
cursor.execute(addMissingSrcHosts);
cursor.execute(addMissingDstHosts);
print "Converting status entries"
cursor.execute(convertStatusEntries);
print "Analize status for problems"

# Create problem processor
class ProblemProcessor:
  queryStatusProcessing = "SELECT srcId, dstId, UNIX_TIMESTAMP(startTime), UNIX_TIMESTAMP(endTime), detectionCode & 2 <> 0 AS hasDelay, detectionCode & 4 <> 0 AS hasLoss, queueingDelay, lossRatio from status ORDER BY srcId, dstId, startTime"
  findOpenProblem = "SELECT UNIX_TIMESTAMP(startTime), info FROM problem WHERE srcId = %s AND dstID = %s AND type = %s AND endTime IS NULL"
  updateOpenProblem = "UPDATE problem SET info = %s WHERE srcId = %s AND dstID = %s AND type = %s AND endTime IS NULL"
  addOpenProblem = "INSERT INTO problem (startTime, srcId, dstId, type, info) VALUES (FROM_UNIXTIME(%s), %s, %s, %s, %s)"
  addClosedProblem = "INSERT INTO problem (startTime, endTime, srcId, dstId, type, info) VALUES (FROM_UNIXTIME(%s), FROM_UNIXTIME(%s), %s, %s, %s, %s)"
  closeProblem = "UPDATE problem SET info = %s, endTime = FROM_UNIXTIME(%s) WHERE srcId = %s AND dstID = %s AND type = %s AND endTime IS NULL"

  currentSrcHost = None
  currentDstHost = None
  currentDelayProblemStart = None
  currentDelayProblemEnd = None
  currentDelayProblemInfo = 0
  currentDelayProblemOldProblem = False
  currentLossProblemStart = None
  currentLossProblemEnd = None
  currentLossProblemInfo = 0
  currentLossProblemOldProblem = False

  srcHost = None
  dstHost = None
  startTime = None
  endTime = None
  hasDelay = None
  hasLoss = None
  queueingDelay = None
  lossRatio = None

  cursor2 = None

  def delayInfo(self):
    return "%s ms" % self.currentDelayProblemInfo

  def lossInfo(self):
    return "%s%%" % self.currentLossProblemInfo

  def infoFromDB(self, info):
    if info.endswith(" ms"):
      return float(info[:-3])
    if info.endswith("%"):
      return float(info[:-1])
    return 0

  def pathChanged(self):
    return self.currentSrcHost != self.srcHost or self.currentDstHost != self.dstHost

  def updateCurrentPath(self):
    self.currentSrcHost = self.srcHost
    self.currentDstHost = self.dstHost

  def flushAndInitDelayProblem(self, initNext):
    if not self.currentDelayProblemStart is None:
      if self.currentDelayProblemOldProblem:
        self.cursor2.execute(self.updateOpenProblem, (self.delayInfo(), self.currentSrcHost, self.currentDstHost, "delay"))
      else:
        self.cursor2.execute(self.addOpenProblem, (self.currentDelayProblemStart, self.currentSrcHost, self.currentDstHost, "delay", self.delayInfo()))

    if initNext:
      self.cursor2.execute(self.findOpenProblem, (self.srcHost, self.dstHost, "delay"))
      row = self.cursor2.fetchone()
      if row is None:
        self.currentDelayProblemStart = None
        self.currentDelayProblemEnd = None
        self.currentDelayProblemInfo = 0
        self.currentDelayProblemOldProblem = False
      else:
        self.currentDelayProblemStart = row[0]
        self.currentDelayProblemEnd = row[0]
        self.currentDelayProblemInfo = self.infoFromDB(row[1])
        self.currentDelayProblemOldProblem = True

  def flushAndInitLossProblem(self, initNext):
    if not self.currentLossProblemStart is None:
      if self.currentLossProblemOldProblem:
        self.cursor2.execute(self.updateOpenProblem, (self.lossInfo(), self.currentSrcHost, self.currentDstHost, "pLoss"))
      else:
        self.cursor2.execute(self.addOpenProblem, (self.currentLossProblemStart, self.currentSrcHost, self.currentDstHost, "pLoss", self.lossInfo()))

    if initNext:
      self.cursor2.execute(self.findOpenProblem, (self.srcHost, self.dstHost, "pLoss"))
      row = self.cursor2.fetchone()
      if row is None:
        self.currentLossProblemStart = None
        self.currentLossProblemEnd = None
        self.currentLossProblemInfo = 0
        self.currentLossProblemOldProblem = False
      else:
        self.currentLossProblemStart = row[0]
        self.currentLossProblemEnd = row[0]
        self.currentLossProblemInfo = self.infoFromDB(row[1])
        self.currentLossProblemOldProblem = True

  def processDelayProblem(self):
    if self.currentDelayProblemStart is None:
      if self.hasDelay != 0:
        self.currentDelayProblemStart = self.startTime
        self.currentDelayProblemEnd = self.endTime
        self.currentDelayProblemInfo = max(self.currentDelayProblemInfo, self.queueingDelay)
    else:
      if self.hasDelay != 0:
        self.currentDelayProblemEnd = self.endTime
        self.currentDelayProblemInfo = max(self.currentDelayProblemInfo, self.queueingDelay)
      else:
        if self.endTime > (self.currentDelayProblemEnd + 3600):
          if self.currentDelayProblemOldProblem:
            self.cursor2.execute(self.closeProblem, (self.delayInfo(), self.currentDelayProblemEnd, self.currentSrcHost, self.currentDstHost, "delay"))
          else:
            self.cursor2.execute(self.addClosedProblem, (self.currentDelayProblemStart, self.currentDelayProblemEnd, self.currentSrcHost, self.currentDstHost, "delay", self.delayInfo()))
          self.currentDelayProblemStart = None
          self.currentDelayProblemEnd = None
          self.currentDelayProblemInfo = 0
          self.currentDelayProblemOldProblem = False

  def processLossProblem(self):
    if self.currentLossProblemStart is None:
      if self.hasLoss != 0:
        self.currentLossProblemStart = self.startTime
        self.currentLossProblemEnd = self.endTime
        self.currentLossProblemInfo = max(self.currentLossProblemInfo, self.lossRatio)
    else:
      if self.hasLoss != 0:
        self.currentLossProblemEnd = self.endTime
        self.currentLossProblemInfo = max(self.currentLossProblemInfo, self.lossRatio)
      else:
        if self.endTime > (self.currentLossProblemEnd + 3600):
          if self.currentLossProblemOldProblem:
            self.cursor2.execute(self.closeProblem, (self.lossInfo(), self.currentLossProblemEnd, self.currentSrcHost, self.currentDstHost, "pLoss"))
          else:
            self.cursor2.execute(self.addClosedProblem, (self.currentLossProblemStart, self.currentLossProblemEnd, self.currentSrcHost, self.currentDstHost, "pLoss", self.lossInfo()))
          self.currentLossProblemStart = None
          self.currentLossProblemEnd = None
          self.currentLossProblemInfo = 0
          self.currentLossProblemOldProblem = False


  def processStatus(self, cnx):
    cursor = cnx.cursor(buffered=True)
    self.cursor2 = cnx.cursor(buffered=True)
    cursor.execute(self.queryStatusProcessing)
    for (self.srcHost, self.dstHost, self.startTime, self.endTime, self.hasDelay, self.hasLoss, self.queueingDelay, self.lossRatio) in cursor:
      #print "New line %s %s %s %s %s %s %s %s" %(self.srcHost, self.dstHost, self.startTime, self.endTime, self.hasDelay, self.hasLoss, self.queueingDelay, self.lossRatio);
      if self.pathChanged():
        self.flushAndInitDelayProblem(True)
        self.flushAndInitLossProblem(True)
        self.updateCurrentPath()
      self.processDelayProblem()
      self.processLossProblem()
    self.flushAndInitDelayProblem(False)
    self.flushAndInitLossProblem(False)

problemProcessor = ProblemProcessor()
problemProcessor.processStatus(cnx)

cursor.execute(removeStatusProcessing);
cnx.commit();
end = time.time();
print "Done in %s s" %(str(end-start));
