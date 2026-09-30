#!/usr/bin/env python3
"""Bounded frozen offline component timings; synthetic decisions, never win evidence."""
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

from benchmark import digest, file_digest, policy_hashes

HERE = Path(__file__).resolve().parent
WORKLOADS = ('shop_safe', 'shop_weak_full', 'nonclear')
ALL_WORKLOADS = WORKLOADS + ('shop_dagger', 'shop_marble', 'shop_dagger_marble', 'nonclear9', 'nonclear10', 'nonclear12')
MODES = ('plain', 'prepared')
ADAPTER = ('component_profile.py', 'component_profile.lua', 'benchmark.py')


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def freeze(source, output, runtime, repetitions, timeout, workloads=None):
    workloads = tuple(WORKLOADS if workloads is None else workloads)
    if type(repetitions) is not int or not 1 <= repetitions <= 5 or not 0 < timeout <= 30:
        raise ValueError('Require 1..5 repetitions and 0..30 seconds per workload/mode')
    if not 1 <= len(workloads) <= 4 or len(set(workloads)) != len(workloads) or any(w not in ALL_WORKLOADS for w in workloads):
        raise ValueError('Require 1..4 distinct registered workloads (eight workers maximum)')
    output = Path(output).resolve();output.mkdir(parents=True, exist_ok=False)
    source = Path(source).resolve();runtime = Path(runtime).resolve()
    hashes = policy_hashes(source)
    for relative in hashes:
        target = output / 'policy' / relative;target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / relative, target)
    if hashes != policy_hashes(source) or hashes != policy_hashes(output / 'policy'):
        raise ValueError('Product changed during freeze')
    (output / 'adapter').mkdir()
    adapter = {name: file_digest(HERE / name) for name in ADAPTER}
    for name in ADAPTER:
        shutil.copyfile(HERE / name, output / 'adapter' / name)
    if any(file_digest(output / 'adapter' / name) != value or file_digest(HERE / name) != value for name, value in adapter.items()):
        raise ValueError('Profiling adapter changed during freeze')
    manifest = {'schema': 1, 'qualification': False, 'scope': 'synthetic_offline_component_profile',
                'created_utc': datetime.now(timezone.utc).isoformat(), 'policy_files': hashes,
                'policy_digest': digest(hashes), 'adapter_files': adapter, 'adapter_digest': digest(adapter),
                'runtime': str(runtime), 'runtime_digest': file_digest(runtime), 'workloads': list(workloads),
                'modes': list(MODES), 'repetitions': repetitions, 'timeout_seconds': timeout,
                'total_worker_budget_seconds': len(workloads) * len(MODES) * timeout,
                'clock': 'instrumented Lua os.clock; parent elapsed uses time.perf_counter',
                'limitations': ['Synthetic inputs are not source episodes or win evidence.',
                    'Per-call profiling changes absolute latency; inclusive times overlap.',
                    'Only the existing classification-cache switch differs between paired modes.',
                    'Whole-row shop cache remains active in both modes; no cross-decision cache is introduced.']}
    manifest['manifest_digest'] = digest(manifest)
    write_json(output / 'manifest.json', manifest)
    return manifest


def verify(output):
    output = Path(output)
    manifest = json.loads((output / 'manifest.json').read_text(encoding='utf-8'))
    unsigned = dict(manifest);expected = unsigned.pop('manifest_digest', None)
    if digest(unsigned) != expected or policy_hashes(output / 'policy') != manifest['policy_files']:
        raise ValueError('Frozen manifest or product changed')
    if any(file_digest(output / 'adapter' / name) != value for name, value in manifest['adapter_files'].items()):
        raise ValueError('Frozen profiling adapter changed')
    if file_digest(manifest['runtime']) != manifest['runtime_digest']:
        raise ValueError('Lua runtime changed')
    return manifest


def lua_literal(value):
    data = value.encode('utf-8');separator = b'='
    while b']' + separator + b']' in data:
        separator += b'='
    return b'[' + separator + b'[' + data + b']' + separator + b']'


