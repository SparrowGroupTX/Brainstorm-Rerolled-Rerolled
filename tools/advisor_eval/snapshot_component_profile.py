"""Register one detached development decision for bounded component profiling.

Registration never executes a decision. A separate one-use execution runs only
frozen Advisor modules in an isolated Lua DLL, with the original default options.
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

import engine_probe
import outcome_validation as outcome
import paired_policy_audit as paired

HERE = Path(__file__).resolve().parent
ADAPTER_FILES = ('snapshot_component_profile.py', 'snapshot_component_profile.lua',
                 'benchmark.py', 'engine_probe.py', 'opening_support.py',
                 'outcome_validation.py', 'paired_policy_audit.py', 'development_report.py')
SETUP_BOUNDARY = b'local function json(value)'


def module_setup(source):
    """Use the frozen source adapter's wiring, without entering its dispatcher."""
    if source.count(SETUP_BOUNDARY) != 1:
        raise ValueError('Unknown source adapter module-setup boundary')
    prefix = source.split(SETUP_BOUNDARY)[0]
    if not prefix.startswith(b'-- Experimental dispatcher') or b'local modules=' not in prefix:
        raise ValueError('Unsupported source adapter module setup')
    if b'local function state_fingerprint' in prefix or b'for step=1,500' in prefix:
        raise ValueError('Source dispatcher entered detached module setup')
    return prefix


def source_input(directory, trace, role, step):
    directory, trace = Path(directory).resolve(), Path(trace).resolve()
    if role not in paired.ROLES or type(step) is not int or not 1 <= step <= 500:
        raise ValueError('Require registered role and decision step 1..500')
    registration, manifest = outcome.verify(directory)
    # Locate the requested file from manifest identities before opening it. This
    # path never reads episodes.jsonl or any other request's action/outcome data.
    candidates = [(i, request) for i, request in enumerate(manifest['requests'])
                  if trace == directory / f'{i:03d}_{role}.log']
    if len(candidates) != 1 or candidates[0][1].get('split') != 'development':
        raise ValueError('Only the explicit registered development trace is admitted; holdouts are excluded')
    index, request = candidates[0]
    before = paired.file_digest(trace)
    rows, errors = paired.parse_trace(trace)
    if errors:
        raise ValueError('Malformed source trace; preserve it without detached profiling')
    origins = [row for row in rows if row.get('type') == 'engine_probe_provenance']
    if len(origins) != 1:
        raise ValueError('Require exactly one source provenance record')
    origin = origins[0]
    expected = {key: manifest[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest',
                                              'start_distribution', 'profile_spec', 'profile_spec_digest')}
    expected.update(manifest['policies'][role])
    expected.update({key: request[key] for key in ('challenge', 'seed')})
    expected['opening_policy_loaded'] = False
    if any(origin.get(key) != value for key, value in expected.items()):
        raise ValueError('Source trace differs from frozen policy/adapter/profile provenance')
    if origin.get('counterfactual') or origin.get('followed_advice') is False:
        raise ValueError('Overridden or counterfactual source traces are excluded')
    profile_digest = outcome.applied_profile(rows, manifest)
    selected = [row for row in rows if row.get('type') == 'engine_episode_decision_started' and row.get('step') == step]
    if len(selected) != 1 or not isinstance(selected[0].get('snapshot'), dict):
        raise ValueError('Require one snapshot-bearing decision_started record')
    selected = selected[0]
    if (selected.get('fingerprint_schema') != 'source_decision_v1' or
            not isinstance(selected.get('state_fingerprint'), str) or len(selected['state_fingerprint']) != 64 or
            selected.get('phase') != selected['snapshot'].get('phase')):
        raise ValueError('Missing source decision fingerprint or inconsistent snapshot phase')
    actions = [row for row in rows if row.get('type') == 'engine_episode_action' and row.get('step') == step]
    profiles = [row for row in rows if row.get('type') == 'engine_episode_profile' and row.get('step') == step]
    if len(actions) > 1 or len(profiles) > 1 or profiles and profiles[0].get('advisor_skipped') is True:
        raise ValueError('Duplicate or skipped source decision records')
    if actions and (actions[0].get('state_fingerprint') != selected['state_fingerprint'] or
                    actions[0].get('phase') != selected['phase']):
        raise ValueError('Selected source action does not match its started decision')
    if paired.file_digest(trace) != before:
        raise ValueError('Source trace changed while reading; wait for its worker to finish')
    return registration, manifest, {'pair_index': index, 'role': role, **request,
        'step': step, 'source_trace_digest': before, 'source_origin': origin,
        'actual_profile_digest': profile_digest, 'decision_started': selected,
        'source_action': actions[0].get('action') if actions else None,
        'source_profile': profiles[0] if profiles else None}


