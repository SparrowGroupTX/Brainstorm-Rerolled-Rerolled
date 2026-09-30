from __future__ import annotations
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(TOOLS))
import engine_probe
spec = importlib.util.spec_from_file_location('paired_policy', TOOLS / 'paired_policy_audit.py')
P = importlib.util.module_from_spec(spec);spec.loader.exec_module(P)


class PairedPolicyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory();self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        product = self.root / 'source'
        for name in ['Advisor/scoring.lua', 'Core/Brainstorm.lua', 'Core/challenge_opening.lua',
                     'UI/advisor.lua', 'UI/ui.lua', 'UI/challenge_opening.lua', 'lovely.toml']:
            target = product / 'Brainstorm' / name;target.parent.mkdir(parents=True, exist_ok=True);target.write_text('-- fixture')
        install = self.root / 'install';install.mkdir()
        (install / 'Balatro.exe').write_bytes(b'fixture rules');(install / 'lua51.dll').write_bytes(b'fixture runtime')
        self.directory = self.root / 'run'
        self.manifest = P.initialize(self.directory, {role: product for role in P.ROLES}, install,
                                     [{'challenge': 'c_fragile_1', 'seed': 'PAIREDFIXTURE'}], 20, 3)

    def record(self, role='incumbent', outcome='loss', seconds=10, diagnostic=None):
        m = self.manifest;request = m['requests'][0]
        provenance = {'type': 'engine_probe_provenance', 'validation': 'experimental', **request,
                      **{key: m[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest', 'start_distribution',
                                                'retry_context_spec', 'retry_context_spec_digest')},
                      **m['policies'][role], 'opening_policy_loaded': False}
        rows = [provenance, engine_probe.retry_context_record(),
                {'type': 'engine_probe_profile', 'unlock_profile_digest': 'same-profile', 'qualification_compatible': False},
                {'type': 'engine_episode_profile', 'step': 1, 'advisor_seconds': .1, 'score_calls': 16},
                {'type': 'engine_episode_action', 'step': 1, 'action': {'kind': 'play', 'indices': [1]}}]
        if outcome in ('win', 'loss'):
            rows.append({'type': 'engine_episode_terminal', 'outcome': outcome, 'game_won': outcome == 'win', 'ante': 8,
                         'source_profile_completed': outcome == 'win', 'source_game_won': outcome == 'win', 'game_over': outcome == 'loss'})
        elif outcome == 'censored': rows.append({'type': 'engine_episode_stopped', 'reason': 'development_action_limit'})
        elif outcome == 'unsupported': rows.append({'type': 'engine_probe_blocked', 'reason': 'HEADLESS_BOUNDARY fixture'})
        if diagnostic: rows.append({'type': diagnostic})
        trace = self.directory / (role + '.log')
        trace.write_text('\n'.join(json.dumps(row) for row in rows) + '\n', encoding='utf-8')
        code = 'timeout' if outcome == 'timeout' else 1 if outcome == 'unsupported' else 0
        record = P.episode_record(trace, request['challenge'], request['seed'], code, seconds, P.command_for(self.directory, m, role, request))
        record.update({'role': role, 'pair_index': 0})
        return record

    def test_freeze_integrity_and_no_overwrite(self):
        self.assertEqual(P.verify_manifest(self.directory, True)['manifest_digest'], self.manifest['manifest_digest'])
        with self.assertRaises(FileExistsError):
            P.initialize(self.directory, {}, self.root, self.manifest['requests'], 10, 3)

    def test_frozen_mutation_rejected(self):
        path = self.directory / 'candidate/Brainstorm/Advisor/scoring.lua';path.write_text('changed')
        with self.assertRaisesRegex(ValueError, 'Frozen product changed'): P.verify_manifest(self.directory)

    def test_manifest_mutation_rejected(self):
        path = self.directory / 'manifest.json';value = json.loads(path.read_text());value['timeout_seconds'] = 99;P.write_json(path, value)
        with self.assertRaisesRegex(ValueError, 'manifest changed'): P.verify_manifest(self.directory)

    def test_adapter_mutation_rejected(self):
        (self.directory / 'adapter/engine_run.lua').write_text('-- changed')
        with self.assertRaisesRegex(ValueError, 'Frozen adapter changed'): P.verify_manifest(self.directory)

    def test_trace_mutation_rejected(self):
        r = self.record();Path(r['trace']).write_text('{}')
        with self.assertRaisesRegex(ValueError, 'Trace digest'): P.checked_record(self.directory, self.manifest, r)

    def test_seed_and_start_mismatches_rejected(self):
        for key, value in [('seed', 'OTHER'), ('start_distribution', {'kind': 'filtered'}), ('adapter_digest', 'wrong'), ('policy_digest', 'wrong')]:
            r = self.record();path = Path(r['trace']);rows = [json.loads(x) for x in path.read_text().splitlines()]
            rows[0][key] = value;path.write_text('\n'.join(json.dumps(x) for x in rows));r['trace_digest'] = P.file_digest(path)
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'provenance'):
                P.checked_record(self.directory, self.manifest, r)

    def test_cached_win_cannot_override_trace_mismatch(self):
        r = self.record('incumbent', 'win', diagnostic='engine_episode_score_mismatch');r['outcome'] = 'win'
        actual = P.checked_record(self.directory, self.manifest, r)
        self.assertEqual(actual['outcome'], 'error')
        self.assertIsNone(P.retry_proxy([actual])['seconds'])

    def test_cached_win_cannot_override_timeout(self):
        r = self.record('incumbent', 'win');r['exit_code'] = 'timeout';r['outcome'] = 'win'
        self.assertEqual(P.checked_record(self.directory, self.manifest, r)['outcome'], 'timeout')

    def test_incomplete_and_unsupported_not_losses(self):
        for outcome in ('censored', 'unsupported', 'timeout'):
            r = self.record('incumbent', outcome)
            actual = P.checked_record(self.directory, self.manifest, r)
            self.assertEqual(actual['outcome'], outcome)
            self.assertIsNone(P.retry_proxy([actual])['seconds'])

    def test_retry_time_includes_failed_attempts_and_overhead(self):
        records = [{'outcome': 'win', 'elapsed_seconds': 100}, {'outcome': 'loss', 'elapsed_seconds': 20}, {'outcome': 'loss', 'elapsed_seconds': 30}]
        self.assertEqual(P.retry_proxy(records, 5)['seconds'], 160)
        self.assertIsNone(P.retry_proxy(records[1:])['seconds'])
        self.assertIsNone(P.retry_proxy(records + [{'outcome': 'censored', 'elapsed_seconds': 1}])['seconds'])

    def test_unqualified_terminal_proxy_never_promotes(self):
        records = [self.record('incumbent', 'win', 100), self.record('candidate', 'win', 50)]
        report = P.compare(self.manifest, records)
        self.assertFalse(report['promotion_allowed']);self.assertIsNone(report['recommended_policy'])
        self.assertIn('adapter_unqualified', report['blockers'])
        self.assertEqual(report['cohorts'][0]['diagnostic_candidate_minus_incumbent_seconds'], -50)
        self.assertIsNone(report['cohorts'][0]['roles']['candidate']['qualified_win_rate'])

    def test_missing_duplicate_and_unmatched_profiles_block_comparison(self):
        a, b = self.record('incumbent', 'win'), self.record('candidate', 'win')
        missing = P.compare(self.manifest, [a]);self.assertEqual(len(missing['missing']), 1)
        duplicate = P.compare(self.manifest, [a, a, b]);self.assertIn('duplicate_attempts', duplicate['blockers'])
        self.assertIsNone(duplicate['cohorts'][0]['diagnostic_candidate_minus_incumbent_seconds'])
        b['unlock_profile']['unlock_profile_digest'] = 'different'
        mismatch = P.compare(self.manifest, [a, b]);self.assertIn('unlock_profile_mismatch_or_missing', mismatch['blockers'])
        self.assertIsNone(mismatch['cohorts'][0]['diagnostic_candidate_minus_incumbent_seconds'])

    def test_audit_generates_report_and_preserves_missing_attempts(self):
        r = self.record();(self.directory / 'episodes.jsonl').write_text(json.dumps(r) + '\n')
        report = P.audit(self.directory)
        self.assertTrue((self.directory / 'report.json').exists())
        self.assertEqual(report['requested_attempts'], 2);self.assertEqual(report['valid_records'], 1)

    def test_exact_full_replay_command(self):
        request = self.manifest['requests'][0]
        normal = P.command_for(self.directory, self.manifest, 'candidate', request)
        full = P.command_for(self.directory, self.manifest, 'candidate', request, True)
        self.assertEqual(normal[:-2], full);self.assertEqual(normal[-2:], ['--stop-after-step', '3'])
        self.assertIn(str(self.directory / 'candidate'), full)
        self.assertIn('PAIREDFIXTURE', full)

    def test_execution_args_and_counterfactual_rejected(self):
        r = self.record();r['command'] += ['--override', 'fake.json']
        with self.assertRaisesRegex(ValueError, 'execution arguments'): P.checked_record(self.directory, self.manifest, r)
        r = self.record();path = Path(r['trace']);rows = [json.loads(x) for x in path.read_text().splitlines()]
        rows[0]['counterfactual'] = True;path.write_text('\n'.join(json.dumps(x) for x in rows));r['trace_digest'] = P.file_digest(path)
        with self.assertRaisesRegex(ValueError, 'Counterfactual'): P.checked_record(self.directory, self.manifest, r)

    def test_nonterminal_partner_blocks_both_retry_proxies(self):
        a, b = self.record('incumbent', 'win'), self.record('candidate', 'censored')
        report = P.compare(self.manifest, [a, b])
        for role in P.ROLES:
            self.assertIsNone(report['cohorts'][0]['roles'][role]['diagnostic_retry_time_proxy']['seconds'])

    def test_prefix_timing_stops_at_first_action_difference(self):
        a, b = self.record('incumbent', 'censored'), self.record('candidate', 'censored')
        for r in (a, b):
            r['action_sequence'] = [(1, {'kind': 'play', 'indices': [1]}), (2, {'kind': 'discard', 'indices': [1]})]
            r['profiles'] = [{'step': 1, 'advisor_seconds': 1, 'score_calls': 16}, {'step': 2, 'advisor_seconds': 99, 'score_calls': 10000}]
        b['action_sequence'][1] = (2, {'kind': 'play', 'indices': [2]});b['profiles'][0]['score_calls'] = 10
        report = P.compare(self.manifest, [a, b]);pair = report['paired_prefix_latency_diagnostics'][0]
        self.assertEqual(pair['matching_action_prefix'], 1);self.assertEqual(pair['candidate_minus_incumbent_score_calls'], -6)

    def test_full_replay_writes_reviewable_command_without_execution(self):
        from argparse import Namespace
        r = self.record('candidate');(self.directory / 'episodes.jsonl').write_text(json.dumps(r) + '\n')
        output = self.root / 'replay'
        result = P.replay(Namespace(directory=self.directory, pair=0, role='candidate', full_episode=True,
                                    timeout=20, output_dir=output, execute=False))
        self.assertFalse(result['executed']);self.assertNotIn('--stop-after-step', result['command'])
        self.assertTrue((output / 'replay.json').exists());self.assertFalse((output / 'replay.log').exists())

    def test_multiple_provenance_records_rejected(self):
        r = self.record();path = Path(r['trace']);raw = path.read_text();path.write_text(raw + raw.splitlines()[0] + '\n');r['trace_digest'] = P.file_digest(path)
        with self.assertRaisesRegex(ValueError, 'exactly one provenance'): P.checked_record(self.directory, self.manifest, r)

    def test_missing_actual_retry_context_rejects_cached_terminal_win(self):
        record=self.record(outcome='win');path=Path(record['trace'])
        rows=[json.loads(line) for line in path.read_text().splitlines()]
        rows=[row for row in rows if row.get('type')!='engine_probe_retry_context']
        path.write_text('\n'.join(json.dumps(row) for row in rows));record['trace_digest']=P.file_digest(path)
        with self.assertRaisesRegex(ValueError,'matching applied'):
            P.checked_record(self.directory,self.manifest,record)

    def test_old_schema_without_retry_metadata_remains_explicitly_unreported(self):
        record=self.record();path=Path(record['trace'])
        rows=[json.loads(line) for line in path.read_text().splitlines()]
        rows=[row for row in rows if row.get('type')!='engine_probe_retry_context']
        for key in ('retry_context_spec','retry_context_spec_digest'):
            rows[0].pop(key);self.manifest.pop(key)
        self.manifest['schema']=1
        path.write_text('\n'.join(json.dumps(row) for row in rows));record['trace_digest']=P.file_digest(path)
        actual=P.checked_record(self.directory,self.manifest,record)
        self.assertEqual(actual['retry_context']['mode'],'historical_unreported')
        self.assertEqual(actual['outcome'],'loss')

    def test_personal_settings_excluded_from_new_hashes_and_freezes(self):
        product = self.root / 'source';config = product / 'Brainstorm/config.lua'
        before = P.policy_hashes(product);config.write_text('return {personal_preference=true}')
        self.assertEqual(P.policy_hashes(product), before)
        target = self.root / 'new-freeze';P.freeze_product(product, target)
        self.assertFalse((target / 'Brainstorm/config.lua').exists())
        self.assertEqual(config.read_text(), 'return {personal_preference=true}')
        config.write_text('return {personal_preference=false}');self.assertEqual(P.policy_hashes(product), before)

    def test_historical_settings_manifest_remains_verifiable(self):
        for role in P.ROLES:
            path = self.directory / role / 'Brainstorm/config.lua';path.write_text('-- historical config')
            policy = self.manifest['policies'][role];policy['policy_files']['Brainstorm/config.lua'] = P.file_digest(path)
            policy['policy_digest'] = P.digest(policy['policy_files'])
        self.manifest.pop('manifest_digest');self.manifest['manifest_digest'] = P.digest(self.manifest)
        P.write_json(self.directory / 'manifest.json', self.manifest)
        self.assertEqual(P.verify_manifest(self.directory)['manifest_digest'], self.manifest['manifest_digest'])


if __name__ == '__main__': unittest.main()
