"""Qualification protocol tests; these synthetic records are never game outcomes."""
from pathlib import Path
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(TOOLS))
import qualify_episode_boundaries as Q


class EpisodeBoundaryTests(unittest.TestCase):
    def records(self, scenario='terminal_win_final'):
        request = {'challenge': 'c_city_1', 'scenario': scenario, 'seed': 'BOUNDARY263'}
        spec = Q.engine_probe.profile_spec('source_defaults_v1')
        registration = {**{key: key for key in ('rules_digest', 'runtime_digest', 'adapter_digest', 'policy_digest')},
                        'profile_spec': spec}
        profile = Q.engine_probe.profile_record(spec['name'],
            '\n'.join(scope + ':fixture:true:true' for scope in sorted(spec['scope'])).encode())
        origin = {'type': 'engine_probe_provenance', **registration, 'challenge': request['challenge'],
                  'seed': request['seed'], 'test_scenario': scenario, 'counterfactual': True, 'followed_advice': False,
                  'profile_spec_digest': Q.paired.digest(spec),
                  'start_distribution': {'kind': 'source_parity_fixture', 'scenario': scenario}}
        terminal = {'type': 'engine_episode_terminal', 'outcome': 'win', 'game_won': True, 'ante': 8,
                    'source_game_won': True, 'source_profile_completed': True, 'game_over': False}
        return request, registration, [origin, profile, terminal]

    def test_matrix_contains_every_challenge_pair_and_explicit_extras(self):
        matrix = Q.requests()
        self.assertEqual(len(matrix), 47)
        self.assertEqual(len({(r['challenge'], r['scenario']) for r in matrix}), 47)
        for challenge in Q.paired.CHALLENGES:
            self.assertEqual({r['scenario'] for r in matrix if r['challenge'] == challenge and r['scenario'].startswith('terminal_')}
                & {'terminal_win_final', 'terminal_loss_final'}, {'terminal_win_final', 'terminal_loss_final'})

    def test_source_completion_and_profile_identity_are_both_required(self):
        request, registration, rows = self.records()
        self.assertTrue(Q.verify(rows, request, registration, 0)['passed'])
        rows[-1]['source_profile_completed'] = False
        self.assertFalse(Q.verify(rows, request, registration, 0)['passed'])

    def test_fixture_cannot_be_marked_as_an_ordinary_attempt(self):
        request, registration, rows = self.records()
        rows[0]['start_distribution'] = {'kind': 'ordinary'}
        self.assertIn('fixture_incorrectly_marked_ordinary', Q.verify(rows, request, registration, 0)['findings'])

    def test_profile_inventory_tampering_rejected(self):
        request, registration, rows = self.records()
        rows[1]['inventory'][0]['unlocked'] = 'false'
        self.assertIn('profile_inventory_mismatch', Q.verify(rows, request, registration, 0)['findings'])

    def test_partial_terminal_does_not_hide_timeout(self):
        request, registration, rows = self.records()
        checked = Q.verify(rows, request, registration, 'timeout')
        self.assertFalse(checked['passed'])
        self.assertEqual(checked['outcome'], 'timeout')

    def test_refill_requires_population_conservation(self):
        request, registration, rows = self.records('empty_hand_refill')
        rows[-1] = {'type': 'engine_episode_stopped', 'reason': 'development_empty_hand_refill'}
        rows.append({'type': 'engine_source_phase_verified', 'deck_before': 20, 'deck_after': 14,
                     'held_after': 6, 'game_over': False})
        self.assertTrue(Q.verify(rows, request, registration, 0)['passed'])
        rows[-1]['held_after'] = 7
        self.assertFalse(Q.verify(rows, request, registration, 0)['passed'])

    def test_failure_context_must_be_unique_and_retain_original_error(self):
        request, registration, rows = self.records('failure_context')
        rows[-1] = {'type': 'engine_probe_blocked', 'reason': 'HEADLESS_BOUNDARY synthetic failure context qualification'}
        context = {'type': 'engine_episode_failure_context', 'last_decision': {'step': 0}, 'snapshot': {'phase': 'blind'}}
        rows.append(context)
        self.assertTrue(Q.verify(rows, request, registration, 1)['passed'])
        rows.append(context)
        self.assertIn('missing_or_duplicate_failure_context', Q.verify(rows, request, registration, 1)['findings'])

    def test_forced_selection_requires_exact_semantics_and_population(self):
        request, registration, rows = self.records('forced_selection')
        rows[-1] = {'type': 'engine_episode_stopped', 'reason': 'development_forced_selection'}
        selection = {'type': 'engine_source_selection_verified', 'legacy_duplicate_reproduced': True,
                     'omitted_forced_rejected': True, 'zero_target_preserves_forced': True,
                     'targeted_omission_rejected': True, 'targeted_exact': True, 'ankh_noop_rejected': True, 'unique_population': True,
                     'discarded_count': 1, 'population_before': 52, 'population_after': 52}
        rows.append(selection)
        self.assertTrue(Q.verify(rows, request, registration, 0)['passed'])
        selection['discarded_count'] = 2
        self.assertIn('forced_selection_population_mismatch', Q.verify(rows, request, registration, 0)['findings'])
        selection['discarded_count'] = 1
        selection['targeted_omission_rejected'] = False
        self.assertIn('forced_selection_semantics_not_verified', Q.verify(rows, request, registration, 0)['findings'])


if __name__ == '__main__':
    unittest.main()
