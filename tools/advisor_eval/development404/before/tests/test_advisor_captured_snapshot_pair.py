"""Synthetic paired-worker protocol tests. No captured decisions or source runs."""
import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(HERE))
import captured_snapshot_pair as P


class CapturedPairTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.ledger = self.root / 'ledger'; self.ledger.mkdir()
        def write(name, value):
            path = self.root / name; path.write_text(json.dumps(value), encoding='utf-8'); return path
        self.write = write
        self.authority = write('authority.json', {'kind': 'prospective287_authority', 'status': 'APPROVED',
            'approved_by': 'user', 'approval_reference': 'synthetic fixture only', 'allowed_job_ids': ['A1'],
            'serial_only': True, 'replacements': 0, 'per_job_caps': {'A1': 60},
            'ledger_directory': str(self.ledger),
            'expires_at_utc': (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()})
        self.parent = write('parent.json', {'kind': 'prospective287_job', 'status': 'REGISTERED', 'job_id': 'A1',
                                          'authority_sha256': P.sha(self.authority), 'timeout_seconds': 60})
        runtime = self.root / 'lua51.dll'; runtime.write_bytes(b'fixture; never loaded')
        snapshot = write('snapshot.json', {'phase': 'hand', 'hand': [], 'hands_left': 1})
        self.spec = {'kind': 'captured_snapshot_pair287', 'qualification': False, 'job_id': 'A1',
            'authority': self.ref(self.authority), 'parent_registration': self.ref(self.parent),
            'policy_seconds': 15, 'pair_seconds': 60, 'policy_order': ['282', '286'], 'policies': {},
            'snapshot': self.ref(snapshot), 'runtime': self.ref(runtime),
            'module_setup': self.ref(HERE / 'engine_run.lua'), 'contract': self.ref(HERE / 'engine_contract.lua'),
            'runner': self.ref(HERE / 'captured_snapshot_pair.py'), 'driver': self.ref(HERE / 'captured_snapshot_pair.lua'),
            'options': 'product_defaults_no_overrides', 'source_execution': False, 'save_access': 'none'}
        for role in ('282', '286'):
            root = self.root / role; advisor = root / 'Brainstorm/Advisor'; advisor.mkdir(parents=True)
            names = ['snapshot', 'scoring', 'search', 'decision', 'strategy', 'consumables', 'synergies']
            if role == '286': names.append('resource_finish')
            for name in names:
                (advisor / (name + '.lua')).write_text('return {fixture_policy="' + role + '"}', encoding='utf-8')
            files = {'Brainstorm/Advisor/' + p.name: P.sha(p) for p in advisor.iterdir()}
            policy = {'policy_files': files, 'policy_digest': P.digest(files)}
            record = write(role + '_record.json', {'policy': policy})
            self.spec['policies'][role] = {'root': str(root), 'record': self.ref(record),
                                         'policy_digest': policy['policy_digest']}
        history = write('historical_registration.json', {'fixture': 'no captured data'})
        parent = P.read(self.parent)
        parent.update({'per_policy_seconds': 15, 'separate_modeled_legality_score_allowed': True,
                       'source_execution': False, 'no_replacements': True,
                       'policy_order': self.spec['policy_order'], 'snapshot': self.spec['snapshot'],
                       'historical_registration': self.ref(history),
                       'policy_digests': {k: v['policy_digest'] for k, v in self.spec['policies'].items()}})
        self.parent.write_text(json.dumps(parent)); self.spec['parent_registration'] = self.ref(self.parent)
        self.spec_path = write('spec.json', self.spec)

    @staticmethod
    def ref(path): return {'path': str(path.resolve()), 'sha256': P.sha(path)}

    def prepare(self):
        self.spec_path.write_text(json.dumps(self.spec), encoding='utf-8')
        out = self.root / 'output'
        with patch.object(P.ctypes, 'CDLL') as dll:
            result = P.prepare(self.spec_path, out)
            dll.assert_not_called()
        return out, result

    def test_prepare_freezes_without_loading_runtime_or_evaluating(self):
        out, result = self.prepare()
        self.assertEqual(P.verify(out)['job_id'], 'A1')
        self.assertFalse((out / 'execution_started.json').exists())
        self.assertTrue((self.ledger / 'A1_captured_reservation.json').exists())
        self.assertEqual(result['kind'], 'captured_snapshot_pair287_registration')

    def test_policy_dependencies_cannot_fall_back_or_leak_from286_into282(self):
        out, _ = self.prepare(); baseline = P.worker_source(out, '282'); candidate = P.worker_source(out, '286')
        self.assertIn(b'package.path="";package.cpath="";package.loaders={package.loaders[1]}', baseline)
        self.assertNotIn(b'package.preload[ ' + P.literal('probe_policy_resource_finish') + b' ]=assert(loadstring', baseline)
        self.assertIn(b'probe_policy_resource_finish', candidate)
        self.assertNotIn(b'fixture_policy="286"', baseline)
        self.assertNotIn(b'for step=1,500', candidate)
        self.assertNotIn(b'local function state_fingerprint', candidate)
        self.assertIn(b'decision.run(s,modules)', candidate)

    def test_parent_job_cannot_be_reused_with_a_fresh_output_directory(self):
        self.prepare()
        with self.assertRaises(FileExistsError): P.prepare(self.spec_path, self.root / 'replacement')
        self.assertFalse((self.root / 'replacement').exists())

    def test_invalid_caps_order_and_options_rejected_before_reservation(self):
        original = copy.deepcopy(self.spec)
        for key, value in [('policy_seconds', 16), ('pair_seconds', 61), ('policy_order', ['282', '282']),
                           ('options', 'raised_budget'), ('source_execution', True), ('qualification', True)]:
            self.spec = copy.deepcopy(original); self.spec[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): self.prepare()
        self.assertFalse((self.ledger / 'A1_captured_reservation.json').exists())

    def test_missing_authority_rejected_before_runtime_read(self):
        self.spec['authority']['sha256'] = '0' * 64
        with patch.object(P.ctypes, 'CDLL') as dll, self.assertRaises(ValueError): self.prepare()
        dll.assert_not_called()

    def test_expired_or_wrong_parent_authority_rejected(self):
        authority = P.read(self.authority); authority['expires_at_utc'] = '2000-01-01T00:00:00+00:00'
        self.authority.write_text(json.dumps(authority)); self.spec['authority'] = self.ref(self.authority)
        parent = P.read(self.parent); parent['authority_sha256'] = self.spec['authority']['sha256']
        self.parent.write_text(json.dumps(parent)); self.spec['parent_registration'] = self.ref(self.parent)
        with self.assertRaisesRegex(ValueError, 'expired'): self.prepare()

    def test_frozen_inputs_policy_driver_and_runtime_mutation_detected(self):
        out, _ = self.prepare()
        for name in ('snapshot.json', '282/scoring.lua', '286/resource_finish.lua', 'module_setup.lua',
                     'captured_snapshot_pair.lua', 'lua51.dll'):
            path = out / 'frozen' / name; before = path.read_bytes(); path.write_bytes(before + b' ')
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'evidence changed'): P.verify(out)
            path.write_bytes(before)

    def test_missing_policy_dependency_and_changed_snapshot_rejected(self):
        self.spec['snapshot']['sha256'] = '1' * 64
        with self.assertRaisesRegex(ValueError, 'parent job'): self.prepare()

    def test_unknown_module_setup_rejected_without_source_dispatch(self):
        for source in (b'no boundary', b'local modules={}\nlocal function json(value)',
                       b'-- Experimental dispatcher\nlocal modules={}\nfor step=1,500 do end\nlocal function json(value)'):
            with self.assertRaises(ValueError): P.module_setup(source)

    def test_generated_literal_preserves_brackets_leading_newline_and_null(self):
        value = b'\n]] ]=] \x00 tail'; result = P.literal(value)
        self.assertTrue(result.startswith(b'[==[\n\n'))
        self.assertEqual(P.lua_value({'a': [True, None, 3]}), b'{[ [[\na]] ]={true,nil,3}}')
        with self.assertRaises(ValueError): P.lua_value(float('nan'))

    def test_generated_worker_executes_only_synthetic_modules_with_exact_strings(self):
        # Exercise the real Python generator and Lua parser together. The former
        # tests asserted an invalid [[[ index spelling and tested the Lua driver
        # separately, allowing every real captured worker to fail before advice.
        out, _ = self.prepare()
        value = {'phase': 'hand', 'nested': {'string': '\n]] ]=] \x00\r\n\r tail'}, 'flags': [True, False, 3]}
        (out / 'frozen/snapshot.json').write_text(json.dumps(value), encoding='utf-8')
        paths = []
        raw = value['nested']['string'].encode()
        for role in ('282', '286'):
            assertion = (b"assert(PROFILE_INPUT.phase=='hand');assert(PROFILE_INPUT.flags[1]==true);"
                         b"assert(PROFILE_INPUT.flags[2]==false);assert(PROFILE_INPUT.flags[3]==3);"
                         b'local expected=' + P.lua_value(list(raw)) + b';local value=PROFILE_INPUT.nested.string;'
                         b'assert(#value==#expected);for i=1,#expected do assert(value:byte(i)==expected[i]) end;'
                         b"assert(modules.scoring.fixture_policy=='" + role.encode() + b"');"
                         + (b"assert(modules.resource_finish.fixture_policy=='286');" if role == '286'
                            else b'assert(modules.resource_finish==nil);')
                         + b"print('synthetic generated worker parsed and executed without source or policy decisions')")
            # No real decision.run invocation or captured state enters the test.
            (out / 'frozen/captured_snapshot_pair.lua').write_bytes(assertion)
            path = self.root / (role + '_synthetic_generated.lua')
            path.write_bytes(P.worker_source(out, role));paths.append(str(path))
        command = [sys.executable, str(HERE.parents[1] / 'tests/run_lua_tests.py'), *paths]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15,
                                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        self.assertEqual(result.returncode, 0, result.stdout.decode('utf-8', 'replace'))

    def test_worker_needs_one_use_lease_before_dll_load(self):
        out, _ = self.prepare()
        with patch.object(P.ctypes, 'CDLL') as dll, self.assertRaises(FileNotFoundError): P.run_worker(out, '282')
        dll.assert_not_called()

    def test_pair_timeout_is_preserved_each_worker_hidden_and_cannot_retry(self):
        out, _ = self.prepare()
        with patch.object(P.subprocess, 'run', side_effect=subprocess.TimeoutExpired('fixture', 15)) as run:
            report = P.execute(out)
        self.assertEqual(run.call_count, 2)
        for call in run.call_args_list:
            self.assertEqual(call.kwargs['timeout'], 15)
            self.assertEqual(call.kwargs['creationflags'], getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        self.assertEqual([r['status'] for r in report['policy_reports']], ['timeout', 'timeout'])
        self.assertEqual(report['status'], 'incomplete'); self.assertFalse(report['win_rate_evidence'])
        with patch.object(P.subprocess, 'run') as rerun, self.assertRaises(FileExistsError): P.execute(out)
        rerun.assert_not_called()

    def test_success_requires_policy_identity_and_unchanged_input(self):
        out, _ = self.prepare()
        def worker(command, **kwargs):
            role = command[-1]
            kwargs['stdout'].write(json.dumps({'type': 'captured_snapshot_pair_decision', 'policy': role,
                'policy_digest': self.spec['policies'][role]['policy_digest'], 'input_unchanged': True}))
            return subprocess.CompletedProcess(command, 0)
        with patch.object(P.subprocess, 'run', side_effect=worker): report = P.execute(out)
        self.assertEqual(report['status'], 'complete')
        self.assertEqual(report['input_sha256_before'], report['input_sha256_after'])


if __name__ == '__main__': unittest.main()
