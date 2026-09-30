"""Root-registered one-use public decision pair; no source/game/save access.

The root's process watchdog enforces30 seconds shared by verification, both
isolated Lua decisions and output. An instruction hook is a second deadline gate.
Import/verification/preparation does not evaluate a policy.
"""
from pathlib import Path
import ctypes
import hashlib
import json
import sys
import time
from lua_bytes import literal, lua_value
from module_graph import module_setup

ROLES = ('baseline', 'candidate')
CAPS = {'hand': 140000, 'shop': 50000, 'pack': 50000}
MAX_ROLE_BYTES, MAX_TOTAL_BYTES = 16 * 1024**2, 32 * 1024**2

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'),
                      parse_constant=lambda v: (_ for _ in ()).throw(ValueError('Nonfinite JSON: ' + v)))

def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')

def contained(folder, relative):
    value = Path(relative)
    if value.is_absolute() or not value.parts or '..' in value.parts:
        raise ValueError('Require contained frozen relative path')
    path = (folder / value).resolve()
    path.relative_to(folder.resolve())
    return path

def validate_snapshot(snapshot):
    if not isinstance(snapshot, dict) or snapshot.get('phase') not in CAPS:
        raise ValueError('Require supplied public decision phase')
    if any(key in snapshot for key in ('retry_context', '_retry', '_retry_context', '_shop_scoring', 'pseudorandom')):
        raise ValueError('Internal/retry state is not an admitted public input')
    # Missing public fields stay missing. No defaults, hidden identities, next
    # shop roll information or source initialization is reconstructed here.
    return CAPS[snapshot['phase']]

def verify(folder):
    folder = Path(folder).resolve()
    registration = read(folder / 'registration.json')
    metadata = registration.get('metadata', {})
    if folder.name not in tuple('P%02d' % i for i in range(1, 7)):
        raise ValueError('Only fresh P01..P06 slots are admitted')
    authority = read(folder / 'authority.json')
    if (registration.get('kind') != 'loss328_registered_job' or
        registration.get('job') != folder.name or registration.get('timeout_seconds') != 30 or
        metadata.get('kind') != 'public_state_pair' or metadata.get('decision_order') != list(ROLES) or
        metadata.get('source_execution') is not False or metadata.get('action_dispatch') is not False or
        metadata.get('selected_action_rescore') is not False or
        authority.get('kind') != 'fresh_loss_validation_authority' or authority.get('status') != 'ACTIVE' or
        authority.get('limits') != {'detached_comparison_jobs': 6, 'seconds_per_comparison_job': 30,
         'complete_attempt_jobs': 6, 'seconds_per_complete_attempt': 180, 'total_worker_seconds': 1260,
         'search_jobs': 0, 'other_source_component_jobs': 0} or
        registration.get('authority_sha256') != sha(folder / 'authority.json') or
        sha(folder.parent / 'authority.json') != sha(folder / 'authority.json')):
        raise ValueError('Fresh exact public comparison authority/registration required')
    reservation = folder.parent / (folder.name + '_reservation.json')
    if ((folder.parent / 'CLOSED.json').exists() or
        registration.get('reservation_sha256') != sha(reservation) or
        read(reservation).get('job') != folder.name or read(reservation).get('timeout_seconds') != 30 or
        read(reservation).get('one_use') is not True):
        raise ValueError('Active one-use root reservation required')
    spent = read(folder / 'spent.json')
    if (spent.get('job') != folder.name or spent.get('one_use') is not True or
        spent.get('registration_sha256') != sha(folder / 'registration.json')):
        raise ValueError('Root one-use spent receipt required')
    files = registration.get('files', {})
    for name, expected in files.items():
        if sha(contained(folder, name)) != expected:
            raise ValueError('Frozen input changed: ' + name)
    for name in ('compare_public.py', 'driver.lua', 'module_graph.py', 'lua_bytes.py',
                 'policy_wiring.lua', 'engine_contract.lua', 'snapshot.json', 'input_provenance.json'):
        if name not in files:
            raise ValueError('Missing frozen worker/input: ' + name)
    if Path(__file__).resolve() != folder / 'compare_public.py':
        raise ValueError('Invoke the exact frozen registered worker')
    external = registration.get('external_files', {})
    if len(external) != 2 or str(Path(sys.executable).resolve()) not in external:
        raise ValueError('Exact Python and isolated Lua library required')
    for name, expected in external.items():
        if Path(name).name.lower() not in ('python.exe', 'lua51.dll') or sha(name) != expected:
            raise ValueError('Unexpected or changed external runtime')
    snapshot = read(folder / 'snapshot.json')
    cap = validate_snapshot(snapshot)
    origin = read(folder / 'input_provenance.json')
    if (origin.get('kind') != 'redacted_public_snapshot328' or origin.get('raw_fingerprint_used') is not False or
        origin.get('snapshot_sha256') != sha(folder / 'snapshot.json') or
        origin.get('snapshot_canonical_sha256') != hashlib.sha256(canonical(snapshot)).hexdigest() or
        metadata.get('input') != {'path': 'snapshot.json', 'sha256': origin['snapshot_sha256'],
                                'phase': snapshot['phase'], 'sequence': origin.get('sequence')} or
        metadata.get('score_caps') != {role: cap for role in ROLES} or metadata.get('total_score_cap') != 2 * cap or
        metadata.get('max_output_bytes_per_role') != MAX_ROLE_BYTES or
        metadata.get('max_output_bytes_total') != MAX_TOTAL_BYTES):
        raise ValueError('Unchanged public input provenance/caps required')
    policies = metadata.get('policies', {})
    if set(policies) != set(ROLES):
        raise ValueError('Baseline and candidate must each be frozen')
    manifests = {}
    for role, spec in policies.items():
        record = read(contained(folder, spec['record']))
        policy = record['policy']
        if (hashlib.sha256(canonical(policy['policy_files'])).hexdigest() != policy['policy_digest'] or
            policy['policy_digest'] != spec.get('policy_digest')):
            raise ValueError('Policy manifest mismatch')
        policy_root = contained(folder, spec['root'])
        for name, expected in policy['policy_files'].items():
            if sha(contained(policy_root, name)) != expected:
                raise ValueError('Frozen policy mismatch: ' + role + '/' + name)
        setup, omitted = module_setup((policy_root / 'Brainstorm/Advisor/runtime.lua').read_bytes())
        if contained(folder, spec['setup']).read_bytes() != setup:
            raise ValueError('Frozen production graph derivation differs')
        manifests[role] = (policy_root, policy, setup, omitted)
    return registration, metadata, snapshot, manifests