def register(directory, trace, role, step, output, timeout=15, candidate_root=None):
    if type(timeout) not in (int, float) or not math.isfinite(timeout) or not 0 < timeout <= 15:
        raise ValueError('One worker must have a finite hard timeout in (0, 15] seconds')
    directory, output = Path(directory).resolve(), Path(output).resolve()
    registration, source_manifest, selected = source_input(directory, trace, role, step)
    runtime = Path(source_manifest['install']) / 'lua51.dll'
    if paired.file_digest(runtime) != source_manifest['runtime_digest']:
        raise ValueError('Source Lua runtime changed')
    module_setup((directory / 'adapter/engine_run.lua').read_bytes())
    output.mkdir(parents=True, exist_ok=False)
    source_policy = paired.freeze_product(directory / role, output / 'source_policy')
    if source_policy != source_manifest['policies'][role]:
        raise ValueError('Frozen source policy differs from selected role')
    policy = paired.freeze_product(Path(candidate_root).resolve() if candidate_root else directory / role, output / 'policy')
    (output / 'source_adapter').mkdir()
    for name, expected in source_manifest['adapter_files'].items():
        shutil.copyfile(directory / 'adapter' / name, output / 'source_adapter' / name)
        if paired.file_digest(output / 'source_adapter' / name) != expected:
            raise ValueError('Source adapter changed during copy')
    shutil.copyfile(trace, output / 'source.log')
    if paired.file_digest(output / 'source.log') != selected['source_trace_digest']:
        raise ValueError('Source trace changed during freeze')
    paired.write_json(output / 'input.json', selected)
    paired.write_json(output / 'source_manifest.json', source_manifest)
    paired.write_json(output / 'source_registration.json', registration)
    (output / 'adapter').mkdir()
    adapters = {name: paired.file_digest(HERE / name) for name in ADAPTER_FILES}
    for name, expected in adapters.items():
        shutil.copyfile(HERE / name, output / 'adapter' / name)
        if paired.file_digest(output / 'adapter' / name) != expected or paired.file_digest(HERE / name) != expected:
            raise ValueError('Profiler changed during freeze')
    manifest = {'schema': 1, 'qualification': False, 'scope': 'detached_development_decision_components',
        'created_utc': datetime.now(timezone.utc).isoformat(), **policy,
        'source_policy_files': source_policy['policy_files'], 'source_policy_digest': source_policy['policy_digest'],
        'same_product': policy['policy_digest'] == source_policy['policy_digest'],
        'adapter_files': adapters, 'adapter_digest': paired.digest(adapters),
        'source_adapter_files': source_manifest['adapter_files'], 'source_adapter_digest': source_manifest['adapter_digest'],
        'source_registration_digest': registration['registration_digest'],
        'source_manifest_digest': source_manifest['manifest_digest'],
        'frozen_input_files': {name: paired.file_digest(output / name) for name in
                               ('source.log', 'input.json', 'source_manifest.json', 'source_registration.json')},
        'runtime': str(runtime.resolve()), 'runtime_digest': source_manifest['runtime_digest'],
        'timeout_seconds': timeout, 'requested_workers': 1, 'decision_options': 'product_defaults_no_overrides',
        'limitations': ['One detached source-captured decision; no source prefix or outcome is replayed.',
            'Fresh module state may differ from a continuing episode; source action and score-count parity are checked when available.',
            'Per-call instrumentation changes absolute latency; inclusive component times overlap.',
            'Original source fingerprint also includes RNG/progression unavailable in this detached snapshot; it remains a reference.',
            'The source unlock profile is synthetic; no win-rate, retry-time or general speedup inference.']}
    manifest['manifest_digest'] = paired.digest(manifest)
    paired.write_json(output / 'manifest.json', manifest)
    verify(output)
    return manifest


