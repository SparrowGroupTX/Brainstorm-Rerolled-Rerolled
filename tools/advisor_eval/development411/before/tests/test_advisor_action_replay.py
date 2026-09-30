from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'tools' / 'advisor_eval'
sys.path.insert(0, str(TOOLS))
import action_replay


class ActionInterventionTests(unittest.TestCase):
    def setUp(self):
        self.base = {'step': 7, 'action': {'kind': 'buy', 'area': 'shop_jokers', 'index': 2},
                     'card_key': 'j_runner', 'reason': 'Test retained matching-hand growth.'}

    def test_concrete_visible_buy_admitted(self):
        self.assertEqual(action_replay.validate_intervention(self.base), self.base)

    def test_save_has_no_fake_card(self):
        value = {**self.base, 'action': {'kind': 'leave_shop'}, 'card_key': None}
        self.assertEqual(action_replay.validate_intervention(value), value)
        with self.assertRaises(ValueError):
            action_replay.validate_intervention({**value, 'card_key': 'j_runner'})

    def test_wrong_area_or_missing_identity_rejected(self):
        for value in ({**self.base, 'card_key': None},
                      {**self.base, 'action': {'kind': 'buy', 'area': 'hand', 'index': 2}},
                      {**self.base, 'action': {'kind': 'open', 'area': 'shop_jokers', 'index': 2}}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                action_replay.validate_intervention(value)

    def test_hypothesis_and_boundary_required(self):
        for values in ({'step': True}, {'step': 0}, {'step': 501}, {'reason': ''}, {'future_offer': 'j_joker'}):
            with self.subTest(values=values), self.assertRaises(ValueError):
                action_replay.validate_intervention({**self.base, **values})

    def test_only_one_shop_action_supported(self):
        for action in ({'kind': 'play', 'indices': [1]}, {'kind': 'buy', 'area': 'shop_jokers', 'index': 0},
                       {'kind': 'reroll', 'seed': 'future'}, {'kind': 'sell', 'area': 'jokers', 'index': 1}):
            with self.subTest(action=action), self.assertRaises(ValueError):
                action_replay.validate_intervention({**self.base, 'action': action})

    def test_override_only_applied_to_candidate(self):
        directory = Path('C:/registered')
        manifest = {'requests': [{'challenge': 'c_omelette_1', 'seed': 'TEST'}],
                    'install': 'C:/game', 'action_limit': None}
        registration = {'intervention': self.base}
        commands = {role: action_replay.command_for(directory, manifest, registration, role)
                    for role in ('incumbent', 'candidate')}
        self.assertNotIn('--override', commands['incumbent'])
        self.assertIn('--override', commands['candidate'])
        for command in commands.values():
            self.assertIn('--replay-policy-root', command)
            self.assertIn('--replay-until-step', command)
            self.assertNotIn('--stop-after-step', command)


if __name__ == '__main__':
    unittest.main()