def run_worker(output, workload, mode):
    manifest = verify(output)
    if workload not in manifest['workloads'] or mode not in manifest['modes']:
        raise ValueError('Unregistered workload or cache mode')
    library = ctypes.CDLL(manifest['runtime'])
    library.luaL_newstate.restype = ctypes.c_void_p
    library.luaL_openlibs.argtypes = [ctypes.c_void_p]
    library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    library.lua_tolstring.restype = ctypes.c_void_p
    library.lua_close.argtypes = [ctypes.c_void_p]
    source = b'PROFILE_ROOT=' + lua_literal(str((output / 'policy').resolve()).replace('\\', '/'))
    source += b';PROFILE_WORKLOAD=' + lua_literal(workload) + b';PROFILE_MODE=' + lua_literal(mode)
    source += b';PROFILE_REPETITIONS=' + str(manifest['repetitions']).encode() + b'\n'
    source += (output / 'adapter' / 'component_profile.lua').read_bytes()
    state = library.luaL_newstate()
    if not state:
        raise RuntimeError('Could not allocate isolated Lua state')
    try:
        library.luaL_openlibs(state)
        status = library.luaL_loadbuffer(state, source, len(source), b'@frozen_component_profile.lua')
        if status == 0:
            status = library.lua_pcall(state, 0, 1, 0)
        length = ctypes.c_size_t();ptr = library.lua_tolstring(state, -1, ctypes.byref(length))
        text = ctypes.string_at(ptr, length.value).decode('utf-8', 'replace') if ptr else ''
        if status != 0:
            raise RuntimeError(text)
        rows = json.loads(text)
        for row in rows:
            for key in ('input_fingerprint', 'decision_fingerprint', 'action_fingerprint'):
                row[key] = hashlib.sha256(row[key].encode()).hexdigest()
            print(json.dumps(row, allow_nan=False), flush=True)
    finally:
        library.lua_close(state)


def percentiles(values):
    values = sorted(values)
    return {'count': len(values), 'median': values[(len(values)-1)//2] if values else None,
            'p95': values[max(0, math.ceil(len(values)*.95)-1)] if values else None}


def summarize(records, selected_workloads=None):
    selected_workloads = WORKLOADS if selected_workloads is None else selected_workloads
    workloads = []
    for workload in selected_workloads:
        pair = {r['mode']: r for r in records if r['workload'] == workload}
        complete = all(mode in pair and pair[mode]['status'] == 'complete' for mode in MODES)
        rows = {mode: pair.get(mode, {}).get('rows', []) for mode in MODES}
        fingerprints = {mode: {(r['input_fingerprint'], r['decision_fingerprint'], r['action_fingerprint'], r['evaluations'])
                               for r in rows[mode]} for mode in MODES}
        identical = complete and len(fingerprints['plain']) == 1 and fingerprints['plain'] == fingerprints['prepared']
        workloads.append({'workload': workload, 'complete': complete, 'exact_paired_result': identical,
                          'performance_comparison_eligible': identical,
                          'latencies': {mode: percentiles([r['elapsed_seconds'] for r in rows[mode]]) for mode in MODES},
                          'rows': rows})
    return {'qualification': False, 'scope': 'synthetic_offline_component_profile', 'workloads': workloads,
            'requested_workers': len(selected_workloads)*len(MODES), 'records': records,
            'win_rate_evidence': False, 'general_speedup_established': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy-root', type=Path)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--runtime', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll'))
    parser.add_argument('--repetitions', type=int, default=3)
    parser.add_argument('--timeout', type=float, default=20)
    parser.add_argument('--workloads', nargs='+', choices=ALL_WORKLOADS)
    parser.add_argument('--worker', choices=ALL_WORKLOADS)
    parser.add_argument('--mode', choices=MODES)
    args = parser.parse_args();output = args.output_dir.resolve()
    if args.worker:
        run_worker(output, args.worker, args.mode);return 0
    if not args.policy_root:
        parser.error('--policy-root is required for registration')
    manifest = freeze(args.policy_root, output, args.runtime, args.repetitions, args.timeout, args.workloads)
    records = []
    for index, workload in enumerate(manifest['workloads']):
        for mode in MODES[::1 if index % 2 == 0 else -1]:
            command = [sys.executable, '-u', str(output / 'adapter' / 'component_profile.py'),
                       '--output-dir', str(output), '--worker', workload, '--mode', mode]
            log = output / f'{workload}_{mode}.log';start = time.perf_counter();exit_code = None
            with log.open('x', encoding='utf-8') as stream:
                try:
                    exit_code = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                        timeout=manifest['timeout_seconds'], creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).returncode
                except subprocess.TimeoutExpired:
                    exit_code = 'timeout'
                except OSError as error:
                    exit_code = 'launch_error';stream.write(str(error))
            rows, errors = [], []
            for number, line in enumerate(log.read_text(encoding='utf-8').splitlines(), 1):
                if not line.startswith('{'):
                    errors.append({'line': number, 'text': line});continue
                try:
                    rows.append(json.loads(line))
                except ValueError:
                    errors.append({'line': number, 'text': line})
            status = 'timeout' if exit_code == 'timeout' else 'complete' if exit_code == 0 and not errors and len(rows) == args.repetitions else 'error'
            record = {'workload': workload, 'mode': mode, 'status': status, 'exit_code': exit_code, 'rows': rows,
                      'errors': errors, 'elapsed_seconds': time.perf_counter()-start, 'log': str(log),
                      'log_digest': file_digest(log), 'command': command}
            records.append(record);print(json.dumps({key: record[key] for key in ('workload','mode','status','elapsed_seconds')}), flush=True)
    verify(output)
    report = summarize(records, manifest['workloads']);write_json(output / 'report.json', report)
    return 0 if all(w['exact_paired_result'] for w in report['workloads']) else 1


if __name__ == '__main__':
    raise SystemExit(main())
