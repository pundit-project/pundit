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
    # def test_processStatusSequenceAll(self):
    #     cnx = PunditDBUtil.createConnection()
    #     PunditDBUtil.truncateDB(cnx)
    #     import_sql("../../../tests/db/statusSequence/status.1.sql")
    #     import_sql("../../../tests/db/statusSequence/status.2.sql")
    #     import_sql("../../../tests/db/statusSequence/status.3.sql")
    #     import_sql("../../../tests/db/statusSequence/status.4.sql")
    #     import_sql("../../../tests/db/statusSequence/status.5.sql")
    #     import_sql("../../../tests/db/statusSequence/status.6.sql")
    #     import_sql("../../../tests/db/statusSequence/status.7.sql")
    #     PunditDBUtil.processStatusStaging(cnx)
    #     cnx.close
    #     self.assertEqual(True, True)

    def test_processStatusSequenceIncremental(self):
        cnx = PunditDBUtil.createConnection()
        PunditDBUtil.resetDB()
        import_sql("../../../tests/db/statusSequence/status.1.sql")
        PunditDBUtil.processStatusStaging(cnx)
        import_sql("../../../tests/db/statusSequence/status.2.sql")
        PunditDBUtil.processStatusStaging(cnx)
        import_sql("../../../tests/db/statusSequence/status.3.sql")
        PunditDBUtil.processStatusStaging(cnx)
        import_sql("../../../tests/db/statusSequence/status.4.sql")
        PunditDBUtil.processStatusStaging(cnx)
        import_sql("../../../tests/db/statusSequence/status.5.sql")
        PunditDBUtil.processStatusStaging(cnx)
        import_sql("../../../tests/db/statusSequence/status.6.sql")
        PunditDBUtil.processStatusStaging(cnx)
        import_sql("../../../tests/db/statusSequence/status.7.sql")
        PunditDBUtil.processStatusStaging(cnx)
        cnx.close
        self.assertEqual(True, True)


    def test_something_else(self):
        self.assertEqual(True, True)


if __name__ == '__main__':
    unittest.main()
