"""Fresh, one-use paired public-snapshot evaluations; never dispatch source code.

Importing and preparing the driver performs no game/source/runtime access.
Execution requires an immutable parent registration and exactly two isolated
15-second policy workers. Policy Lua files are embedded from each own freeze;
filesystem and native module fallback are disabled in the worker Lua state.
"""
from __future__ import annotations

import argparse
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
BOUNDARY = b'local function json(value)'
POLICIES = {'282', '286'}
POLICY_SECONDS, PAIR_SECONDS = 15, 60


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def sha(path):
    with Path(path).open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'),
                      parse_constant=lambda x: (_ for _ in ()).throw(ValueError('Nonfinite JSON')))


def create_json(path, value):
    with Path(path).open('x', encoding='utf-8') as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write('\n')


def checked(ref):
    path = Path(ref['path']).resolve()
    if sha(path) != ref['sha256']:
        raise ValueError('Changed frozen input: ' + str(path))
    return path


def literal(raw):
    """Lua long string which cannot terminate on embedded policy bytes."""
    raw = raw.encode() if isinstance(raw, str) else raw
    # Lua normalizes CR/CRLF inside long strings. Preserve them explicitly so
    # detached public strings and embedded source retain their exact bytes.
    if b'\r' in raw:
        return b'(' + b'.."\\013"..'.join(literal(part) for part in raw.split(b'\r')) + b')'
    equal = b''
    while b']' + equal + b']' in raw:
        equal += b'='
    # A leading newline is discarded by Lua, preserving the original byte zero.
    return b'[' + equal + b'[\n' + raw + b']' + equal + b']'


def lua_value(value):
    if value is None:
        return b'nil'
    if type(value) is bool:
        return b'true' if value else b'false'
    if type(value) in (int, float):
        if not math.isfinite(value):
            raise ValueError('Nonfinite Lua input')
        return str(value).encode()
    if isinstance(value, str):
        return literal(value)
    if isinstance(value, list):
        return b'{' + b','.join(lua_value(x) for x in value) + b'}'
    if isinstance(value, dict):
        # Without spaces, a string key starts with [[[ and the Lua lexer sees
        # a long-string opener instead of the table-index opening bracket.
        return b'{' + b','.join(b'[ ' + lua_value(k) + b' ]=' + lua_value(v)
                                for k, v in sorted(value.items())) + b'}'
    raise ValueError('Unsupported Lua input')


def module_setup(source):
    if source.count(BOUNDARY) != 1:
        raise ValueError('Unknown module setup boundary')
    prefix = source.split(BOUNDARY)[0]
    if not prefix.startswith(b'-- Experimental dispatcher') or b'local modules=' not in prefix:
        raise ValueError('Unknown module setup')
    if b'local function state_fingerprint' in prefix or b'for step=1,500' in prefix:
        raise ValueError('Detached setup reached source dispatcher')
    return prefix


def validate_spec(spec):
    if (spec.get('kind') != 'captured_snapshot_pair287' or spec.get('qualification') is not False or
            spec.get('job_id') not in ('A1', 'A2', 'A3', 'A4') or
            spec.get('policy_seconds') != POLICY_SECONDS or spec.get('pair_seconds') != PAIR_SECONDS or
            set(spec.get('policies', {})) != POLICIES or
            set(spec.get('policy_order', [])) != POLICIES or len(spec['policy_order']) != 2 or
            spec.get('options') != 'product_defaults_no_overrides' or
            spec.get('source_execution') is not False or spec.get('save_access') != 'none'):
        raise ValueError('Unsupported fixed paired snapshot specification')
    if Path(spec['runtime']['path']).name.lower() != 'lua51.dll':
        raise ValueError('Require isolated lua51.dll')


