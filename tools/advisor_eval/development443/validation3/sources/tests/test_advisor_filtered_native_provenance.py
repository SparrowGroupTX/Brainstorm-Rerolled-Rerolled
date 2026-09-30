from pathlib import Path
import copy
import hashlib
import json
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/advisor_eval'))
import filtered_opening_audit as audit
import filtered_engine_compare as compare


class FilteredNativeProvenanceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.product = self.root / 'Brainstorm'
        (self.product / 'Core').mkdir(parents=True)
        self.core = self.product / 'Core/Brainstorm.lua'
        self.legacy = self.product / 'Immolate-v2.16.dll'
        self.legacy.write_bytes(b'legacy native fixture, never executed')
        data = b'new tested native fixture, never executed'
        self.sidecar = self.product / ('Immolate-advisor-' + hashlib.sha256(data).hexdigest() + '.dll')
        self.sidecar.write_bytes(data)
        self.core.write_text('Brainstorm.NATIVE_FILE = "' + self.sidecar.name + '"')
        self.policy = self.fingerprint()
        self.request = {'challenge': 'c_city_1', 'seed': 'FRESH1', 'targets': 'j_perkeo'}

    def fingerprint(self):
        files = {path.relative_to(self.root).as_posix(): audit.file_digest(path)
                 for path in (self.core, self.legacy, self.sidecar)}
        return {'policy_files': files, 'policy_digest': audit.digest(files)}

    def both_auditors(self, policy, opening_changes=None):
        manifest = {'policy': policy, 'rules_digest': 'rules', 'runtime_digest': 'runtime',
                    'adapter_digest': 'adapter', 'targets': 'j_perkeo', 'search_limit': 10}
        opening = {'result': {'status': 'not_found', 'next_seed': 'NEXT1'},
                   'search_start': 'FRESH1', 'search_limit': 10, 'targets': 'j_perkeo', 'threads': 1,
                   'search_seconds': .2, 'native_sha256': policy.get('native_sha256', audit.file_digest(self.legacy))}
        if 'native_file' in policy:
            opening['native_file'] = policy['native_file']
        opening.update(opening_changes or {})
        trace = self.root / 'trace.log'
        trace.write_text(json.dumps({'type': 'engine_probe_provenance', **self.request,
            **{k: manifest[k] for k in ('rules_digest', 'runtime_digest', 'adapter_digest')},
            'policy_digest': policy['policy_digest'], 'policy_files': policy['policy_files'],
            'start_distribution': {'kind': 'filtered_two_soul_native_v1', 'targets': 'j_perkeo'},
            'opening_policy_loaded': False, 'run_seed': None, 'opening': opening}))
        record = {'trace': str(trace), 'trace_digest': audit.file_digest(trace), 'outcome': 'censored',
                  'reason': 'bounded_native_miss', 'elapsed_seconds': .4}
        return [lambda: audit.inspect_record(record, manifest, 'filtered', self.request),
                lambda: compare.inspect(record, manifest, self.request)]

    def rejected_by_both(self, policy, changes=None):
        for inspect in self.both_auditors(policy, changes):
            with self.assertRaises(ValueError):
                inspect()

    def test_registration_uses_frozen_loader_and_keeps_both_files_without_loading(self):
        with patch('opening_support.ctypes.CDLL', side_effect=AssertionError('No native execution')):
            registered = audit.register_native_policy(self.root, self.policy)
        self.assertNotIn('native_file', self.policy)
        self.assertEqual(registered['native_file'], self.sidecar.name)
        self.assertEqual(registered['native_sha256'], audit.file_digest(self.sidecar))
        self.assertEqual(registered['policy_digest'], self.policy['policy_digest'])
        self.assertTrue(self.legacy.is_file())
        for inspect in self.both_auditors(registered):
            record = inspect()
            self.assertEqual(record['native_status'], 'not_found')
            self.assertFalse(record['setup_complete'])
            self.assertEqual(record['search_seconds'], .2)

    def test_registered_sidecar_requires_both_exact_trace_fields(self):
        registered = audit.register_native_policy(self.root, self.policy)
        for changes in ({'native_file': None}, {'native_file': self.legacy.name},
                        {'native_file': 'Immolate.dll'}, {'native_file': '../outside.dll'},
                        {'native_sha256': audit.file_digest(self.legacy)}, {'native_sha256': None}):
            with self.subTest(changes=changes):
                self.rejected_by_both(registered, changes)

    def test_trace_cannot_promote_an_unselected_binary_already_in_policy(self):
        self.core.write_text('Brainstorm.NATIVE_FILE = "Immolate-v2.16.dll"')
        registered = audit.register_native_policy(self.root, self.fingerprint())
        self.rejected_by_both(registered, {'native_file': self.sidecar.name,
                                          'native_sha256': audit.file_digest(self.sidecar)})

    def test_historical_manifest_stays_on_legacy_even_when_sidecar_is_present(self):
        for changes in (None, {'native_file': self.legacy.name}):
            for inspect in self.both_auditors(self.policy, changes):
                self.assertEqual(inspect()['native_status'], 'not_found')
        self.rejected_by_both(self.policy, {'native_file': self.sidecar.name})
        self.rejected_by_both(self.policy, {'native_file': self.sidecar.name,
                                          'native_sha256': audit.file_digest(self.sidecar)})
        no_legacy = copy.deepcopy(self.policy)
        del no_legacy['policy_files']['Brainstorm/Immolate-v2.16.dll']
        self.rejected_by_both(no_legacy)

    def test_partial_or_mismatched_registration_never_falls_back(self):
        registered = audit.register_native_policy(self.root, self.policy)
        for field in ('native_file', 'native_sha256'):
            partial = copy.deepcopy(registered)
            del partial[field]
            self.rejected_by_both(partial)
        changed = copy.deepcopy(registered)
        changed['policy_files']['Brainstorm/' + self.sidecar.name] = '0' * 64
        self.rejected_by_both(changed)
        changed = copy.deepcopy(registered)
        changed['native_file'] = 'Immolate-advisor-' + '0' * 64 + '.dll'
        changed['policy_files']['Brainstorm/' + changed['native_file']] = changed['native_sha256']
        self.rejected_by_both(changed)

    def test_registration_detects_changed_loader_binary_and_unregistered_selection(self):
        self.core.write_text('Brainstorm.NATIVE_FILE = "Immolate-v2.16.dll"')
        with self.assertRaisesRegex(ValueError, 'loader differs'):
            audit.register_native_policy(self.root, self.policy)
        current = self.fingerprint()
        self.legacy.write_bytes(b'changed after freeze')
        with self.assertRaisesRegex(ValueError, 'binary differs'):
            audit.register_native_policy(self.root, current)
        current = self.fingerprint()
        del current['policy_files']['Brainstorm/Immolate-v2.16.dll']
        with self.assertRaisesRegex(ValueError, 'binary differs'):
            audit.register_native_policy(self.root, current)


if __name__ == '__main__':
    unittest.main()
