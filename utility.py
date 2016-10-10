#!/bin/python

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

class PunditDBUtil:
  @staticmethod
  def regenerateTraceroutePeriod(cnx):
    print "Regenerating traceroutePeriod table"
    cursor = cnx.cursor(buffered=True)
    cursor.execute("TRUNCATE traceroutePeriod")
    aggregator = PeriodAggregator(cnx)
    aggregator.processNewData("SELECT * FROM traceroute, tracerouteHistory WHERE traceroute.tracerouteID = tracerouteHistory.tracerouteId ORDER BY traceroute.srcId ASC, traceroute.dstId ASC, tracerouteHistory.timestamp ASC")
    