def verify(output):
    output = Path(output).resolve()
    manifest = json.loads((output / 'manifest.json').read_text(encoding='utf-8'))
    unsigned = dict(manifest); claimed = unsigned.pop('manifest_digest', None)
    if paired.digest(unsigned) != claimed or paired.policy_hashes(output / 'policy') != manifest['policy_files']:
        raise ValueError('Frozen profiling manifest or product changed')
    if paired.policy_hashes(output / 'source_policy') != manifest['source_policy_files']:
        raise ValueError('Frozen source policy changed')
    for folder, hashes in (('adapter', manifest['adapter_files']), ('source_adapter', manifest['source_adapter_files'])):
        if any(paired.file_digest(output / folder / name) != expected for name, expected in hashes.items()):
            raise ValueError('Frozen ' + folder + ' changed')
    if any(paired.file_digest(output / name) != expected for name, expected in manifest['frozen_input_files'].items()):
        raise ValueError('Frozen source evidence or snapshot changed')
    if paired.file_digest(manifest['runtime']) != manifest['runtime_digest']:
        raise ValueError('Lua runtime changed')
    timeout = manifest['timeout_seconds']
    if (manifest['requested_workers'] != 1 or manifest['decision_options'] != 'product_defaults_no_overrides' or
            type(timeout) not in (int, float) or not math.isfinite(timeout) or not 0 < timeout <= 15):
        raise ValueError('Unsupported profiling worker/options registration')
    return manifest


def worker_source(output):
    output = Path(output)
    selected = json.loads((output / 'input.json').read_text(encoding='utf-8'))
    chunks = [b'PROBE_MONOTONIC_SECONDS=os.clock', b'PROFILE_INPUT=' + engine_probe.lua_value(selected)]
    for path in sorted((output / 'policy/Brainstorm/Advisor').glob('*.lua')):
        name = b'probe_policy_' + path.stem.encode()
        chunks.append(b'package.preload[ ' + engine_probe.literal(name) + b' ]=assert(loadstring(' +
                      engine_probe.literal(path.read_bytes()) + b',' + engine_probe.literal(b'@policy/' + path.name.encode()) + b'))')
    chunks.append(b'package.preload.probe_engine_contract=assert(loadstring(' +
                  engine_probe.literal((output / 'source_adapter/engine_contract.lua').read_bytes()) + b'))')
    chunks.append(module_setup((output / 'source_adapter/engine_run.lua').read_bytes()))
    chunks.append((output / 'adapter/snapshot_component_profile.lua').read_bytes())
    return b'\n'.join(chunks)


def run_worker(output):
    output = Path(output).resolve(); manifest = verify(output)
    lease = json.loads((output / 'execution_started.json').read_text(encoding='utf-8'))
    if lease.get('manifest_digest') != manifest['manifest_digest']:
        raise ValueError('Worker requires its one-use registered execution lease')
    with (output / 'worker_started.json').open('x', encoding='utf-8') as handle:
        json.dump({'manifest_digest': manifest['manifest_digest'], 'started_utc': datetime.now(timezone.utc).isoformat()}, handle)
    library = ctypes.CDLL(manifest['runtime'])
    library.luaL_newstate.restype = ctypes.c_void_p
    library.luaL_openlibs.argtypes = [ctypes.c_void_p]
    library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    library.lua_tolstring.restype = ctypes.c_void_p
    library.lua_close.argtypes = [ctypes.c_void_p]
    source = worker_source(output)
    state = library.luaL_newstate()
    if not state:
        raise RuntimeError('Could not allocate isolated Lua state')
    try:
        library.luaL_openlibs(state)
        status = library.luaL_loadbuffer(state, source, len(source), b'@detached_component_profile.lua')
        if status == 0:
            status = library.lua_pcall(state, 0, 1, 0)
        length = ctypes.c_size_t(); pointer = library.lua_tolstring(state, -1, ctypes.byref(length))
        value = ctypes.string_at(pointer, length.value).decode('utf-8', 'replace') if pointer else ''
        if status != 0:
            raise RuntimeError(value)
        row = json.loads(value)
        for key in ('input_fingerprint', 'decision_fingerprint', 'action_fingerprint'):
            row[key] = hashlib.sha256(row[key].encode()).hexdigest()
        print(json.dumps(row, allow_nan=False), flush=True)
    finally:
        library.lua_close(state)


