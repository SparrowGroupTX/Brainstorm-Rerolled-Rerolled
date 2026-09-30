"""Frozen source-fixture protocol tests; no callback/episode worker executes."""
import ctypes
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

HERE = Path(__file__).resolve().parents[1] / 'tools/advisor_eval'
sys.path.insert(0, str(HERE))
import planet_pool_source_parity as P


class PlanetPoolSourceParityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.install = self.root / 'install'; self.install.mkdir()
        with zipfile.ZipFile(self.install / 'Balatro.exe', 'w') as archive:
            archive.writestr('engine/object.lua', 'Object={}\n')
            archive.writestr('engine/event.lua', 'Event={};EventManager={}\n')
            for name, signatures in P.SOURCES.items():
                archive.writestr(name, '\n'.join(signature + ') return nil end' for signature in signatures) +
                                 '\nfunction fixture_boundary() end\n')
        (self.install / 'lua51.dll').write_bytes(b'fixture DLL; never loaded')
        self.policy = self.root / 'policy'
        for name in ('Advisor/paid_reroll.lua', 'Advisor/snapshot.lua', 'Core/Brainstorm.lua',
                     'Core/challenge_opening.lua', 'UI/advisor.lua', 'UI/ui.lua', 'UI/challenge_opening.lua', 'lovely.toml'):
            path = self.policy / 'Brainstorm' / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('return {}', encoding='utf-8')
        self.output = self.root / 'output'

    def register(self):
        with patch.object(P.subprocess, 'run') as run:
            registration = P.register(self.policy, self.install, self.output)
            run.assert_not_called()
        return registration

    def test_registration_is_complete_frozen_and_does_not_execute(self):
        registration = self.register()
        self.assertEqual(registration['requested_workers'], 1)
        self.assertEqual(registration['per_worker_seconds'], 10)
        self.assertEqual(registration['cases'], list(P.CASES))
        self.assertEqual(P.verify(self.output)['registration_digest'], registration['registration_digest'])
        self.assertFalse((self.output / 'execution_started.json').exists())
        self.assertIn(b'Card:set_cost(', (self.output / 'source_probe.lua').read_bytes())

    def test_frozen_sources_helpers_and_product_cannot_change(self):
        self.register()
        for relative in ('source/card.lua', 'adapter/planet_pool_source_parity.lua',
                         'policy/Brainstorm/Advisor/paid_reroll.lua', 'source_probe.lua', 'run_lua_tests.py'):
            path = self.output / relative; before = path.read_bytes(); path.write_bytes(before + b' ')
            with self.subTest(path=relative), self.assertRaises(ValueError): P.verify(self.output)
            path.write_bytes(before)

    def test_existing_output_cannot_re_register(self):
        self.register()
        with self.assertRaises(FileExistsError): self.register()

    def test_one_worker_timeout_is_retained_and_lease_cannot_repeat(self):
        self.register()
        with patch.object(P.subprocess, 'run', side_effect=subprocess.TimeoutExpired('fixture', 10)) as run:
            report = P.execute(self.output)
            self.assertEqual(run.call_args.kwargs['timeout'], 10)
            self.assertEqual(run.call_args.kwargs['creationflags'], getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        self.assertEqual(report['status'], 'timeout'); self.assertEqual(report['cases'], 0)
        self.assertTrue((self.output / 'report.json').exists())
        with patch.object(P.subprocess, 'run') as run, self.assertRaises(FileExistsError): P.execute(self.output)
        run.assert_not_called()

    def test_success_requires_every_registered_case(self):
        self.register()
        def missing_case(*args, **kwargs):
            kwargs['stdout'].write('planet source parity: 7 cases, 100 comparisons\n')
            return subprocess.CompletedProcess(args[0], 0)
        with patch.object(P.subprocess, 'run', side_effect=missing_case): report = P.execute(self.output)
        self.assertEqual(report['status'], 'error'); self.assertEqual(report['cases'], 7)

    def test_case_isolation_preserves_later_success_and_original_error(self):
        text = '\n'.join(['planet case_result {"case":"ordinary","status":"passed"}',
            'planet case_result {"case":"flags_bans_locked","status":"error","reason":"policy guard"}',
            'planet case_result {"case":"discount_inflation","status":"passed"}'])
        records = P.case_records(text)
        self.assertEqual([r['status'] for r in records], ['passed', 'error', 'passed'])
        self.assertEqual(records[1]['reason'], 'policy guard')

    def test_generated_fixture_compiles_with_original_source_but_executes_nothing(self):
        install = Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
        if not (install / 'lua51.dll').exists(): self.skipTest('Lua source compiler unavailable')
        self.register()
        # Compile only: no lua_pcall, game initialization, callbacks or decisions.
        with zipfile.ZipFile(install / 'Balatro.exe') as archive:
            for name in P.WHOLE_SOURCES + tuple(P.SOURCES):
                (self.output / 'source' / name).write_bytes(archive.read(name))
        source = P.generated_probe(self.output)
        library = ctypes.CDLL(str(install / 'lua51.dll')); library.luaL_newstate.restype = ctypes.c_void_p
        library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
        library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        library.lua_tolstring.restype = ctypes.c_void_p; library.lua_close.argtypes = [ctypes.c_void_p]
        state = library.luaL_newstate(); self.assertTrue(state)
        try:
            status = library.luaL_loadbuffer(state, source, len(source), b'@planet_compile_only.lua')
            length = ctypes.c_size_t(); pointer = library.lua_tolstring(state, -1, ctypes.byref(length))
            message = ctypes.string_at(pointer, length.value).decode() if pointer else ''
            self.assertEqual(status, 0, message)
        finally:
            library.lua_close(state)


if __name__ == '__main__':
    unittest.main()