class Lua:
    def __init__(self, runtime, deadline):
        self.lib = lib = ctypes.CDLL(str(runtime))
        lib.luaL_newstate.restype = ctypes.c_void_p
        lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
        lib.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
        lib.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        lib.lua_tolstring.restype = ctypes.c_void_p
        lib.lua_close.argtypes = [ctypes.c_void_p]
        lib.lua_pushcclosure.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]
        lib.lua_pushnumber.argtypes = [ctypes.c_void_p, ctypes.c_double]
        lib.lua_pushboolean.argtypes = [ctypes.c_void_p, ctypes.c_int]
        lib.lua_setfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
        callback = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p)
        @callback
        def clock(state):
            lib.lua_pushnumber(state, time.perf_counter()); return 1
        @callback
        def expired(state):
            lib.lua_pushboolean(state, time.perf_counter() >= deadline); return 1
        self.clock, self.expired = clock, expired

    def evaluate(self, source):
        lib = self.lib; state = lib.luaL_newstate()
        if not state:
            raise RuntimeError('Could not allocate isolated Lua state')
        try:
            lib.luaL_openlibs(state)
            for key, function in ((b'PROBE_MONOTONIC_SECONDS', self.clock), (b'PROBE_DEADLINE_EXCEEDED', self.expired)):
                lib.lua_pushcclosure(state, function, 0); lib.lua_setfield(state, -10002, key)
            status = lib.luaL_loadbuffer(state, source, len(source), b'@loss328_captured_public')
            if not status:
                status = lib.lua_pcall(state, 0, 1, 0)
            length = ctypes.c_size_t(); pointer = lib.lua_tolstring(state, -1, ctypes.byref(length))
            if length.value > MAX_ROLE_BYTES:
                raise RuntimeError('Lua role output exceeded16MiB')
            raw = ctypes.string_at(pointer, length.value) if pointer else b''
            if status:
                raise RuntimeError(raw.decode('utf-8', 'replace')[:2048])
            return raw
        finally:
            lib.lua_close(state)

