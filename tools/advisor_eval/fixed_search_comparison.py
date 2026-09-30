"""One-use, explicitly authorized 285/286 fixed-work search measurement.

Importing this module does no I/O. No source ZIP, game, save or historical runner
is opened. Only register/run/worker may access the separately approved Lua DLL.
"""
from __future__ import annotations

import argparse
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
MODEL = 'Brainstorm/Core/jokerless_opening.lua'
PROFILE = 'all_unlocked_discovered_v1'
JOBS = (
    {'id': 'D1', 'policy': '285', 'target_planet': 'c_mars', 'start': 11123177},
    {'id': 'D2', 'policy': '286', 'target_planet': 'c_mars', 'start': 11123177},
    {'id': 'D3', 'policy': '286', 'target_planet': 'c_jupiter', 'start': 11223177},
    {'id': 'D4', 'policy': '285', 'target_planet': 'c_jupiter', 'start': 11223177},
)
LIMIT, BATCH, MATCH_CAP, WORKER_SECONDS, TOTAL_SECONDS = 100000, 1000, 16, 15, 60
BASELINE_DIGEST = '94ab92fc5fc074c8f6dd05c513083c77d23bb9992fff0dd2732083e2772e1095'


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def sha(path):
    with Path(path).open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'),
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError('Nonfinite JSON')))


def create_json(path, value):
    with Path(path).open('x', encoding='utf-8') as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write('\n')


def checked_file(ref):
    path = Path(ref['path']).resolve()
    if sha(path) != ref['sha256']:
        raise ValueError('Provenance changed: ' + str(path))
    return path


def utc_timestamp(value):
    stamp = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if stamp.tzinfo is None:
        raise ValueError('Authority deadline must include timezone')
    return stamp.timestamp()


def validate_proposal(proposal):
    if proposal.get('kind') != 'fixed_search286_proposal' or proposal.get('status') != 'READY_FOR_AUTHORIZATION':
        raise ValueError('Require finalized search-only proposal')
    required = {'jobs': list(JOBS), 'indices_per_job': LIMIT, 'batch_limit': BATCH,
                'match_cap': MATCH_CAP, 'worker_seconds': WORKER_SECONDS,
                'total_seconds': TOTAL_SECONDS, 'serial': True, 'replacements': 0}
    if canonical(proposal.get('limits')) != canonical(required):
        raise ValueError('Fixed search allocation differs')
    if proposal.get('profile') != PROFILE or proposal.get('qualification') is not False:
        raise ValueError('Require unqualified synthetic profile')
    policies = proposal['policies']
    if set(policies) != {'285', '286'} or policies['285']['policy_digest'] != BASELINE_DIGEST:
        raise ValueError('Require exact frozen285 baseline')
    for role in policies:
        if policies[role]['version'] != f'2.{int(role) - 200}.0-alpha':
            raise ValueError('Unexpected policy version')
        if not isinstance(policies[role].get('policy_digest'), str) or len(policies[role]['policy_digest']) != 64:
            raise ValueError('Candidate policy freeze incomplete')
    runtime = proposal['runtime']
    if Path(runtime['path']).name.lower() != 'lua51.dll':
        raise ValueError('Only isolated lua51.dll runtime is supported')
    if proposal.get('source_access') != 'none' or proposal.get('save_access') != 'none':
        raise ValueError('Pure search must not access original source or saves')
    if set(proposal['adapter_files']) != {'python', 'lua'}:
        raise ValueError('Require exactly the two reviewed runner files')


def validate_authority(authority, proposal_path, now=None):
    now = time.time() if now is None else now
    expected = {'kind': 'fixed_search286_authority', 'status': 'APPROVED',
                'approved_by': 'user', 'proposal_sha256': sha(proposal_path),
                'max_workers': 4, 'worker_seconds': 15, 'total_seconds': 60}
    if any(authority.get(key) != value for key, value in expected.items()):
        raise ValueError('Require fresh explicit search-only authority')
    if not isinstance(authority.get('approval_reference'), str) or not authority['approval_reference'].strip():
        raise ValueError('Missing explicit user approval reference')
    if not isinstance(authority.get('authority_id'), str) or not authority['authority_id'].strip():
        raise ValueError('Missing fresh authority identity')
    if utc_timestamp(authority['expires_at_utc']) <= now:
        raise ValueError('Authority expired')
    ledger = Path(authority['ledger_directory'])
    if not ledger.is_absolute():
        raise ValueError('Authority must bind an absolute one-use ledger directory')
    validate_proposal(read(proposal_path))
    return ledger.resolve()


