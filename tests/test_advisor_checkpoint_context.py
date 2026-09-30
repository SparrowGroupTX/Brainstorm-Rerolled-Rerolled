"""Checkpoint context validation is read-only and never grants experiment jobs."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(HERE))
import finalize_runtime_checkpoint as F


class ContextTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.patch = patch.object(F, 'ROOT', self.root)
        self.patch.start(); self.addCleanup(self.patch.stop)
        refs = {}
        for role in ('authority', 'outcomes', 'budget', 'limits'):
            path = self.root / (role + '.json'); path.write_text(json.dumps({'fixture': role}), encoding='utf-8')
            refs[role] = {'path': path.name, 'sha256': F.sha(path)}
        self.value = {'schema': 1, 'kind': 'checkpoint_experiment_context', 'status': 'ACTIVE',
            'summary': 'Four pairs and four search jobs ran.',
            'outcome_summary': 'One loss and one running attempt; no verified win.',
            'limits_summary': 'Selected synthetic development data; no population odds.',
            'budget_summary': 'Four complete attempts reserved, two not started; existing authority remains active.',
            'verified_complete_win': False,
            'counts': {'source_components': 2, 'captured_pair_jobs': 4, 'captured_policy_evaluations': 8,
                       'search_workers': 4, 'complete_attempts': 2},
            'complete_attempt_outcomes': {'win': 0, 'loss': 1, 'error': 0, 'timeout': 0, 'unsupported': 0,
                                         'censored': 0, 'running': 1, 'not_started': 2},
            'unused_capacity': 'retained_under_existing_authority', 'evidence': refs}
        self.path = self.root / 'context.json'

    def load(self):
        self.path.write_text(json.dumps(self.value), encoding='utf-8')
        return F.experiment_context(self.path)

    def test_active_context_preserves_pending_jobs_and_precise_evidence(self):
        context = self.load(); session, budget = F.experiment_json(context)
        self.assertEqual(session['new_experiments'], 12)
        self.assertEqual(budget['complete_attempts'], 2)
        self.assertEqual(budget['captured_pair_jobs'], 4)
        self.assertEqual(budget['complete_attempt_outcomes']['not_started'], 2)
        self.assertEqual(session['cycle_status'], 'ACTIVE')
        self.assertEqual(session['unused_capacity'], 'retained_under_existing_authority')
        self.assertEqual(context['sha256'], F.sha(self.path))
        self.assertEqual(set(context['verified_evidence']), {'authority', 'outcomes', 'budget', 'limits'})

    def test_active_text_replaces_historical_zero_and_no_attempt_claims(self):
        sections = F.experiment_sections(self.load())
        text = '\n'.join(sections.values())
        self.assertIn('One loss and one running attempt', text)
        self.assertIn('does not close its existing unused jobs', text)
        self.assertNotIn('Policies 281 onward have no', text)
        self.assertNotIn('zero source workers', text)
        self.assertNotIn('No new source/search/replay/complete experiment.', text)

    def test_closed_context_cannot_hide_running_workers_or_renew_capacity(self):
        self.value['status'] = 'CLOSED'; self.value['unused_capacity'] = 'closed'
        with self.assertRaisesRegex(ValueError, 'closure'): self.load()
        self.value['complete_attempt_outcomes']['running'] = 0
        self.value['complete_attempt_outcomes']['loss'] = 2
        context = self.load()
        self.assertIn('unused capacity remains closed', F.experiment_sections(context)['navigation'])
        self.assertEqual(F.experiment_json(context)[1]['complete_attempt_outcomes']['not_started'], 2)

    def test_missing_narratives_counts_or_outcomes_fail_closed(self):
        original = copy.deepcopy(self.value)
        for key in ('summary', 'outcome_summary', 'limits_summary', 'budget_summary', 'counts', 'complete_attempt_outcomes'):
            self.value = copy.deepcopy(original); self.value.pop(key)
            with self.subTest(key=key), self.assertRaises(ValueError): self.load()

    def test_counts_and_verified_win_must_match_explicit_dispositions(self):
        self.value['counts']['complete_attempts'] = 3
        with self.assertRaisesRegex(ValueError, 'disagree'): self.load()
        self.value['counts']['complete_attempts'] = 2; self.value['verified_complete_win'] = True
        with self.assertRaisesRegex(ValueError, 'recorded win'): self.load()
        self.value['verified_complete_win'] = False; self.value['counts']['source_components'] = True
        with self.assertRaisesRegex(ValueError, 'integers'): self.load()

    def test_changed_evidence_or_context_outside_repository_rejected(self):
        (self.root / 'budget.json').write_text('{}', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'budget'): self.load()
        with self.assertRaises(ValueError): F.experiment_context(self.root.parent / 'context.json')

    def test_omitted_context_preserves_routine_only_defaults(self):
        self.assertIsNone(F.experiment_context(None))
        session, budget = F.experiment_json(None)
        self.assertEqual(session, {'new_experiments': 0, 'historical_budgets': 'closed', 'complete_win': False})
        self.assertEqual(budget['complete_attempts'], 0)
        self.assertIn('zero source workers', F.experiment_sections(None)['budget'])

    def historical(self):
        self.value.update(status='CLOSED', unused_capacity='closed', counts_scope='historical_closed_cycle',
                          release_counts={key: 0 for key in self.value['counts']}, verified_complete_win=True)
        self.value['complete_attempt_outcomes'].update(win=1, running=0)

    def test_historical_closed_counts_do_not_become_new_release_experiments(self):
        self.historical()
        context = self.load(); session, budget = F.experiment_json(context)
        self.assertEqual(session['new_experiments'], 0)
        self.assertFalse(session['complete_win'])
        self.assertTrue(session['historical_verified_complete_win'])
        self.assertEqual(session['historical_counts'], self.value['counts'])
        self.assertEqual(session['counts_scope'], 'historical_closed_cycle')
        self.assertEqual(session['outcomes_scope'], 'historical_closed_cycle')
        self.assertEqual(budget['complete_attempt_outcomes']['win'], 1)
        self.assertEqual(context['snapshot']['counts']['complete_attempts'], 2)
        for key in ('new_source_components', 'captured_pair_jobs', 'captured_policy_evaluations', 'searches', 'complete_attempts'):
            self.assertEqual(budget[key], 0)
        self.assertEqual(context['sha256'], F.sha(self.path))
        self.assertEqual(set(context['verified_evidence']), {'authority', 'outcomes', 'budget', 'limits'})

    def test_historical_scope_requires_closed_cycle_and_zero_integer_release_counts(self):
        self.historical(); original = copy.deepcopy(self.value)
        for change in ('active', 'missing', 'nonzero', 'boolean', 'negative', 'extra', 'unknown_scope'):
            self.value = copy.deepcopy(original)
            if change == 'active': self.value['status'] = 'ACTIVE'
            elif change == 'missing': self.value.pop('release_counts')
            elif change == 'nonzero': self.value['release_counts']['complete_attempts'] = 1
            elif change == 'boolean': self.value['release_counts']['complete_attempts'] = False
            elif change == 'negative': self.value['release_counts']['source_components'] = -1
            elif change == 'extra': self.value['release_counts']['new_slot'] = 0
            else: self.value['counts_scope'] = 'new_cycle'
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, 'Historical counts'):
                self.load()
        self.value = copy.deepcopy(original); self.value.pop('counts_scope')
        with self.assertRaisesRegex(ValueError, 'explicit historical counts scope'): self.load()

    def test_historical_scope_cannot_hide_dispositions_or_changed_evidence(self):
        self.historical(); self.value['complete_attempt_outcomes']['running'] = 1
        self.value['complete_attempt_outcomes']['loss'] = 0
        with self.assertRaisesRegex(ValueError, 'closure'): self.load()
        self.value['complete_attempt_outcomes'].update(running=0, loss=1)
        self.value['counts']['complete_attempts'] = 3
        with self.assertRaisesRegex(ValueError, 'disagree'): self.load()
        self.value['counts']['complete_attempts'] = 2
        (self.root / 'budget.json').write_text('{}', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'budget'): self.load()


if __name__ == '__main__': unittest.main()
