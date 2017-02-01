#!/usr/bin/python

import mysql.connector
import time
from utility import PunditDBUtil

cnx = PunditDBUtil.createConnection()

cursor = cnx.cursor(buffered=True)

createTimeSeries = """CREATE TABLE timeSeries SELECT FROM_UNIXTIME(FLOOR((UNIX_TIMESTAMP(startTime) / (5 * 60))) * (5 * 60)) AS timeBlock, srcId AS srcId, dstId AS dstId, MIN(queueingDelay) AS delayMin,  AVG(queueingDelay) AS delay,  MAX(queueingDelay) AS delayMax, MAX(lossRatio) AS loss, MAX(((detectionCode & 2) <> 0)) AS hasDelay, MAX(((detectionCode & 4) <> 0)) AS hasLoss FROM status GROUP BY timeBlock, srcId, dstId ORDER BY srcId, dstId, startTime"""

start = time.time();
print "Recalculate time series"
cursor.execute("DROP TABLE IF EXISTS timeSeries");
cursor.execute(createTimeSeries);
end = time.time();
print "Done in %s s" %(str(end-start));
