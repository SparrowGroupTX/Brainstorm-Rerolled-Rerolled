"""M10 DRAFT: four detached shop decisions. Requires root registration/spent lease."""
from pathlib import Path
from datetime import datetime, timezone
import ctypes
import hashlib
import json
from captured_snapshot_pair import module_setup
from lua_bytes import literal, lua_value

folder = Path(__file__).resolve().parent
registration = json.loads((folder / 'registration.json').read_text())
authority = json.loads((folder / 'authority.json').read_text())
assert folder.name == 'M10'
assert registration['job'] == 'M10' and registration['timeout_seconds'] == 30
assert registration['metadata']['maximum_decisions'] == 4
assert authority['status'] == 'APPROVED' and authority['per_job_caps']['M10'] == 30
assert datetime.now(timezone.utc) < datetime.fromisoformat(authority['expires_at_utc'])
assert json.loads((folder / 'spent.json').read_text())['job'] == 'M10'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
canonical = lambda value: json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False)
for name, expected in registration['files'].items():
    assert sha(folder / name) == expected, name
with (folder / 'comparison_started.json').open('x') as stream:
    json.dump({'job': 'M10', 'one_use': True, 'registration_sha256': sha(folder / 'registration.json')}, stream)
snapshots = {step: json.loads((folder / f'step{step}.json').read_text())['snapshot'] for step in (138, 139)}
assert all(s['phase'] == 'shop' for s in snapshots.values())
left, right = snapshots[138], snapshots[139]
assert {k: v for k, v in left.items() if k != 'jokers'} == {k: v for k, v in right.items() if k != 'jokers'}
assert sorted(map(canonical, left['jokers'])) == sorted(map(canonical, right['jokers']))
prefix = module_setup((folder / 'engine_run.lua').read_bytes())
driver = (folder / 'driver_shop10.lua').read_bytes()
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
    for step in (138, 139):
        chunks = [b'PROBE_MONOTONIC_SECONDS=os.clock', b'PROFILE_INPUT=' + lua_value(snapshots[step]),
                  b'package.path="";package.cpath="";package.loaders={package.loaders[1]}']
        for path in sorted((folder / role / 'Brainstorm/Advisor').glob('*.lua')):
            chunks.append(b'package.preload[ ' + literal('probe_policy_' + path.stem) + b' ]=assert(loadstring(' +
                          literal(path.read_bytes()) + b',' + literal('@' + role + '/' + path.name) + b'))')
        chunks.append(b'package.preload.probe_engine_contract=assert(loadstring(' + literal((folder / 'engine_contract.lua').read_bytes()) + b'))')
        source = b'\n'.join(chunks + [prefix, driver])
        state = library.luaL_newstate(); assert state
        try:
            library.luaL_openlibs(state)
            status = library.luaL_loadbuffer(state, source, len(source), b'@M10_detached_shop_comparison')
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
            result.update({'policy': role, 'step': step, 'policy_digest': registration['metadata']['policy_digests'][role]})
            with (folder / f'{role}_step{step}_result.json').open('x') as stream:
                json.dump(result, stream, indent=2)
            results[(role, step)] = result
            print(json.dumps({'type': 'captured_shop_result', 'role': role, 'step': step,
                              'action': result['action'], 'score_calls': result['score_calls'],
                              'evaluations': result['result']['evaluations'],
                              'seconds': result['decision_elapsed_seconds'], 'input_unchanged': result['input_unchanged']}), flush=True)
        finally:
            library.lua_close(state)


def hold_projection(result):
    return result['result']['shop_diagnostics']['sequences']['best_by_first_action']['leave_shop::']['readiness']


def fixed_trajectories(ready):
    finish = ready['finishing']
    assert finish['complete'] and finish['supported'] and finish['samples'] == 4
    assert len(finish['policies']) == 2
    normalized = []
    for policy in finish['policies']:
        assert len(policy['worlds']) == 4
        rows = []
        for world in policy['worlds']:
            actions = world['actions']; setups = [a for a in actions if a['kind'] == 'reorder_jokers']
            assert len(setups) == world.get('setup_actions', 0) <= 1
            assert len(actions) == world['hands_used'] + world['discards_used'] + len(setups)
            if setups:
                assert actions[0] == setups[0] and setups[0]['projected']
                assert setups[0]['order'] == ready['ordering']['order']
            rows.append({k: world.get(k) for k in ('clear', 'score', 'shortfall', 'progress', 'hands_used',
                                                  'discards_used', 'dollars_delta', 'dollars_after',
                                                  'population_loss', 'finish_reward', 'resources')})
            rows[-1]['actions'] = [a for a in actions if a['kind'] != 'reorder_jokers']
        assert policy['mean_setup_actions'] == ready['ordering']['action_count']
        normalized.append({'name': policy['name'], 'worlds': rows})
    return normalized


for step in (138, 139):
    a, b = results[('baseline300', step)], results[('candidate', step)]
    assert a['input_unchanged'] and b['input_unchanged']
    assert a['input_fingerprint'] == b['input_fingerprint']
    assert b['score_calls'] <= 50000 and b['result']['evaluations'] <= 50000
    assert a['legality_audit']['score_calls'] == b['legality_audit']['score_calls'] == 0
baseline = [hold_projection(results[('baseline300', step)]) for step in (138, 139)]
candidate = [hold_projection(results[('candidate', step)]) for step in (138, 139)]
assert baseline[0]['opening_mean'] == baseline[1]['opening_mean']
assert baseline[0]['cumulative_mean'] != baseline[1]['cumulative_mean']
assert candidate[0]['ordering']['identity'] == candidate[1]['ordering']['identity']
assert candidate[0]['cumulative_mean'] == candidate[1]['cumulative_mean']
assert fixed_trajectories(candidate[0]) == fixed_trajectories(candidate[1])
summary = {'type': 'captured_shop_comparison', 'status': 'passed', 'decisions': 4,
           'source_execution': False, 'terminal_evidence': False, 'qualification': False,
           'inputs_unchanged': True, 'baseline_mean_138': baseline[0]['cumulative_mean'],
           'baseline_mean_139': baseline[1]['cumulative_mean'],
           'candidate_mean_138': candidate[0]['cumulative_mean'],
           'candidate_mean_139': candidate[1]['cumulative_mean'],
           'candidate_setup_actions': [r['ordering']['action_count'] for r in candidate],
           'same_per_world_nonsetup_trajectories': True,
           'actions': {role: {str(step): results[(role, step)]['action'] for step in (138, 139)}
                       for role in ('baseline300', 'candidate')},
           'interpretation': 'Local fixed-order forecast consistency; no required Perkeo retention, no rescued run or win-rate inference.'}
with (folder / 'comparison.json').open('x') as stream:
    json.dump(summary, stream, indent=2)
print(json.dumps(summary), flush=True)
