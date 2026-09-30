"""Two full captured pack decisions; executable only after root registers/spends M21."""
from pathlib import Path
from datetime import datetime, timezone
import ctypes
import hashlib
import json
import sys
import time
from lua_bytes import literal, lua_value

ORDER = (('baseline', 12), ('candidate', 12))
CAP, TOTAL_CAP = 50000, 100000


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False)


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'),
                      parse_constant=lambda x: (_ for _ in ()).throw(ValueError('Nonfinite JSON: ' + x)))


def write(path, value):
    with Path(path).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')


def compare_pair(left, right):
    """Record all changes; candidate action and evaluation count need not match."""
    if (left['status'] != 'complete' or right['status'] != 'complete' or
            not left['input_unchanged'] or not right['input_unchanged'] or
            left['input_fingerprint'] != right['input_fingerprint']):
        raise ValueError('Complete results on one unchanged public input required')
    return {'actions_equal': left['action'] == right['action'],
            'results_equal': left['result'] == right['result'],
            'score_calls_equal': left['score_calls'] == right['score_calls'],
            'evaluations_equal': left['result'].get('evaluations') == right['result'].get('evaluations'),
            'baseline_action': left['action'], 'candidate_action': right['action'],
            'baseline_survival_priority': left['result'].get('pack_diagnostics', {}).get('survival_priority'),
            'candidate_survival_priority': right['result'].get('pack_diagnostics', {}).get('survival_priority')}


def verify(folder):
    folder = Path(folder).resolve()
    registration = read(folder / 'registration.json')
    authority = read(folder / 'authority.json')
    if (folder.name != 'M21' or registration.get('job') != 'M21' or registration.get('timeout_seconds') != 30
            or authority.get('kind') != 'gold299_prospective_authority' or authority.get('status') != 'APPROVED'
            or authority.get('per_job_caps', {}).get('M21') != 30
            or datetime.now(timezone.utc) >= datetime.fromisoformat(authority['expires_at_utc'])
            or registration['authority_sha256'] != sha(folder / 'authority.json')):
        raise ValueError('Require fresh root M21 registration and authority')
    spent = read(folder / 'spent.json')
    if spent.get('job') != 'M21' or spent.get('registration_sha256') != sha(folder / 'registration.json'):
        raise ValueError('Require the root one-use spent receipt')
    if (registration['metadata']['decision_order'] != [list(row) for row in ORDER]
            or registration['metadata']['score_call_cap'] != TOTAL_CAP
            or registration['metadata']['source_execution'] is not False):
        raise ValueError('Registered comparison scope changed')
    for name, expected in registration['files'].items():
        if sha(folder / name) != expected:
            raise ValueError('Frozen input changed: ' + name)
    for name, expected in registration['external_files'].items():
        if Path(name).name.lower() not in ('lua51.dll', 'python.exe') or sha(name) != expected:
            raise ValueError('Unexpected or changed external runtime: ' + name)
    if str(Path(sys.executable).resolve()) not in registration['external_files']:
        raise ValueError('Current Python is not registered')
    manifests = {role: read(folder / (role + '_record.json'))['policy'] for role in ('baseline', 'candidate')}
    for role, manifest in manifests.items():
        if hashlib.sha256(canonical(manifest['policy_files']).encode()).hexdigest() != manifest['policy_digest']:
            raise ValueError('Policy manifest digest changed')
        for name, expected in manifest['policy_files'].items():
            if sha(folder / role / name) != expected:
                raise ValueError('Frozen policy changed: ' + role + '/' + name)
    provenance = read(folder / 'input_provenance.json')
    if provenance.get('source_attempt') != 'C05' or provenance.get('step') != 12:
        raise ValueError('Wrong captured input provenance')
    binding = read(folder / 'binding.json')
    if binding.get('baseline_checkpoint') != 312 or binding.get('candidate_checkpoint') != 314:
        raise ValueError('Wrong checkpoint binding')
    for role in ('baseline', 'candidate'):
        if binding[role]['policy_digest'] != manifests[role]['policy_digest']:
            raise ValueError('Bound installed policy digest differs')
        if sha(folder / (role + '_module_setup.lua')) != binding[role]['module_setup_sha256']:
            raise ValueError('Frozen module graph differs')
    snapshots = {12: read(folder / 'step12.json')['snapshot']}
    snapshot = snapshots[12]
    if snapshot['phase'] != 'pack' or snapshot['completionist_goal']['counts'] != {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}:
        raise ValueError('Captured source Gold pack context changed')
    if hashlib.sha256(canonical(snapshot).encode()).hexdigest() != provenance['snapshot_canonical_sha256']:
        raise ValueError('Captured snapshot canonical hash differs')
    return registration, manifests, snapshots