def verify_inputs(proposal):
    """Called only after authority validation; never reads the game executable."""
    for role, spec in proposal['policies'].items():
        record = read(checked_file(spec['record']))
        if record['version'] != spec['version'] or record['policy']['policy_digest'] != spec['policy_digest']:
            raise ValueError('Frozen policy record mismatch')
        if digest(record['policy']['policy_files']) != spec['policy_digest']:
            raise ValueError('Policy manifest digest mismatch')
        model = checked_file(spec['model'])
        if record['policy']['policy_files'].get(MODEL) != sha(model):
            raise ValueError('Search module not from declared frozen policy')
    catalog = read(checked_file(proposal['catalog']['source_record']))
    for key in proposal['catalog']['json_path']:
        catalog = catalog[key]
    if digest(catalog) != proposal['catalog']['catalog_digest']:
        raise ValueError('Synthetic catalog changed')
    checked_file(proposal['runtime'])
    for ref in proposal['adapter_files'].values():
        checked_file(ref)
    if proposal['adapter_files']['python']['sha256'] != sha(Path(__file__)):
        raise ValueError('Invoke the exact proposed Python runner')
    return catalog


def register(authority_path, proposal_path):
    """Reserve this authority's four one-use jobs; exclusive directory blocks reuse."""
    authority_path, proposal_path = Path(authority_path).resolve(), Path(proposal_path).resolve()
    authority = read(authority_path)
    ledger = validate_authority(authority, proposal_path)
    proposal = read(proposal_path)
    catalog = verify_inputs(proposal)
    ledger.mkdir(parents=False, exist_ok=False)
    frozen = ledger / 'frozen'; frozen.mkdir()
    for name, ref in proposal['adapter_files'].items():
        shutil.copyfile(checked_file(ref), frozen / ('fixed_search_comparison.' + ('py' if name == 'python' else 'lua')))
    for role, spec in proposal['policies'].items():
        shutil.copyfile(checked_file(spec['model']), frozen / (role + '.lua'))
    shutil.copyfile(checked_file(proposal['runtime']), frozen / 'lua51.dll')
    create_json(frozen / 'catalog.json', catalog)
    manifest = {'schema': 1, 'kind': 'fixed_search286_registration',
                'authority': {'path': str(authority_path), 'sha256': sha(authority_path)},
                'proposal': {'path': str(proposal_path), 'sha256': sha(proposal_path)},
                'authority_id': authority['authority_id'], 'ledger_directory': str(ledger),
                'frozen_files': {p.name: sha(p) for p in frozen.iterdir()},
                'policies': {r: s['policy_digest'] for r, s in proposal['policies'].items()},
                'profile': PROFILE, 'catalog_digest': digest(catalog),
                'runtime_sha256': proposal['runtime']['sha256'], 'reserved_jobs': 4,
                'reserved_seconds': 60, 'qualification': False, 'source_access': 'none',
                'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version}
    create_json(ledger / 'registration.json', manifest)
    for job in JOBS:
        create_json(ledger / (job['id'] + '_registration.json'),
                    {'batch_registration_sha256': sha(ledger / 'registration.json'),
                     'job': job, 'indices': LIMIT, 'wall_cap_seconds': WORKER_SECONDS})
    return manifest


def verify_registration(ledger):
    ledger = Path(ledger).resolve(); manifest = read(ledger / 'registration.json')
    if manifest.get('kind') != 'fixed_search286_registration' or manifest['ledger_directory'] != str(ledger):
        raise ValueError('Unexpected registration')
    authority_path = checked_file(manifest['authority'])
    proposal_path = checked_file(manifest['proposal'])
    authority = read(authority_path)
    if validate_authority(authority, proposal_path) != ledger:
        raise ValueError('Authority ledger changed')
    proposal = read(proposal_path)
    expected_files = {'fixed_search_comparison.py': proposal['adapter_files']['python']['sha256'],
                      'fixed_search_comparison.lua': proposal['adapter_files']['lua']['sha256'],
                      '285.lua': proposal['policies']['285']['model']['sha256'],
                      '286.lua': proposal['policies']['286']['model']['sha256'],
                      'lua51.dll': proposal['runtime']['sha256']}
    expected_fields = {'authority_id': authority['authority_id'],
                       'policies': {r: s['policy_digest'] for r, s in proposal['policies'].items()},
                       'profile': PROFILE, 'catalog_digest': proposal['catalog']['catalog_digest'],
                       'runtime_sha256': proposal['runtime']['sha256'], 'reserved_jobs': 4,
                       'reserved_seconds': 60, 'qualification': False, 'source_access': 'none',
                       'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version}
    if any(manifest.get(k) != v for k, v in expected_fields.items()):
        raise ValueError('Registration differs from approved identities or caps')
    if (set(manifest['frozen_files']) != set(expected_files) | {'catalog.json'} or
            any(manifest['frozen_files'].get(k) != v for k, v in expected_files.items())):
        raise ValueError('Frozen manifest differs from approved inputs')
    if digest(read(ledger / 'frozen/catalog.json')) != proposal['catalog']['catalog_digest']:
        raise ValueError('Frozen catalog differs from approved catalog')
    if (ledger / 'run_started.json').exists():
        if read(ledger / 'run_started.json')['registration_sha256'] != sha(ledger / 'registration.json'):
            raise ValueError('Active registration changed')
    for name, expected in manifest['frozen_files'].items():
        if Path(name).name != name or sha(ledger / 'frozen' / name) != expected:
            raise ValueError('Frozen worker input changed')
    return manifest, authority


def seed_index(seed):
    alphabet = '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    if not isinstance(seed, str) or len(seed) != 8 or any(c not in alphabet for c in seed):
        raise ValueError('Malformed match seed')
    return sum(alphabet.index(c) * 35 ** i for i, c in enumerate(seed))


def summarize_events(job, rows, exit_status):
    """Trust only contiguous, completely emitted batches; never infer a killed tail."""
    start, end = job['start'], job['start'] + LIMIT
    cursor, matches, cpu, terminal = start, [], 0.0, None
    error = None
    try:
        for row in rows:
            if terminal:
                raise ValueError('Output after terminal event')
            if row.get('kind') == 'done':
                if row.get('next_index') != cursor or cursor != end:
                    raise ValueError('Premature completion')
                terminal = 'complete'; continue
            if row.get('kind') != 'batch' or row.get('start') != cursor:
                raise ValueError('Noncontiguous result prefix')
            requested = min(BATCH, end - cursor)
            if row.get('requested') != requested or requested <= 0:
                raise ValueError('Unexpected batch range')
            result = row['result']; tested = result.get('tested')
            if type(tested) is not int or not 0 <= tested <= requested:
                raise ValueError('Invalid completed count')
            if result.get('start') != cursor or result.get('limit') != requested:
                raise ValueError('Returned range mismatch')
            status = result.get('status'); found = result.get('matches')
            if not isinstance(found, list):
                raise ValueError('Invalid match list')
            next_cursor = cursor + tested
            if status == 'not_found' and tested != requested:
                raise ValueError('Incomplete not_found')
            if status == 'found' and (len(found) != MATCH_CAP or tested == 0):
                raise ValueError('Unexpected early match cap')
            if status not in {'not_found', 'found', 'unsupported'}:
                raise ValueError('Unknown search status')
            if status != 'unsupported' and result.get('next_index') != next_cursor:
                raise ValueError('Next cursor mismatch')
            if status == 'unsupported' and tested >= requested:
                raise ValueError('Unsupported must identify an unresolved index')
            seconds = row.get('os_clock_seconds')
            if type(seconds) not in (int, float) or not math.isfinite(seconds) or seconds < 0:
                raise ValueError('Invalid scan clock')
            batch_matches, previous = [], cursor - 1
            for match in found:
                canonical(match)
                index = seed_index(match.get('seed'))
                if not previous < index < next_cursor:
                    raise ValueError('Match outside ordered completed prefix')
                if match.get('target_planet') != job['target_planet'] or match.get('qualification') is not False:
                    raise ValueError('Match target or qualification mismatch')
                batch_matches.append({'index': index, 'recipe': match}); previous = index
            # Publish this prefix only after the entire result passed validation.
            cursor = next_cursor; matches.extend(batch_matches); cpu += seconds
            if status == 'unsupported':
                terminal = 'unsupported'
    except (ValueError, TypeError, KeyError, AttributeError) as exc:
        error = str(exc)
    status = 'error' if error else 'timeout' if exit_status == 'timeout' else terminal
    if status is None or (exit_status != 0 and status != 'timeout'):
        status = 'error'
    if status == 'complete' and cursor != end:
        status = 'error'
    return {'id': job['id'], 'policy': job['policy'], 'target_planet': job['target_planet'],
            'status': status, 'requested_indices': LIMIT, 'start': start, 'next_index': cursor,
            'completed_indices': cursor - start, 'unresolved_indices': end - cursor,
            'matches': matches, 'ordered_match_recipe_digest': digest(matches),
            'search_call_os_clock_seconds': cpu, 'os_clock_semantics': 'platform_clock_not_qualified_as_CPU_only',
            'error': error, 'exit_status': exit_status,
            'qualification': False}


def parse_output(path, job, exit_status):
    rows, parse_error = [], None
    with Path(path).open('r', encoding='utf-8') as handle:
        for line in handle:
            try:
                rows.append(json.loads(line, parse_constant=lambda value: (_ for _ in ()).throw(ValueError('Nonfinite output'))))
            except ValueError:
                parse_error = 'Truncated or malformed output; prior complete lines retained'; break
    result = summarize_events(job, rows, exit_status)
    if parse_error:
        result['output_error'] = parse_error
        if exit_status != 'timeout': result['status'] = 'error'
    return result


def compare_pair(left, right):
    if (left['start'], left['target_planet']) != (right['start'], right['target_planet']):
        raise ValueError('Comparison ranges differ')
    end = min(left['next_index'], right['next_index'])
    prefixes = [[m for m in r['matches'] if m['index'] < end] for r in (left, right)]
    full = all(r['status'] == 'complete' and r['completed_indices'] == LIMIT for r in (left, right))
    same = digest(prefixes[0]) == digest(prefixes[1])
    baseline_wall, candidate_wall = left.get('wall_seconds'), right.get('wall_seconds')
    ratio = (baseline_wall / candidate_wall if full and same and
             isinstance(baseline_wall, (int, float)) and isinstance(candidate_wall, (int, float)) and
             baseline_wall >= 0 and candidate_wall > 0 else None)
    return {'target_planet': left['target_planet'], 'common_completed_indices': end - left['start'],
            'common_prefix_match_recipes_equal': same, 'full_work_comparable': full and same,
            'paired_match_digests': [digest(p) for p in prefixes],
            'baseline_wall_seconds': baseline_wall, 'candidate_wall_seconds': candidate_wall,
            'observed_full_work_baseline_over_candidate_wall_ratio': ratio,
            'timing_inference': 'single serial observations only; no timing confidence interval',
            'survival_or_win_inference': False}


def execute_registered_job(ledger, job, outer_deadline, expiry):
    verify_registration(ledger)
    registration = read(ledger / (job['id'] + '_registration.json'))
    expected = {'batch_registration_sha256': sha(ledger / 'registration.json'),
                'job': job, 'indices': LIMIT, 'wall_cap_seconds': WORKER_SECONDS}
    if registration != expected: raise ValueError('Job registration changed')
    began = time.perf_counter()
    if min(outer_deadline - began, expiry - time.time()) < WORKER_SECONDS:
        return {'id': job['id'], 'status': 'not_started', 'consumed': False,
                'reason': 'verification_left_insufficient_full_cap'}
    deadline = min(began + WORKER_SECONDS, outer_deadline, began + expiry - time.time())
    create_json(ledger / (job['id'] + '_started.json'),
                {'job': job, 'one_use': True, 'deadline_perf_counter': deadline})
    command = [sys.executable, '-u', str(ledger / 'frozen/fixed_search_comparison.py'),
               'worker', '--ledger', str(ledger), '--job', job['id']]
    with (ledger / (job['id'] + '.jsonl')).open('x', encoding='utf-8') as out, (ledger / (job['id'] + '.stderr')).open('x', encoding='utf-8') as err:
        try:
            process = subprocess.Popen(command, stdout=out, stderr=err,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            try:
                code = process.wait(timeout=max(0, deadline - time.perf_counter()))
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(); code = 'timeout'
            except BaseException:
                process.kill(); process.wait(); raise
        except OSError as exc:
            code = 'launch_error'; err.write(str(exc))
    result = parse_output(ledger / (job['id'] + '.jsonl'), job, code)
    elapsed = time.perf_counter() - began
    result.update({'wall_seconds': elapsed, 'worker_deadline_overshoot_seconds': max(0, elapsed - WORKER_SECONDS),
                   'consumed': True, 'stdout_sha256': sha(ledger / (job['id'] + '.jsonl')),
                   'stderr_sha256': sha(ledger / (job['id'] + '.stderr'))})
    try:
        verify_registration(ledger)
    except Exception as exc:
        # A failed post-worker check must retain the actual cost and all output
        # hashes already measured, including a timeout/cleanup overshoot.
        result['status'] = 'error'
        result['provenance_error'] = type(exc).__name__ + ': ' + str(exc)
    return result


def run(ledger):
    ledger = Path(ledger).resolve(); manifest, authority = verify_registration(ledger)
    started = time.perf_counter(); expiry = utc_timestamp(authority['expires_at_utc'])
    outer_deadline = started + TOTAL_SECONDS
    create_json(ledger / 'run_started.json', {'utc': datetime.now(timezone.utc).isoformat(),
                                             'coordinator_pid': os.getpid(), 'deadline_perf_counter': outer_deadline,
                                             'registration_sha256': sha(ledger / 'registration.json')})
    results = []; stopped = False
    for job in JOBS:
        remaining = min(outer_deadline - time.perf_counter(), expiry - time.time())
        if stopped or remaining < WORKER_SECONDS:
            result = {'id': job['id'], 'status': 'not_started', 'reserved_seconds': 15,
                      'consumed': False, 'reason': 'closed_after_failure_or_insufficient_full_cap'}
            stopped = True
        else:
            try:
                result = execute_registered_job(ledger, job, outer_deadline, expiry)
            except BaseException as exc:
                used = (ledger / (job['id'] + '_started.json')).exists()
                result = {'id': job['id'], 'status': 'error' if used else 'not_started',
                          'consumed': used, 'reason': type(exc).__name__ + ': ' + str(exc)}
                output = ledger / (job['id'] + '.jsonl')
                if output.exists():
                    try:
                        result['preserved_prefix'] = parse_output(output, job, 'error')
                        result['stdout_sha256'] = sha(output)
                    except Exception as parse_exc: result['prefix_parse_error'] = str(parse_exc)
                stopped = True
            if result['status'] in {'error', 'unsupported', 'not_started'}: stopped = True
            if result.get('worker_deadline_overshoot_seconds', 0) > 0: stopped = True
        create_json(ledger / (job['id'] + '_result.json'), result); results.append(result)
    pairs = []
    for indices in [(0, 1), (3, 2)]:
        pair = [results[i] for i in indices]
        if all('next_index' in r for r in pair): pairs.append(compare_pair(*pair))
    report = {'status': 'closed', 'registered_jobs': 4, 'reserved_seconds': 60,
              'consumed_jobs': sum(r['consumed'] for r in results), 'results': results, 'pairs': pairs,
              'outer_wall_seconds': time.perf_counter() - started,
              'outer_deadline_overshoot_seconds': max(0, time.perf_counter() - outer_deadline),
              'unused_capacity_closed': True,
              'qualification': False, 'automatic_replacements': 0, 'source_access': 'none',
              'python_executable': str(Path(sys.executable).resolve()), 'python_version': sys.version,
              'runtime_sha256': manifest.get('runtime_sha256'), 'policies': manifest.get('policies')}
    create_json(ledger / 'report.json', report)
    return report


def lua_value(value):
    if value is None: return b'nil'
    if isinstance(value, bool): return b'true' if value else b'false'
    if isinstance(value, (int, float)):
        if not math.isfinite(value): raise ValueError('Nonfinite Lua input')
        return str(value).encode()
    if isinstance(value, str):
        # Lua decimal byte escapes prevent injection, including brackets/newlines.
        return b'"' + b''.join(('\\%03d' % b).encode() for b in value.encode('utf-8')) + b'"'
    if isinstance(value, list): return b'{' + b','.join(map(lua_value, value)) + b'}'
    if isinstance(value, dict): return b'{' + b','.join(b'[' + lua_value(k) + b']=' + lua_value(v) for k, v in value.items()) + b'}'
    raise TypeError('Unsupported Lua input')


def worker(ledger, job_id):
    ledger = Path(ledger).resolve(); manifest, _ = verify_registration(ledger)
    job = next((j for j in JOBS if j['id'] == job_id), None)
    if job is None or not (ledger / 'run_started.json').exists() or not (ledger / (job_id + '_started.json')).exists():
        raise ValueError('Coordinator must consume registered job before worker')
    coordinator = read(ledger / 'run_started.json'); consumed = read(ledger / (job_id + '_started.json'))
    if ((ledger / 'report.json').exists() or coordinator['coordinator_pid'] != os.getppid() or
            time.perf_counter() >= min(coordinator['deadline_perf_counter'], consumed['deadline_perf_counter'])):
        raise ValueError('Worker requires its active bounded parent coordinator')
    create_json(ledger / (job_id + '_worker_used.json'), {'one_use': True})
    frozen = ledger / 'frozen'
    if sha(Path(__file__)) != manifest['frozen_files']['fixed_search_comparison.py']:
        raise ValueError('Worker code differs from registration')
    source = (b'SEARCH_MODEL=assert(loadstring(' + lua_value((frozen / (job['policy'] + '.lua')).read_text(encoding='utf-8')) + b'))()\n'
              + b'SEARCH_CATALOG=' + lua_value(read(frozen / 'catalog.json')) + b'\n'
              + b'SEARCH_JOB=' + lua_value({**job, 'limit': LIMIT, 'batch_limit': BATCH, 'match_cap': MATCH_CAP}) + b'\n'
              + (frozen / 'fixed_search_comparison.lua').read_bytes())
    if time.perf_counter() >= min(coordinator['deadline_perf_counter'], consumed['deadline_perf_counter']):
        raise ValueError('Worker setup exhausted its original wall deadline')
    library = ctypes.CDLL(str(frozen / 'lua51.dll'))
    library.luaL_newstate.restype = ctypes.c_void_p
    library.luaL_openlibs.argtypes = [ctypes.c_void_p]
    library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    library.lua_tolstring.restype = ctypes.c_void_p
    library.lua_close.argtypes = [ctypes.c_void_p]
    state = library.luaL_newstate()
    if not state: raise RuntimeError('Could not allocate isolated Lua state')
    try:
        library.luaL_openlibs(state)
        status = library.luaL_loadbuffer(state, source, len(source), b'@fixed_search_comparison')
        if not status: status = library.lua_pcall(state, 0, 0, 0)
        if status:
            size = ctypes.c_size_t(); ptr = library.lua_tolstring(state, -1, ctypes.byref(size))
            raise RuntimeError(ctypes.string_at(ptr, size.value).decode('utf-8', 'replace') if ptr else 'Lua failure')
    finally: library.lua_close(state)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['register', 'run', 'worker'])
    parser.add_argument('--authority', type=Path); parser.add_argument('--proposal', type=Path)
    parser.add_argument('--ledger', type=Path); parser.add_argument('--job', choices=[j['id'] for j in JOBS])
    args = parser.parse_args()
    if args.mode == 'register': print(json.dumps(register(args.authority, args.proposal)))
    elif args.mode == 'run': print(json.dumps(run(args.ledger)))
    else: worker(args.ledger, args.job)


if __name__ == '__main__': main()
