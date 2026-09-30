"""M09: two detached C01 step205 decisions, under root's one-use 30s job.

This invokes no original game source or source actions. The shared helper is
used only for serialization and prefix validation; its historical workers and
authority are never invoked.
"""
from pathlib import Path
from datetime import datetime, timezone
import ctypes
import hashlib
import json
import sys
from captured_snapshot_pair import literal, lua_value, module_setup

folder = Path(__file__).resolve().parent
registration = json.loads((folder / 'registration.json').read_text())
authority = json.loads((folder / 'authority.json').read_text())
assert registration['job'] == 'M09' and registration['timeout_seconds'] == 30
assert authority['status'] == 'APPROVED' and authority['per_job_caps']['M09'] == 30
assert datetime.now(timezone.utc) < datetime.fromisoformat(authority['expires_at_utc'])
assert json.loads((folder / 'spent.json').read_text())['job'] == 'M09'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
for name, expected in registration['files'].items():
    assert sha(folder / name) == expected, name
with (folder / 'comparison_started.json').open('x') as stream:
    json.dump({'job': 'M09', 'one_use': True, 'registration_sha256': sha(folder / 'registration.json')}, stream)
snapshot = json.loads((folder / 'step205.json').read_text())['snapshot']
assert snapshot['ante'] == 8 and snapshot['phase'] == 'hand'
prefix = module_setup((folder / 'engine_run.lua').read_bytes())
driver = (folder / 'captured_snapshot_pair.lua').read_bytes()
runtime = next(Path(p) for p in registration['external_files'] if Path(p).name.lower() == 'lua51.dll')
assert sha(runtime) == registration['external_files'][str(runtime)]
library = ctypes.CDLL(str(runtime))
library.luaL_newstate.restype = ctypes.c_void_p
library.luaL_openlibs.argtypes = [ctypes.c_void_p]
library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
library.lua_tolstring.restype = ctypes.c_void_p
library.lua_close.argtypes = [ctypes.c_void_p]
results = {}
for role in ('baseline300', 'candidate'):
    chunks = [b'PROBE_MONOTONIC_SECONDS=os.clock', b'PROFILE_INPUT=' + lua_value(snapshot),
              b'package.path="";package.cpath="";package.loaders={package.loaders[1]}']
    for path in sorted((folder / role / 'Brainstorm/Advisor').glob('*.lua')):
        chunks.append(b'package.preload[ ' + literal('probe_policy_' + path.stem) + b' ]=assert(loadstring(' +
                      literal(path.read_bytes()) + b',' + literal('@' + role + '/' + path.name) + b'))')
    chunks.append(b'package.preload.probe_engine_contract=assert(loadstring(' + literal((folder / 'engine_contract.lua').read_bytes()) + b'))')
    source = b'\n'.join(chunks + [prefix, driver])
    state = library.luaL_newstate()
    assert state
    try:
        library.luaL_openlibs(state)
        status = library.luaL_loadbuffer(state, source, len(source), b'@M09_detached_cap_comparison')
        if not status:
            status = library.lua_pcall(state, 0, 1, 0)
        length = ctypes.c_size_t()
        pointer = library.lua_tolstring(state, -1, ctypes.byref(length))
        raw = ctypes.string_at(pointer, length.value).decode() if pointer else ''
        if status:
            raise RuntimeError(raw)
        result = json.loads(raw)
        for key in ('input_fingerprint', 'action_fingerprint'):
            result[key] = hashlib.sha256(result[key].encode()).hexdigest()
        result['policy'] = role
        result['policy_digest'] = registration['metadata']['policy_digests'][role]
        with (folder / (role + '_result.json')).open('x') as stream:
            json.dump(result, stream, indent=2)
        results[role] = result
        print(json.dumps({'type': 'captured_cap_result', 'role': role, 'action': result['action'],
                          'score_calls': result['score_calls'], 'evaluations': result['result']['evaluations'],
                          'seconds': result['decision_elapsed_seconds'], 'input_unchanged': result['input_unchanged']}), flush=True)
    finally:
        library.lua_close(state)
baseline, candidate = results['baseline300'], results['candidate']
assert baseline['input_unchanged'] and candidate['input_unchanged']
assert baseline['input_fingerprint'] == candidate['input_fingerprint']
assert baseline['score_calls'] == 150172
assert candidate['score_calls'] <= 140000 and candidate['result']['evaluations'] <= 140000
assert baseline['action'] == candidate['action'] == {'kind': 'use', 'area': 'consumeables', 'index': 2, 'targets': [2, 3, 5]}
for role in results:
    assert results[role]['result']['consumable_diagnostics']['truncated'] is False
    assert results[role]['result']['consumable_diagnostics']['evaluated_candidates'] == 93
print(json.dumps({'type': 'captured_cap_comparison', 'status': 'passed', 'source_execution': False,
                  'terminal_evidence': False, 'qualification': False, 'same_action': True,
                  'complete_owned_consumable_candidates': 93,
                  'score_calls_saved': baseline['score_calls'] - candidate['score_calls']}), flush=True)
