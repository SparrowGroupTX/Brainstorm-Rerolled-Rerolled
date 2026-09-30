"""Manufactured collector arithmetic checks; no simulator or GPU invocation."""
import unittest
import numpy as np
from .train import pad_numpy, seed_for, training_reward, wilson


class CollectorTests(unittest.TestCase):
    def test_empty_candidate_row_rejected(self):
        item={'global':np.zeros(2),'entities':np.zeros((0,3)),'candidates':np.zeros((0,4))}
        with self.assertRaises(ValueError): pad_numpy([item])

    def test_variable_padding_masks(self):
        a={'global':np.zeros(2),'entities':np.ones((1,3)),'candidates':np.ones((2,4))}
        b={'global':np.zeros(2),'entities':np.zeros((0,3)),'candidates':np.ones((1,4))}
        g,e,em,c,cm=pad_numpy([a,b])
        np.testing.assert_array_equal(em,[[True],[False]])
        np.testing.assert_array_equal(cm,[[True,True],[True,False]])
        self.assertEqual(c[1,1].sum(),0)

    def test_partition_seed_prefixes_cannot_overlap(self):
        groups=[{seed_for(n,i) for i in range(100)} for n in ('L355TRAIN','L355DEV','L355FINAL')]
        self.assertTrue(all(len(g)==100 for g in groups))
        self.assertFalse(groups[0]&groups[1] or groups[0]&groups[2] or groups[1]&groups[2])

    def test_terminal_shaping_removes_progress_potential(self):
        value=training_reward({'outcome':'loss','blinds_cleared':20},{'blinds_cleared':20},True)
        self.assertAlmostEqual(value,-5.0005)

    def test_wilson_zero_wins_retains_upper_uncertainty(self):
        self.assertIsNone(wilson(0,0))
        self.assertGreater(wilson(0,64)[1],0)


if __name__ == '__main__': unittest.main()
