#!/usr/bin/env python3

import unittest
from version_gen import *


class TestTot(unittest.TestCase):
    def setUp(self):
        self.maxDiff = None

    def test_basic(self):
        ver_dict = {
            '5.3': {},
            '5.3.1': {},
            '5.3.2': {},
            '5.3.3': {},
            '5.4': {},
            '5.4.1': {},
        }
        versions = sorted(list(map(lambda x: vsn_split(x), ver_dict)))
        expected = [
            NsoV(version='5.3.3', tup=(5, 3, 3), extra='', type='normal'),
            NsoV(version='5.4.1', tup=(5, 4, 1), extra='', type='normal')
        ]
        self.assertEqual(expected, f_tot(versions))


    def test_special(self):
        ver_dict = {
            '5.3': {},
            '5.3.2': {},
            '5.3.2_ps': {},
            '5.4': {},
            '5.4_ps': {},
            '5.4.1': {},
        }
        versions = sorted(list(map(lambda x: vsn_split(x), ver_dict)))
        expected = [
            NsoV(version='5.3.2', tup=(5, 3, 2), extra='', type='normal'),
            NsoV(version='5.3.2_ps', tup=(5, 3, 2), extra='_ps', type='special'),
            NsoV(version='5.4.1', tup=(5, 4, 1), extra='', type='normal'),
            NsoV(version='5.4_ps', tup=(5, 4), extra='_ps', type='special'),
        ]
        self.assertEqual(expected, f_tot(versions))

    def test_nightly(self):
        ver_dict = {
            '5.4': {},
            '5.4.1': {},
            '5.4.2_200922.050200687.7da830a96f9c': {},
            '5.4.2_200923.050200682.b84c2c6f442e': {},
            '5.4_ps': {},
        }
        versions = sorted(list(map(lambda x: vsn_split(x), ver_dict)))
        expected = [
            NsoV(version='5.4.1', tup=(5, 4, 1), extra='', type='normal'),
            NsoV(version='5.4.2_200923.050200682.b84c2c6f442e', tup=(5, 4, 2, 200923, 50200682), extra='_200923.050200682.b84c2c6f442e', type='nightly'),
            NsoV(version='5.4_ps', tup=(5, 4), extra='_ps', type='special'),
        ]
        self.assertEqual(expected, f_tot(versions))

if __name__ == '__main__':
    unittest.main(verbosity=2)

