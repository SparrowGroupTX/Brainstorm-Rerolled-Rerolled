"""Routine synthetic builder/admission tests; no source or binary access."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

HERE = Path(__file__).resolve().parent


def module(name):
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


builder = module('lucky_source_truth')
worker = module('lucky_source_worker')


class BuilderTests(unittest.TestCase):
    def test_extraction_is_exact(self):
        source = 'prefix\nfunction Card:one()\nreturn 1\nend\n\nfunction Card:two()\nend'
        self.assertEqual(builder.extract(source, 'function Card:one('), 'function Card:one()\nreturn 1\nend\n')

    def test_ambiguous_signature_rejected(self):
        with self.assertRaises(ValueError):
            builder.extract('function Card:x()\nend\nfunction Card:x()\nend\nfunction ender()end', 'function Card:x(')

    def test_missing_boundary_rejected(self):
        with self.assertRaises(ValueError):
            builder.extract('function x() return 1 end', 'function x(')

    def test_literal_does_not_interpolate(self):
        self.assertEqual(builder.literal(b'"\\\n\x00'), b'"\\034\\092\\010\\000"')

    def test_mode_checked_before_files(self):
        with self.assertRaises(ValueError):
            builder.build_probe(Path('never-read'), Path('never-read'), 'new_cases')


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        parent = mock.patch.object(worker.os, 'getppid', return_value=123)
        parent.start();self.addCleanup(parent.stop)
        self.manifest = {'kind': 'lucky_source_truth287', 'job_id': 'B1', 'mode': 'ordinary', 'cap_seconds': 30,
                         'rules': {'path': 'C:/frozen/Balatro.exe'},
                         'runtime': {'path': 'C:/frozen/lua51.dll'},
                         'sources': {'card.lua': {}, 'functions/common_events.lua': {}}}
        self.authority = {'kind': 'prospective287_authority', 'status': 'APPROVED', 'approved_by': 'user',
                          'replacements': 0, 'serial_only': True, 'allowed_job_ids': ['B1', 'B2'],
                          'expires_at_utc': '2099-01-01T00:00:00+00:00',
                          'per_job_caps': {'B1': 30, 'B2': 30}}
        self.started = {'job_id': 'B1', 'coordinator_pid': 123, 'deadline_unix': 130}

    def test_exact_authority_admits(self):
        worker.validate_manifest(self.manifest, 100, self.authority, self.started)

    def test_coordinator_marker_required(self):
        with self.assertRaises(ValueError):
            worker.validate_manifest(self.manifest, 100, self.authority, {})

    def test_coordinator_pid_must_be_actual_parent(self):
        with self.assertRaises(ValueError):
            worker.validate_manifest(self.manifest, 100, self.authority, {**self.started, 'coordinator_pid': 124})

    def test_modes_caps_deadlines(self):
        for field, value in [('mode', 'red'), ('cap_seconds', 31),
                             ('job_id', 'C1'), ('kind', 'old_source_authority')]:
            candidate = {**self.manifest, field: value}
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                worker.validate_manifest(candidate, 100, self.authority, self.started)
        for deadline in (99, 132):
            with self.subTest(deadline=deadline), self.assertRaises(ValueError):
                worker.validate_manifest(self.manifest, 100, self.authority, {**self.started, 'deadline_unix': deadline})

    def test_required_authority_guards(self):
        for field, value in [('kind', 'historical'), ('status', 'PROPOSAL_NOT_AUTHORIZED'), ('approved_by', None),
                             ('replacements', 1), ('serial_only', False), ('allowed_job_ids', []),
                             ('expires_at_utc', '1970-01-01T00:01:00+00:00'),
                             ('per_job_caps', {'B1': 31})]:
            candidate = {**self.authority, field: value}
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                worker.validate_manifest(self.manifest, 100, candidate, self.started)

    def test_extra_source_rejected(self):
        candidate = copy.deepcopy(self.manifest)
        candidate['sources']['save.lua'] = {}
        with self.assertRaises(ValueError):
            worker.validate_manifest(candidate, 100, self.authority, self.started)


class WorkerMainTests(unittest.TestCase):
    def setUp(self):
        parent = mock.patch.object(worker.os, 'getppid', return_value=123)
        parent.start();self.addCleanup(parent.stop)
        self.temporary = tempfile.TemporaryDirectory(prefix='lucky287-synthetic-admission-')
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.rules = self.directory / 'Balatro.exe'
        with zipfile.ZipFile(self.rules, 'w') as archive:
            archive.writestr('card.lua', 'synthetic card source; never executed')
            archive.writestr('functions/common_events.lua', 'synthetic event source; never executed')
        def fixture(name, text):
            path = self.directory / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8')
            return {'path': str(path), 'sha256': worker.sha(path)}
        def item(path):
            return {'path': str(path), 'sha256': worker.sha(path)}
        self.manifest = {'kind': 'lucky_source_truth287', 'job_id': 'B1', 'mode': 'ordinary', 'cap_seconds': 30,
            'rules': item(self.rules), 'runtime': fixture('lua51.dll', 'synthetic non-executable bytes'),
            'probe': fixture('probe.lua', 'synthetic non-executed probe'), 'worker': item(Path(worker.__file__)),
            'builder': fixture('builder.py', 'synthetic builder'), 'harness': fixture('harness.lua', 'synthetic harness'),
            'policy_files': {'scoring': fixture('policy/scoring.lua', 'synthetic policy')},
            'sources': {'card.lua': fixture('source/card.lua', 'synthetic card source; never executed'),
                        'functions/common_events.lua': fixture('source/common.lua', 'synthetic event source; never executed')}}
        self.manifest_path = self.directory / 'manifest.json'
        self.manifest_path.write_text(json.dumps(self.manifest), encoding='utf-8')
        authority = {'kind': 'prospective287_authority', 'status': 'APPROVED', 'approved_by': 'user',
                     'replacements': 0, 'serial_only': True, 'expires_at_utc': '2099-01-01T00:00:00+00:00',
                     'allowed_job_ids': ['B1'], 'per_job_caps': {'B1': 30}}
        authority_path = self.directory / 'authority.json'
        authority_path.write_text(json.dumps(authority), encoding='utf-8')
        self.admission_path = self.directory / 'started.json'
        registration = {'kind': 'prospective287_job', 'status': 'REGISTERED', 'job_id': 'B1', 'timeout_seconds': 30,
                        'authority_path': str(authority_path), 'authority_sha256': worker.sha(authority_path),
                        'job_manifest_path': str(self.manifest_path), 'job_manifest_sha256': worker.sha(self.manifest_path),
                        'started_path': str(self.admission_path)}
        self.registration_path = self.directory / 'registration.json'
        self.registration_path.write_text(json.dumps(registration), encoding='utf-8')
        self.admission = {'job_id': 'B1', 'coordinator_pid': 123, 'deadline_unix': 130,
                          'registration_sha256': worker.sha(self.registration_path)}
        self.admission_path.write_text(json.dumps(self.admission), encoding='utf-8')

    def run_worker(self, execute):
        with mock.patch('sys.argv', ['worker', '--registration', str(self.registration_path)]), \
                mock.patch.object(worker.time, 'time', return_value=100), \
                mock.patch.object(worker, 'execute_lua', execute), mock.patch('builtins.print'):
            return worker.main()

    def test_exact_parent_chain_one_use(self):
        execute = mock.Mock()
        self.assertEqual(self.run_worker(execute), 0)
        self.assertEqual(execute.call_count, 1)
        with self.assertRaises(FileExistsError):
            self.run_worker(execute)
        self.assertEqual(execute.call_count, 1)

    def test_wrong_manifest_hash_cannot_consume_or_execute(self):
        self.manifest_path.write_text(self.manifest_path.read_text() + ' ', encoding='utf-8')
        execute = mock.Mock()
        with self.assertRaises(ValueError):
            self.run_worker(execute)
        execute.assert_not_called()
        self.assertFalse(self.manifest_path.with_name('manifest.json.worker_consumed.json').exists())

    def test_unbound_start_marker_cannot_execute(self):
        self.admission['registration_sha256'] = 'wrong'
        self.admission_path.write_text(json.dumps(self.admission), encoding='utf-8')
        execute = mock.Mock()
        with self.assertRaises(ValueError):
            self.run_worker(execute)
        execute.assert_not_called()

    def test_wrong_parent_pid_cannot_consume_or_execute(self):
        self.admission['coordinator_pid'] = 124
        self.admission_path.write_text(json.dumps(self.admission), encoding='utf-8')
        execute = mock.Mock()
        with self.assertRaises(ValueError):
            self.run_worker(execute)
        execute.assert_not_called()
        self.assertFalse(self.manifest_path.with_name('manifest.json.worker_consumed.json').exists())

    def test_modified_policy_after_run_rejected_and_consumed(self):
        def execute(*args):
            Path(self.manifest['policy_files']['scoring']['path']).write_text('changed', encoding='utf-8')
        with self.assertRaises(ValueError):
            self.run_worker(execute)
        self.assertTrue(self.manifest_path.with_name('manifest.json.worker_consumed.json').exists())


if __name__ == '__main__':
    unittest.main()