def main():
    folder = Path(__file__).resolve().parent
    registration, manifests, snapshots = verify(folder)
    write(folder / 'comparison_started.json', {'job': 'M21', 'one_use': True,
          'registration_sha256': sha(folder / 'registration.json')})
    runtime = next(Path(name) for name in registration['external_files'] if Path(name).name.lower() == 'lua51.dll')
    library = ctypes.CDLL(str(runtime))
    library.luaL_newstate.restype = ctypes.c_void_p
    library.luaL_openlibs.argtypes = [ctypes.c_void_p]
    library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    library.lua_tolstring.restype = ctypes.c_void_p
    library.lua_close.argtypes = [ctypes.c_void_p]
    library.lua_pushcclosure.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
    library.lua_pushnumber.argtypes = [ctypes.c_void_p, ctypes.c_double]
    library.lua_setfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
    callback_type = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)
    @callback_type
    def clock(state):
        library.lua_pushnumber(state, time.perf_counter())
        return 1
    results, total_calls = {}, 0
    for role, step in ORDER:
        chunks = [b'PROFILE_INPUT=' + lua_value(snapshots[step]),
                  b'package.path="";package.cpath="";package.loaders={package.loaders[1]};io=nil;dofile=nil;loadfile=nil',
                  b'os={clock=os.clock};math.random=function()error("RNG unavailable")end;math.randomseed=math.random']
        for name in sorted(manifests[role]['policy_files']):
            if name.startswith('Brainstorm/Advisor/') and name.endswith('.lua'):
                path = folder / role / name
                chunks.append(b'package.preload[ ' + literal('probe_policy_' + path.stem) + b' ]=assert(loadstring(' +
                              literal(path.read_bytes()) + b',' + literal('@' + role + '/' + path.name) + b'))')
        chunks.append(b'package.preload.probe_engine_contract=assert(loadstring(' + literal((folder / 'engine_contract.lua').read_bytes()) + b'))')
        chunks.append(b'package.preload.probe_policy_wiring=assert(loadstring(' + literal((folder / 'policy_wiring.lua').read_bytes()) + b'))')
        source = b'\n'.join(chunks + [(folder / (role + '_module_setup.lua')).read_bytes(), (folder / 'driver.lua').read_bytes()])
        state = library.luaL_newstate()
        if not state:
            raise RuntimeError('Could not create isolated Lua state')
        try:
            library.luaL_openlibs(state)
            library.lua_pushcclosure(state, clock, 0)
            library.lua_setfield(state, -10002, b'PROBE_MONOTONIC_SECONDS')
            status = library.luaL_loadbuffer(state, source, len(source), b'@M21_detached_pack_comparison')
            if not status:
                status = library.lua_pcall(state, 0, 1, 0)
            length = ctypes.c_size_t()
            pointer = library.lua_tolstring(state, -1, ctypes.byref(length))
            raw = ctypes.string_at(pointer, length.value).decode() if pointer else ''
            if status:
                write(folder / f'{role}_step{step}_error.json', {'status': 'error', 'error': raw, 'policy': role, 'step': step})
                raise RuntimeError(raw)
            result = json.loads(raw)
            result['input_fingerprint'] = hashlib.sha256(result['input_fingerprint'].encode()).hexdigest()
            result.update(policy=role, step=step, policy_digest=manifests[role]['policy_digest'])
            write(folder / f'{role}_step{step}_result.json', result)
            print(json.dumps({key: result.get(key) for key in ('type', 'status', 'policy', 'step', 'score_calls',
                  'decision_wall_seconds', 'decision_cpu_seconds', 'input_unchanged', 'action', 'score_cache')}), flush=True)
            if result['status'] != 'complete' or not result['input_unchanged']:
                raise RuntimeError(result.get('error') or 'Captured input changed')
            if not 0 <= result['score_calls'] <= CAP or not 0 <= result['result']['evaluations'] <= CAP:
                raise RuntimeError('Decision exceeded its original pack score cap')
            total_calls += result['score_calls']
            if total_calls > TOTAL_CAP:
                raise RuntimeError('Aggregate score cap exceeded')
            results[(role, step)] = result
        finally:
            library.lua_close(state)
    pair = compare_pair(results[('baseline', 12)], results[('candidate', 12)])
    summary = {'type': 'captured_pack_comparison', 'status': 'complete', 'decisions': 2,
               'decision_order': ORDER, 'score_calls': total_calls, 'score_call_cap': TOTAL_CAP,
               'same_inputs': True, 'comparison': pair,
               'source_execution': False, 'action_dispatch': False,
               'selected_action_rescore': False, 'terminal_evidence': False, 'qualification': False,
               'per_policy': {role: {key: results[(role, 12)][key] for key in
                    ('decision_wall_seconds', 'decision_cpu_seconds', 'score_calls', 'action')}
                    for role in ('baseline', 'candidate')},
               'interpretation': 'One dependent C05 captured pack state, one full decision per frozen installed policy. Action changes, unchanged actions, errors and caps remain explicit. No terminal, causal win improvement or player odds inference.'}
    write(folder / 'comparison.json', summary)
    print(json.dumps(summary), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