def verify_parent(spec):
    """The root owns fresh authority/admission; this child binds its one-use job."""
    authority = read(checked(spec['authority']))
    parent = read(checked(spec['parent_registration']))
    if (authority.get('kind') != 'prospective287_authority' or
            authority.get('status') != 'APPROVED' or authority.get('approved_by') != 'user' or
            not authority.get('approval_reference') or
            spec['job_id'] not in authority.get('allowed_job_ids', []) or
            authority.get('serial_only') is not True or authority.get('replacements') != 0 or
            authority.get('per_job_caps', {}).get(spec['job_id']) != PAIR_SECONDS or
            parent.get('kind') != 'prospective287_job' or parent.get('status') != 'REGISTERED' or
            parent.get('job_id') != spec['job_id'] or
            parent.get('authority_sha256') != spec['authority']['sha256'] or
            parent.get('timeout_seconds') != PAIR_SECONDS or parent.get('per_policy_seconds') != POLICY_SECONDS or
            parent.get('separate_modeled_legality_score_allowed') is not True or
            parent.get('source_execution') is not False or parent.get('no_replacements') is not True or
            parent.get('policy_order') != spec['policy_order'] or
            parent.get('policy_digests') != {k: v['policy_digest'] for k, v in spec['policies'].items()} or
            parent.get('snapshot', {}).get('sha256') != spec['snapshot']['sha256'] or
            Path(parent.get('snapshot', {}).get('path', '')).resolve() != Path(spec['snapshot']['path']).resolve()):
        raise ValueError('Require fresh user-authorized parent job registration')
    checked(parent['historical_registration'])
    deadline = datetime.fromisoformat(authority['expires_at_utc'].replace('Z', '+00:00'))
    if deadline.tzinfo is None or deadline.timestamp() <= time.time():
        raise ValueError('Captured comparison authority expired')
    if not Path(authority['ledger_directory']).is_absolute():
        raise ValueError('Require fixed absolute parent ledger')
    return parent


