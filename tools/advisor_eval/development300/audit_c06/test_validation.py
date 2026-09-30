"""Synthetic receipt tests only: no source, Lua, DLL or policy decisions."""
import copy
import unittest
from validation import verify_gold_callbacks


class GoldCallbacks(unittest.TestCase):
    def context(self, n):
        return {'deck': 'b_red', 'stake': 8, 'seeded': False, 'deck_wins': n, 'jokers': {'j_yorick': n, 'j_perkeo': n}}

    def test_no_terminal_is_unknown(self):
        result, issues = verify_gold_callbacks([], [], [], [])
        self.assertEqual(issues, [])
        self.assertEqual(result['synthetic_first_gold_count'], 0)
        self.assertIsNone(result['terminal_captured_goal'])

    def test_actual_callbacks_and_counts(self):
        callbacks = [{'callback': name, 'before': self.context(0), 'after': self.context(1), 'progress_verified': True}
                     for name in ('set_deck_win', 'set_joker_win')]
        goal = {'counts': {'complete': 2, 'missing': 148, 'unknown': 0, 'total': 150},
                'targets': [{'key': key, 'status': 'complete'} for key in ('j_yorick', 'j_perkeo')]}
        terminal = {'outcome': 'win', 'normal_progress': {'deck_progress': True, 'joker_progress': True,
                    'callbacks': [{'name': r['callback'], **{k: r[k] for k in ('before', 'after', 'progress_verified')}} for r in callbacks]}}
        result, issues = verify_gold_callbacks(callbacks, [terminal], [{'snapshot': {'completionist_goal': goal}}], [])
        self.assertEqual(issues, [])
        self.assertEqual(result['synthetic_first_gold_keys'], ['j_perkeo', 'j_yorick'])
        goal['counts']['complete'] = 3
        self.assertIn('Terminal Gold counts differ from original callback awards', verify_gold_callbacks(callbacks, [terminal], [{'snapshot': {'completionist_goal': goal}}], [])[1])

    def test_false_award_and_ineligible(self):
        row = {'callback': 'set_joker_win', 'before': self.context(0), 'after': self.context(0), 'progress_verified': True}
        self.assertTrue(verify_gold_callbacks([row], [], [], [])[1])
        row['after'] = self.context(1); row['after']['seeded'] = True
        self.assertTrue(verify_gold_callbacks([row], [], [], [])[1])

    def test_source_saved_needs_original_receipt(self):
        terminal = {'outcome': 'win', 'normal_progress': {'deck_progress': False, 'joker_progress': False,
                    'callbacks': {}, 'source_saved': True, 'final_context': {'ante': 8, 'chips': 30, 'target': 100}}}
        goal = {'counts': {'complete': 0, 'missing': 150, 'unknown': 0, 'total': 150}, 'targets': []}
        context = [{'snapshot': {'completionist_goal': goal}}]
        self.assertTrue(verify_gold_callbacks([], [terminal], context, [])[1])
        self.assertEqual(verify_gold_callbacks([], [terminal], context, [{'ante': 8, 'chips': 30, 'target': 100}])[1], [])


if __name__ == '__main__':
    unittest.main()
