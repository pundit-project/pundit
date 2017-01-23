import os
import sys

sys.path.insert(0, '../../lib/PuNDIT/db')
import unittest
import subprocess
from utility import PunditDBUtil
os.chdir('../../lib/PuNDIT/db')

cnx = PunditDBUtil.createConnection()
dbConf = PunditDBUtil.readDBConfiguration()


def import_sql(filename):
    mysqlCommand = "mysql -u " + dbConf["user"]
    if dbConf["password"]:
        mysqlCommand += " -p " + dbConf["password"]
    mysqlCommand += " " + dbConf["database"] + " < "
    mysqlCommand += filename
    subprocess.call(mysqlCommand, shell=True)

class MyTestCase(unittest.TestCase):
    # def test_processTracerouteSequenceAll(self):
    #     cnx = PunditDBUtil.createConnection()
    #     PunditDBUtil.resetDB()
    #     import_sql("../../../tests/db/tracerouteSequence/traceroute.1.sql")
    #     import_sql("../../../tests/db/tracerouteSequence/traceroute.2.sql")
    #     import_sql("../../../tests/db/tracerouteSequence/traceroute.3.sql")
    #     PunditDBUtil.processTracerouteStaging(cnx)
    #     cnx.close
    #     self.assertEqual(True, True)

    def test_processTracerouteSequenceIncremental(self):
        cnx = PunditDBUtil.createConnection()
        PunditDBUtil.resetDB()
        import_sql("../../../tests/db/tracerouteSequence/traceroute.1.sql")
        PunditDBUtil.processTracerouteStaging(cnx)
        import_sql("../../../tests/db/tracerouteSequence/traceroute.2.sql")
        PunditDBUtil.processTracerouteStaging(cnx)
        import_sql("../../../tests/db/tracerouteSequence/traceroute.3.sql")
        PunditDBUtil.processTracerouteStaging(cnx)
        cnx.close
        self.assertEqual(True, True)


    def test_something_else(self):
        self.assertEqual(True, True)


if __name__ == '__main__':
    unittest.main()