def prepare(spec_path, output):
    spec_path, output = Path(spec_path).resolve(), Path(output).resolve()
    spec = read(spec_path); validate_spec(spec); verify_parent(spec)
    snapshot_path = checked(spec['snapshot']); snapshot = read(snapshot_path)
    if snapshot.get('phase') != 'hand':
        raise ValueError('Only the four registered hand decisions are admitted')
    setup = module_setup(checked(spec['module_setup']).read_bytes())
    contract = checked(spec['contract'])
    driver = checked(spec['driver'])
    if spec['runner']['sha256'] != sha(Path(__file__)):
        raise ValueError('Invoke the exact registered Python wrapper')
    checked(spec['runner'])
    frozen_policies = {}
    for role, policy in spec['policies'].items():
        record = read(checked(policy['record']))
        manifest = record['policy']
        if (manifest['policy_digest'] != policy['policy_digest'] or
                digest(manifest['policy_files']) != policy['policy_digest']):
            raise ValueError('Policy manifest mismatch')
        root = Path(policy['root']).resolve()
        files = {name: expected for name, expected in manifest['policy_files'].items()
                 if name.startswith('Brainstorm/Advisor/') and name.endswith('.lua')}
        required = {'snapshot', 'scoring', 'search', 'decision', 'strategy', 'consumables', 'synergies'}
        if not required.issubset({Path(name).stem for name in files}):
            raise ValueError('Incomplete frozen policy')
        if role == '282' and any(Path(name).stem == 'resource_finish' for name in files):
            raise ValueError('Baseline282 must not inherit resource_finish')
        for name, expected in files.items():
            if sha(root / name) != expected:
                raise ValueError('Frozen policy bytes mismatch: ' + name)
        frozen_policies[role] = (root, files)
    authority = read(checked(spec['authority']))
    parent_reservation = Path(authority['ledger_directory']) / (spec['job_id'] + '_captured_reservation.json')
    # The authority's fixed ledger prevents executing this job again by merely
    # choosing another output directory. A failed preparation still spends it.
    create_json(parent_reservation, {'output': str(output), 'spec_sha256': sha(spec_path),
                                    'parent_registration_sha256': spec['parent_registration']['sha256']})
    output.mkdir(parents=False, exist_ok=False)
    frozen = output / 'frozen'; frozen.mkdir()
    shutil.copyfile(spec_path, frozen / 'spec.json')
    shutil.copyfile(snapshot_path, frozen / 'snapshot.json')
    shutil.copyfile(Path(__file__), frozen / 'captured_snapshot_pair.py')
    shutil.copyfile(driver, frozen / 'captured_snapshot_pair.lua')
    shutil.copyfile(contract, frozen / 'engine_contract.lua')
    (frozen / 'module_setup.lua').write_bytes(setup)
    # Runtime is only read after fresh parent authorization has been verified.
    shutil.copyfile(checked(spec['runtime']), frozen / 'lua51.dll')
    for role, (root, files) in frozen_policies.items():
        destination = frozen / role; destination.mkdir()
        for name, expected in files.items():
            target = destination / Path(name).name
            shutil.copyfile(root / name, target)
            if sha(target) != expected or sha(root / name) != expected:
                raise ValueError('Policy changed while freezing')
    expected = {'snapshot.json': spec['snapshot']['sha256'], 'spec.json': sha(spec_path),
                'captured_snapshot_pair.py': spec['runner']['sha256'],
                'captured_snapshot_pair.lua': spec['driver']['sha256'],
                'engine_contract.lua': spec['contract']['sha256'], 'lua51.dll': spec['runtime']['sha256'],
                'module_setup.lua': hashlib.sha256(setup).hexdigest()}
    if any(sha(frozen / name) != expected_sha for name, expected_sha in expected.items()):
        raise ValueError('Inputs changed during captured freeze')
    manifest = {'kind': 'captured_snapshot_pair287_registration', 'spec_sha256': sha(spec_path),
                'job_id': spec['job_id'], 'qualification': False,
                'frozen_files': {str(p.relative_to(frozen)).replace('\\', '/'): sha(p)
                                 for p in frozen.rglob('*') if p.is_file()},
                'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version}
    create_json(output / 'registration.json', manifest)
    verify(output)
    return manifest


def verify(output):
    output = Path(output).resolve(); frozen = output / 'frozen'
    manifest = read(output / 'registration.json')
    if manifest.get('kind') != 'captured_snapshot_pair287_registration':
        raise ValueError('Unknown paired registration')
    spec = read(frozen / 'spec.json'); validate_spec(spec); verify_parent(spec)
    authority = read(checked(spec['authority']))
    reservation = read(Path(authority['ledger_directory']) / (spec['job_id'] + '_captured_reservation.json'))
    if reservation != {'output': str(output), 'spec_sha256': manifest['spec_sha256'],
                       'parent_registration_sha256': spec['parent_registration']['sha256']}:
        raise ValueError('Captured job reservation differs')
    actual = {str(p.relative_to(frozen)).replace('\\', '/'): sha(p)
              for p in frozen.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    if actual != manifest['frozen_files'] or sha(frozen / 'spec.json') != manifest['spec_sha256']:
        raise ValueError('Frozen paired evidence changed')
    if (manifest['job_id'] != spec['job_id'] or
            manifest['python_executable'] != str(Path(sys.executable).resolve()) or
            manifest['python_version'] != sys.version):
        raise ValueError('Paired job/runtime changed')
    return spec


def worker_source(output, role):
    frozen = Path(output) / 'frozen'
    if role not in POLICIES:
        raise ValueError('Unknown policy')
    chunks = [b'PROBE_MONOTONIC_SECONDS=os.clock',
              b'PROFILE_INPUT=' + lua_value(read(frozen / 'snapshot.json')),
              b'package.path="";package.cpath="";package.loaders={package.loaders[1]}']
    for path in sorted((frozen / role).glob('*.lua')):
        name = b'probe_policy_' + path.stem.encode()
        chunks.append(b'package.preload[ ' + literal(name) + b' ]=assert(loadstring(' +
                      literal(path.read_bytes()) + b',' + literal(b'@policy' + role.encode() + b'/' + path.name.encode()) + b'))')
    chunks.append(b'package.preload.probe_engine_contract=assert(loadstring(' +
                  literal((frozen / 'engine_contract.lua').read_bytes()) + b'))')
    chunks.append((frozen / 'module_setup.lua').read_bytes())
    chunks.append((frozen / 'captured_snapshot_pair.lua').read_bytes())
    return b'\n'.join(chunks)


def run_worker(output, role):
    output = Path(output).resolve(); spec = verify(output)
    lease = read(output / (role + '_started.json'))
    if lease.get('registration_sha256') != sha(output / 'registration.json') or lease.get('role') != role:
        raise ValueError('Missing exact policy lease')
    create_json(output / (role + '_worker_started.json'), {'role': role, 'one_use': True})
    library = ctypes.CDLL(str(output / 'frozen/lua51.dll'))
    library.luaL_newstate.restype = ctypes.c_void_p
    library.luaL_openlibs.argtypes = [ctypes.c_void_p]
    library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    library.lua_tolstring.restype = ctypes.c_void_p
    library.lua_close.argtypes = [ctypes.c_void_p]
    source = worker_source(output, role); state = library.luaL_newstate()
    if not state:
        raise RuntimeError('Could not allocate isolated Lua state')
    try:
        library.luaL_openlibs(state)
        status = library.luaL_loadbuffer(state, source, len(source), b'@captured_snapshot_pair.lua')
        if not status:
            status = library.lua_pcall(state, 0, 1, 0)
        length = ctypes.c_size_t(); pointer = library.lua_tolstring(state, -1, ctypes.byref(length))
        result = ctypes.string_at(pointer, length.value).decode('utf-8', 'replace') if pointer else ''
        if status:
            raise RuntimeError(result)
        row = json.loads(result)
        for key in ('input_fingerprint', 'action_fingerprint'):
            row[key] = hashlib.sha256(row[key].encode()).hexdigest()
        row['policy'] = role; row['policy_digest'] = spec['policies'][role]['policy_digest']
        print(json.dumps(row, allow_nan=False), flush=True)
    finally:
        library.lua_close(state)


def execute(output):
    output = Path(output).resolve(); spec = verify(output)
    create_json(output / 'execution_started.json', {'registration_sha256': sha(output / 'registration.json'),
                'started_utc': datetime.now(timezone.utc).isoformat(), 'one_use': True})
    started = time.perf_counter(); reports = []
    for role in spec['policy_order']:
        if time.perf_counter() - started + POLICY_SECONDS > PAIR_SECONDS:
            reports.append({'policy': role, 'status': 'not_started', 'reason': 'pair_deadline_admission'})
            continue
        verify(output)
        create_json(output / (role + '_started.json'), {'registration_sha256': sha(output / 'registration.json'),
                    'role': role, 'wall_cap_seconds': POLICY_SECONDS})
        log = output / (role + '.log'); began = time.perf_counter()
        command = [sys.executable, '-B', '-u', str(output / 'frozen/captured_snapshot_pair.py'),
                   '--worker', str(output), '--policy', role]
        with log.open('x', encoding='utf-8') as handle:
            try:
                code = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT,
                                      timeout=POLICY_SECONDS,
                                      creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).returncode
            except subprocess.TimeoutExpired:
                code = 'timeout'
            except OSError as error:
                code = 'launch_error'; handle.write(str(error) + '\n')
        elapsed = time.perf_counter() - began
        row, error = None, None
        try:
            row = read(log)
        except (ValueError, OSError) as problem:
            error = str(problem)
        status = 'timeout' if code == 'timeout' else 'complete' if code == 0 and isinstance(row, dict) else 'error'
        if status == 'complete' and (row.get('type') != 'captured_snapshot_pair_decision' or
                                     row.get('input_unchanged') is not True or row.get('policy') != role or
                                     row.get('policy_digest') != spec['policies'][role]['policy_digest']):
            status = 'error'; error = 'Worker result provenance/input mismatch'
        reports.append({'policy': role, 'status': status, 'exit_code': code,
                        'elapsed_seconds': elapsed, 'log_sha256': sha(log), 'row': row,
                        'parse_error': error, 'command': command})
        create_json(output / (role + '_report.json'), reports[-1])
    integrity = None
    try:
        verify(output)
    except (ValueError, OSError) as problem:
        integrity = str(problem)
    original_input_after = None
    try:
        original_input_after = sha(spec['snapshot']['path'])
        if original_input_after != spec['snapshot']['sha256']:
            integrity = 'Original source snapshot changed'
    except OSError as problem:
        integrity = str(problem)
    report = {'schema': 1, 'job_id': spec['job_id'], 'qualification': False,
              'status': 'complete' if not integrity and all(x['status'] == 'complete' for x in reports) else 'incomplete',
              'elapsed_seconds': time.perf_counter() - started, 'policy_reports': reports,
              'input_sha256_before': spec['snapshot']['sha256'],
              'input_sha256_after': original_input_after, 'integrity_error': integrity,
              'source_execution': False, 'terminal_outcome': None, 'win_rate_evidence': False}
    create_json(output / 'report.json', report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--prepare', type=Path); modes.add_argument('--execute', type=Path)
    modes.add_argument('--worker', type=Path); modes.add_argument('--verify', type=Path)
    parser.add_argument('--output', type=Path); parser.add_argument('--policy', choices=sorted(POLICIES))
    args = parser.parse_args()
    if args.prepare:
        if not args.output:
            parser.error('--prepare requires --output')
        print(json.dumps(prepare(args.prepare, args.output)))
    elif args.worker:
        run_worker(args.worker, args.policy)
    elif args.execute:
        report = execute(args.execute)
        print(json.dumps({k: report[k] for k in ('job_id', 'status', 'elapsed_seconds')}))
    else:
        print(json.dumps({'verified': verify(args.verify)['job_id']}))


if __name__ == '__main__':
    main()
