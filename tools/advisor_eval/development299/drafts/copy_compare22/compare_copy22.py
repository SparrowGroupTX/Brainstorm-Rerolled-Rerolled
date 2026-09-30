"""Four exact captured decisions; executable only after root registers/spends M22."""
from pathlib import Path
from datetime import datetime, timezone
import ctypes
import hashlib
import json
import sys
import time
from lua_bytes import literal, lua_value

ORDER = (('baseline', 31), ('candidate', 31), ('candidate', 96), ('baseline', 96))
CAP, TOTAL_CAP = 140000, 560000


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
    if (left['status'] != 'complete' or right['status'] != 'complete' or
            not left['input_unchanged'] or not right['input_unchanged'] or
            left['input_fingerprint'] != right['input_fingerprint']):
        raise ValueError('Complete paired input preservation failed')
    return {'raw_actions_equal': left['action'] == right['action'],
            'physical_actions_equal': physical_action(left['action']) == physical_action(right['action']),
            'score_call_delta': right['score_calls'] - left['score_calls'],
            'evaluations_delta': right['result']['evaluations'] - left['result']['evaluations'],
            'wall_seconds_delta': right['decision_wall_seconds'] - left['decision_wall_seconds'],
            'candidate_preflight': right['result'].get('copy_preflight'),
            'candidate_reorder_only': right['result'].get('reorder_only', False)}


def physical_action(action):
    if isinstance(action, dict) and action.get('kind') == 'reorder_jokers':
        return dict(action, area=action.get('area', 'jokers'))
    return action


def structural_action(action, snapshot):
    if not isinstance(action, dict) or action.get('kind') != 'reorder_jokers':
        return {'status': 'not_qualified', 'reason': 'This component only checks reorder permutations; no dispatch/rescore.'}
    order = action.get('order')
    jokers = snapshot['jokers']
    if (not isinstance(order, list) or any(type(v) is not int for v in order)
            or sorted(order) != list(range(1, len(jokers) + 1))
            or action.get('area', 'jokers') != 'jokers'):
        raise ValueError('Invalid Joker reorder permutation')
    for position, item in enumerate(order, 1):
        if jokers[item - 1].get('pinned') and item != position:
            raise ValueError('Reorder moves a pinned Joker')
    return {'status': 'valid_permutation_and_pins', 'source_execution_qualified': False}


def verify(folder):
    folder = Path(folder).resolve()
    registration = read(folder / 'registration.json')
    authority = read(folder / 'authority.json')
    if (folder.name != 'M22' or registration.get('job') != 'M22' or registration.get('timeout_seconds') != 30
            or authority.get('kind') != 'gold299_prospective_authority' or authority.get('status') != 'APPROVED'
            or authority.get('per_job_caps', {}).get('M22') != 30
            or datetime.now(timezone.utc) >= datetime.fromisoformat(authority['expires_at_utc'])
            or registration['authority_sha256'] != sha(folder / 'authority.json')):
        raise ValueError('Require fresh root M22 registration and authority')
    spent = read(folder / 'spent.json')
    if spent.get('job') != 'M22' or spent.get('registration_sha256') != sha(folder / 'registration.json'):
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
    expected_digests = {'baseline': '40ce8ca5f3c5860cc377309fe3b4a1bb608a6332f4bed8484ee3e68a482eacc0',
                        'candidate': 'e591f83e9b8bdcdbba288ff199836db12d40711d9b38b0df958c350bbbd0228f'}
    if {role: value['policy_digest'] for role, value in manifests.items()} != expected_digests:
        raise ValueError('Require exact installed314/315 whole policies')
    for role in manifests:
        if sha(folder / (role + '_module_setup.lua')) != provenance['module_setups'][role]['derived_setup_sha256']:
            raise ValueError('Runtime dependency graph changed')
    snapshots = {step: read(folder / f'step{step}.json')['snapshot'] for step in (31, 96)}
    for step, snapshot in snapshots.items():
        if snapshot['phase'] != 'hand' or snapshot['completionist_goal']['counts'] != {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}:
            raise ValueError('Captured source Gold context changed')
    return registration, manifests, snapshots


