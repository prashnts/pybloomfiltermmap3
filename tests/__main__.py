import sys
import unittest
from . import test_all

if __name__ == '__main__':
    runner = unittest.TextTestRunner()
    result = runner.run(test_all())
    sys.exit(not result.wasSuccessful())
