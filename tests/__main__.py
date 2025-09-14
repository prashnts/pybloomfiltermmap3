import unittest
from . import test_all

if __name__ == '__main__':
    runner = unittest.TextTestRunner()
    runner.run(test_all())