def main():
    folder = Path(__file__).resolve().parent
    registration, manifests, snapshots = verify(folder)
    write(folder / 'comparison_started.json', {'job': 'M22', 'one_use': True,
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
        chunks = [b'PROFILE_INPUT=' + lua_value(snapshots[step]), b'PROFILE_ROLE=' + literal(role),
                  b'package.path="";package.cpath="";package.loaders={package.loaders[1]};io=nil;dofile=nil;loadfile=nil',
                  b'os={clock=os.clock};math.random=function()error("RNG unavailable")end;math.randomseed=math.random']
        for name in sorted(manifests[role]['policy_files']):
            if name.startswith('Brainstorm/Advisor/') and name.endswith('.lua'):
                path = folder / role / name
                chunks.append(b'package.preload[ ' + literal('probe_policy_' + path.stem) + b' ]=assert(loadstring(' +
                              literal(path.read_bytes()) + b',' + literal('@' + role + '/' + path.name) + b'))')
        chunks.append(b'package.preload.probe_engine_contract=assert(loadstring(' + literal((folder / 'engine_contract.lua').read_bytes()) + b'))')
        source = b'\n'.join(chunks + [(folder / (role + '_module_setup.lua')).read_bytes(), (folder / 'driver.lua').read_bytes()])
        state = library.luaL_newstate()
        if not state:
            raise RuntimeError('Could not create isolated Lua state')
        try:
            library.luaL_openlibs(state)
            library.lua_pushcclosure(state, clock, 0)
            library.lua_setfield(state, -10002, b'PROBE_MONOTONIC_SECONDS')
            status = library.luaL_loadbuffer(state, source, len(source), b'@M22_detached_copy_comparison')
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
            try:
                result['action_structure'] = structural_action(result['action'], snapshots[step]) if result['status'] == 'complete' else {'status': 'not_qualified'}
            except ValueError as error:
                result['action_structure'] = {'status': 'invalid', 'reason': str(error)}
            write(folder / f'{role}_step{step}_result.json', result)
            print(json.dumps({key: result.get(key) for key in ('type', 'status', 'policy', 'step', 'score_calls',
                  'decision_wall_seconds', 'decision_cpu_seconds', 'input_unchanged', 'action', 'score_cache')}), flush=True)
            if result['status'] != 'complete' or not result['input_unchanged']:
                raise RuntimeError(result.get('error') or 'Captured input changed')
            if result['action_structure']['status'] == 'invalid':
                raise RuntimeError(result['action_structure']['reason'])
            if not 0 <= result['score_calls'] <= CAP or not 0 <= result['result']['evaluations'] <= CAP:
                raise RuntimeError('Decision exceeded its original ordinary score cap')
            stats = result['score_cache']
            if stats['capacity'] != 8192 or stats['stored'] > 8192:
                raise RuntimeError('Cache capacity changed')
            total_calls += result['score_calls']
            if total_calls > TOTAL_CAP:
                raise RuntimeError('Aggregate score cap exceeded')
            results[(role, step)] = result
        finally:
            library.lua_close(state)
    pairs = {str(step): compare_pair(results[('baseline', step)], results[('candidate', step)]) for step in (31, 96)}
    summary = {'type': 'captured_copy_comparison', 'status': 'complete', 'decisions': 4,
               'decision_order': ORDER, 'score_calls': total_calls, 'score_call_cap': TOTAL_CAP,
               'inputs_preserved': True, 'full_results_preserved': True, 'pairs': pairs,
               'source_execution': False, 'action_dispatch': False, 'selected_action_rescore': False,
               'terminal_evidence': False, 'qualification': False,
               'per_step': {str(step): {role: {key: results[(role, step)][key] for key in
                    ('decision_wall_seconds', 'decision_cpu_seconds', 'score_calls', 'score_cache', 'action_structure')}
                    for role in ('baseline', 'candidate')} for step in (31, 96)},
               'interpretation': 'Two selected dependent captured states, one ordered pair each. No controlled-system speed claim. Raw actions retained; physical action comparison only defaults absent reorder area to jokers. No reordered-state follow-up decision, future growth, action cost, gameplay or terminal outcome evaluated.'}
    write(folder / 'comparison.json', summary)
    print(json.dumps(summary), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