def build_source(folder, snapshot, manifest, cap):
    root, policy, setup, _ = manifest
    chunks = [b'PROFILE_INPUT=' + lua_value(snapshot), b'PROFILE_SCORE_CAP=' + str(cap).encode(),
              b'package.path="";package.cpath="";package.loaders={package.loaders[1]};io=nil;dofile=nil;loadfile=nil',
              b'os={clock=os.clock};math.random=function()error("RNG unavailable")end;math.randomseed=math.random',
              b'pseudorandom=math.random;pseudoseed=math.random;G=nil;Brainstorm=nil']
    for name in sorted(policy['policy_files']):
        if name.startswith('Brainstorm/Advisor/') and name.endswith('.lua'):
            path = root / name
            chunks.append(b'package.preload[ ' + literal('probe_policy_' + path.stem) + b' ]=assert(loadstring(' +
                          literal(path.read_bytes()) + b',' + literal('@frozen/' + path.name) + b'))')
    for name in ('engine_contract', 'policy_wiring'):
        chunks.append(b'package.preload[ ' + literal('probe_' + name) + b' ]=assert(loadstring(' +
                      literal((folder / (name + '.lua')).read_bytes()) + b'))')
    return b'\n'.join(chunks + [setup, b'load=nil;loadstring=nil', (folder / 'driver.lua').read_bytes()])

def main():
    started = time.perf_counter(); deadline = started + 30
    folder = Path(__file__).resolve().parent
    registration, metadata, snapshot, manifests = verify(folder)
    write(folder / 'comparison_started.json', {'job': folder.name, 'one_use': True,
          'registration_sha256': sha(folder / 'registration.json'), 'shared_seconds': 30})
    runtime = next(Path(p) for p in registration['external_files'] if Path(p).name.lower() == 'lua51.dll')
    lua = Lua(runtime, deadline); results = {}; output_bytes = 0
    input_sha = sha(folder / 'snapshot.json')
    for role in ROLES:
        if time.perf_counter() >= deadline:
            write(folder / (role + '_unstarted.json'), {'status': 'timeout', 'reason': 'Shared deadline elapsed before this role.'})
            raise TimeoutError('Shared captured-pair deadline')
        try:
            source = build_source(folder, snapshot, manifests[role], metadata['score_caps'][role])
            raw = lua.evaluate(source)
            result = json.loads(raw)
            summary = result['summary']
            summary.update(role=role, input_sha256=input_sha, policy_digest=manifests[role][1]['policy_digest'],
                           evidence_path=role + '_result.json', evidence_sha256=hashlib.sha256(raw).hexdigest())
            summary_bytes = canonical(summary)
            if len(summary_bytes) > 65536 or len(raw) + len(summary_bytes) > MAX_ROLE_BYTES:
                raise RuntimeError('Role evidence and compact summary exceeded16MiB')
            output_bytes += len(raw) + len(summary_bytes)
            if output_bytes > MAX_TOTAL_BYTES:
                raise RuntimeError('Total pair output exceeded32MiB')
            with (folder / (role + '_result.json')).open('xb') as stream:
                stream.write(raw)
            if sha(folder / 'snapshot.json') != input_sha:
                raise RuntimeError('Frozen public input file changed')
            with (folder / (role + '_summary.json')).open('xb') as stream:
                stream.write(summary_bytes)
            print(json.dumps({key: summary.get(key) for key in ('role', 'status', 'action', 'score_calls',
                  'reported_evaluations', 'input_unchanged', 'full_result_status', 'evidence_path', 'evidence_sha256')},
                  separators=(',', ':')), flush=True)
            results[role] = summary
            if summary['status'] != 'complete' or not summary['input_unchanged']:
                raise RuntimeError(summary.get('error') or 'Incomplete/mutating policy decision')
            if not 0 <= summary['score_calls'] <= metadata['score_caps'][role]:
                raise RuntimeError('Actual score count exceeded registered cap')
        except Exception as error:
            write(folder / (role + '_error.json'), {'status': 'timeout' if time.perf_counter() >= deadline else 'error',
                  'error': str(error)[:2048], 'input_sha256': input_sha,
                  'input_file_unchanged': sha(folder / 'snapshot.json') == input_sha, 'role': role,
                  'elapsed_seconds': time.perf_counter() - started})
            raise
    write(folder / 'comparison.json', {'status': 'complete', 'input_sha256': input_sha,
          'source_execution': False, 'terminal_evidence': False, 'qualification': False,
          'actions_equal': results['baseline']['action'] == results['candidate']['action'],
          'score_calls': sum(r['score_calls'] for r in results.values()), 'output_bytes': output_bytes,
          'elapsed_seconds': time.perf_counter() - started,
          'full_results_preserved': all(r['full_result_status'] == 'preserved' for r in results.values()),
          'scope': 'One redacted dependent public input, two frozen decisions; missing context and omitted futures are not reconstructed.'})
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