def execute(output):
    output = Path(output).resolve(); manifest = verify(output)
    with (output / 'execution_started.json').open('x', encoding='utf-8') as handle:
        json.dump({'manifest_digest': manifest['manifest_digest'], 'started_utc': datetime.now(timezone.utc).isoformat()}, handle)
    command = [sys.executable, '-u', str(output / 'adapter/snapshot_component_profile.py'), '--worker', str(output)]
    log = output / 'worker.log'; started = time.perf_counter()
    with log.open('x', encoding='utf-8') as handle:
        try:
            code = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT, timeout=manifest['timeout_seconds'],
                                  creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).returncode
        except subprocess.TimeoutExpired:
            code = 'timeout'
        except OSError as error:
            code = 'launch_error'; handle.write(str(error) + '\n')
    elapsed = time.perf_counter() - started
    rows, errors = paired.parse_trace(log)
    status = 'timeout' if code == 'timeout' else 'complete' if code == 0 and not errors and len(rows) == 1 else 'error'
    integrity_error = None
    try:
        verify(output)
    except (ValueError, OSError) as error:
        integrity_error = str(error); status = 'error'
    report = {'schema': 1, 'qualification': False, 'manifest_digest': manifest['manifest_digest'],
        'source_policy_digest': manifest['source_policy_digest'], 'policy_digest': manifest['policy_digest'],
        'same_product': manifest['same_product'],
        'status': status, 'exit_code': code, 'elapsed_seconds': elapsed, 'timeout_seconds': manifest['timeout_seconds'],
        'requested_workers': 1, 'command': command, 'log': str(log), 'log_digest': paired.file_digest(log),
        'rows': rows, 'parse_errors': errors, 'integrity_error': integrity_error,
        'source_parity': rows[0].get('source_parity') if status == 'complete' else None,
        'win_rate_evidence': False, 'general_speedup_established': False, 'limitations': manifest['limitations']}
    paired.write_json(output / 'report.json', report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--execute', type=Path); modes.add_argument('--worker', type=Path)
    modes.add_argument('--verify', type=Path)
    parser.add_argument('--source-directory', type=Path); parser.add_argument('--source-trace', type=Path)
    parser.add_argument('--role', choices=paired.ROLES); parser.add_argument('--step', type=int)
    parser.add_argument('--candidate-root', type=Path, help='Optional distinct frozen product for the same immutable source input')
    parser.add_argument('--output-dir', type=Path); parser.add_argument('--timeout', type=float, default=15)
    args = parser.parse_args()
    if args.worker:
        run_worker(args.worker); return
    if args.execute:
        report = execute(args.execute); print(json.dumps({key: report[key] for key in ('status', 'elapsed_seconds', 'source_parity')})); return
    if args.verify:
        print(json.dumps({'manifest_digest': verify(args.verify)['manifest_digest']})); return
    if not all((args.source_directory, args.source_trace, args.role, args.step, args.output_dir)):
        parser.error('Registration requires source-directory, source-trace, role, step and fresh output-dir')
    manifest = register(args.source_directory, args.source_trace, args.role, args.step, args.output_dir, args.timeout, args.candidate_root)
    print(json.dumps({'registered': True, 'executed': False, 'manifest_digest': manifest['manifest_digest']}))


if __name__ == '__main__':
    main()
