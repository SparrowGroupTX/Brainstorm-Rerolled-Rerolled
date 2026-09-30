"""Detached-profile admission and one-use protocol fixtures; no source episodes."""
import json
import ctypes
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(HERE))
import snapshot_component_profile as P


class SnapshotComponentProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.source = self.root / 'source'; self.source.mkdir()
        policy = self.source / 'candidate'
        for name in ('Advisor/snapshot.lua', 'Advisor/scoring.lua', 'Advisor/decision.lua',
                     'Core/Brainstorm.lua', 'Core/challenge_opening.lua', 'UI/advisor.lua',
                     'UI/ui.lua', 'UI/challenge_opening.lua', 'lovely.toml'):
            path = policy / 'Brainstorm' / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('return {}', encoding='utf-8')
        runtime = self.root / 'lua51.dll'; runtime.write_bytes(b'fixture runtime; never loaded')
        adapter = self.source / 'adapter'; adapter.mkdir()
        for name in ('engine_run.lua', 'engine_contract.lua'):
            (adapter / name).write_bytes((HERE / name).read_bytes())
        spec = P.engine_probe.profile_spec('all_unlocked_discovered_v1')
        inventory = '\n'.join(scope + ':fixture:true:true' for scope in sorted(spec['scope'])).encode()
        self.profile = P.engine_probe.profile_record(spec['name'], inventory)
        hashes = P.paired.policy_hashes(policy)
        self.manifest = {'requests': [{'challenge': 'c_rich_1', 'seed': 'FIXTUREDEV', 'split': 'development'},
                                     {'challenge': 'c_rich_1', 'seed': 'FIXTUREHOLD', 'split': 'holdout'}],
            'policies': {'candidate': {'policy_files': hashes, 'policy_digest': P.paired.digest(hashes)}},
            'rules_digest': 'fixture-source-rules', 'runtime_digest': P.paired.file_digest(runtime),
            'install': str(self.root), 'profile_spec': spec, 'profile_spec_digest': P.paired.digest(spec),
            'start_distribution': P.paired.ORDINARY_START, 'manifest_digest': 'fixture-manifest'}
        self.manifest['adapter_files'] = {name: P.paired.file_digest(adapter / name) for name in ('engine_run.lua', 'engine_contract.lua')}
        self.manifest['adapter_digest'] = P.paired.digest(self.manifest['adapter_files'])
        origin = {'type': 'engine_probe_provenance', 'challenge': 'c_rich_1', 'seed': 'FIXTUREDEV',
            **{key: self.manifest[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest',
                                                 'profile_spec', 'profile_spec_digest', 'start_distribution')},
            **self.manifest['policies']['candidate'], 'opening_policy_loaded': False}
        self.rows = [origin, self.profile,
            {'type': 'engine_episode_decision_started', 'step': 75, 'phase': 'hand', 'snapshot': {'phase': 'hand'},
             'fingerprint_schema': 'source_decision_v1', 'state_fingerprint': 'a' * 64},
            {'type': 'engine_episode_action', 'step': 75, 'phase': 'hand', 'state_fingerprint': 'a' * 64,
             'action': {'kind': 'play', 'indices': [1]}},
            {'type': 'engine_episode_profile', 'step': 75, 'evaluations': 1, 'score_calls': 1, 'advisor_seconds': .01}]
        self.trace = self.source / '000_candidate.log'; self.write_trace()
        self.registration = {'registration_digest': 'fixture-registration'}

    def write_trace(self):
        self.trace.write_text(''.join(json.dumps(row) + '\n' for row in self.rows), encoding='utf-8')

    def register(self, name='output', **kwargs):
        output = self.root / name
        with patch.object(P.outcome, 'verify', return_value=(self.registration, self.manifest)), \
             patch.object(P.ctypes, 'CDLL') as runtime:
            manifest = P.register(self.source, self.trace, 'candidate', 75, output, **kwargs)
            runtime.assert_not_called()
        return output, manifest

    def test_registration_freezes_input_dependencies_without_execution(self):
        out, manifest = self.register()
        self.assertTrue(manifest['same_product']); self.assertEqual(manifest['requested_workers'], 1)
        self.assertEqual(manifest['timeout_seconds'], 15)
        self.assertFalse((out / 'execution_started.json').exists())
        self.assertEqual(P.verify(out)['manifest_digest'], manifest['manifest_digest'])
        code = P.worker_source(out)
        self.assertIn(b'modules.decision.run(s,modules)', code)
        self.assertNotIn(b'for step=1,500', code)
        self.assertNotIn(b'search={samples=', code)
        self.assertIn(b"'classify','score_classify'", code)

    def test_holdout_is_rejected_before_its_trace_is_read(self):
        with patch.object(P.outcome, 'verify', return_value=(self.registration, self.manifest)), \
             patch.object(P.paired, 'parse_trace', side_effect=AssertionError('Holdout was read')):
            with self.assertRaisesRegex(ValueError, 'holdouts are excluded'):
                P.source_input(self.source, self.source / '001_candidate.log', 'candidate', 75)

    def test_registration_rejects_missing_snapshot_changed_provenance_and_duplicate_step(self):
        original = json.loads(json.dumps(self.rows))
        for change in ('snapshot', 'policy', 'duplicate', 'profile'):
            self.rows = json.loads(json.dumps(original))
            if change == 'snapshot': self.rows[2].pop('snapshot')
            elif change == 'policy': self.rows[0]['policy_digest'] = 'changed'
            elif change == 'profile': self.rows[1]['unlock_profile_digest'] = 'changed'
            else: self.rows.append(self.rows[2])
            self.write_trace()
            with self.subTest(change=change), self.assertRaises(ValueError): self.register(change)
            self.assertFalse((self.root / change).exists())

    def test_frozen_input_source_adapter_and_both_products_are_checked(self):
        out, _ = self.register()
        for relative in ('input.json', 'source.log', 'source_adapter/engine_run.lua',
                         'source_policy/Brainstorm/Advisor/scoring.lua', 'policy/Brainstorm/Advisor/scoring.lua'):
            path = out / relative; before = path.read_bytes(); path.write_bytes(before + b' ')
            with self.subTest(relative=relative), self.assertRaises(ValueError): P.verify(out)
            path.write_bytes(before)

    def test_candidate_is_frozen_separately_without_relabeling_source_provenance(self):
        candidate = self.root / 'other'; P.paired.freeze_product(self.source / 'candidate', candidate)
        (candidate / 'Brainstorm/Advisor/scoring.lua').write_text('return {candidate=true}')
        out, manifest = self.register(candidate_root=candidate)
        self.assertFalse(manifest['same_product'])
        self.assertNotEqual(manifest['source_policy_digest'], manifest['policy_digest'])
        self.assertEqual(json.loads((out / 'input.json').read_text())['source_origin']['policy_digest'], manifest['source_policy_digest'])

    def test_invalid_caps_and_existing_output_cannot_register(self):
        for timeout in (0, 16, True, float('inf'), float('nan')):
            with self.subTest(timeout=timeout), self.assertRaises(ValueError): self.register(timeout=timeout)
        self.register()
        with self.assertRaises(FileExistsError): self.register()

    def test_execute_is_hidden_bounded_once_and_retains_timeout(self):
        out, _ = self.register()
        with patch.object(P.subprocess, 'run', side_effect=subprocess.TimeoutExpired('fixture', 15)) as run:
            result = P.execute(out)
            self.assertEqual(run.call_args.kwargs['timeout'], 15)
            self.assertEqual(run.call_args.kwargs['creationflags'], getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        self.assertEqual(result['status'], 'timeout'); self.assertIsNone(result['source_parity'])
        self.assertTrue((out / 'report.json').exists())
        with patch.object(P.subprocess, 'run') as run, self.assertRaises(FileExistsError):
            P.execute(out)
        run.assert_not_called()

    def test_worker_rejects_absent_lease_before_loading_runtime(self):
        out, _ = self.register()
        with patch.object(P.ctypes, 'CDLL') as runtime, self.assertRaises(FileNotFoundError): P.run_worker(out)
        runtime.assert_not_called()

    def test_generated_worker_compiles_without_executing_a_decision(self):
        runtime = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll')
        if not runtime.exists(): self.skipTest('Lua51 library unavailable for compile-only fixture')
        out, _ = self.register(); source = P.worker_source(out)
        library = ctypes.CDLL(str(runtime)); library.luaL_newstate.restype = ctypes.c_void_p
        library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
        library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        library.lua_tolstring.restype = ctypes.c_void_p; library.lua_close.argtypes = [ctypes.c_void_p]
        state = library.luaL_newstate(); self.assertTrue(state)
        try:
            status = library.luaL_loadbuffer(state, source, len(source), b'@compile_only_detached_fixture.lua')
            size = ctypes.c_size_t(); pointer = library.lua_tolstring(state, -1, ctypes.byref(size))
            message = ctypes.string_at(pointer, size.value).decode() if pointer else ''
            self.assertEqual(status, 0, message)
        finally:
            library.lua_close(state)


if __name__ == '__main__':
    unittest.main()
