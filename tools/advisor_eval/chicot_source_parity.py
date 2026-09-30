"""Register one bounded original-source Chicot/Dagger callback fixture worker.

Registration reads the executable only as ZIP. Execution uses an isolated Lua
DLL with frozen product/source/helper bytes, never an episode or live game.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import zipfile

from discard_source_parity import function_source
from engine_probe import literal
import paired_policy_audit as paired

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCES = {
    'card.lua': ('function Card:calculate_joker(', 'function Card:set_debuff(',
                 'function Card:add_to_deck(', 'function Card:remove_from_deck(',
                 'function Card:start_dissolve(', 'function Card:is_suit(',
                 'function Card:is_face(', 'function Card:get_id('),
    'blind.lua': ('function Blind:set_blind(', 'function Blind:disable(', 'function Blind:debuff_card('),
    'functions/common_events.lua': ('function ease_discard(', 'function ease_hands_played(', 'function delay('),
}
WHOLE_SOURCES = ('engine/object.lua', 'engine/event.lua')
HELPERS = ('chicot_source_parity.py', 'chicot_source_parity.lua', 'discard_source_parity.py',
           'engine_probe.py', 'opening_support.py', 'paired_policy_audit.py', 'development_report.py', 'benchmark.py')
CASES = ('dagger_eats_chicot', 'retained_chicot', 'chicot_before_dagger', 'debuffed_dagger',
         'duplicate_chicot_wall', 'retained_chicot_water', 'retained_chicot_needle', 'duplicate_chicot_water')


def case_records(text):
    records = []
    for line in text.splitlines():
        if line.startswith('chicot case_result '):
            try:
                row = json.loads(line[len('chicot case_result '):])
                if not isinstance(row, dict) or row.get('case') not in CASES:
                    raise ValueError('Unknown case record')
                records.append(row)
            except (ValueError, TypeError) as error:
                records.append({'status': 'malformed', 'raw': line, 'reason': str(error)})
    return records


def generated_probe(output):
    output = Path(output).resolve()
    chunks = [(output / 'source' / name).read_bytes() for name in WHOLE_SOURCES]
    chunks.append(b'Card={};Blind={}')
    for name, signatures in SOURCES.items():
        source = (output / 'source' / name).read_text(encoding='utf-8')
        chunks.extend(function_source(source, signature).encode() for signature in signatures)
    chunks.append(b'PROBE_POLICY=' + literal(str(output / 'policy').replace('\\', '/').encode()))
    chunks.append((output / 'adapter/chicot_source_parity.lua').read_bytes())
    return b'\n'.join(chunks)


def register(policy_root, install, output):
    output, install = Path(output).resolve(), Path(install).resolve()
    output.mkdir(parents=True, exist_ok=False)
    policy = paired.freeze_product(policy_root, output / 'policy')
    source_hashes = {}
    rules_digest = paired.file_digest(install / 'Balatro.exe')
    with zipfile.ZipFile(install / 'Balatro.exe') as archive:
        for name in WHOLE_SOURCES + tuple(SOURCES):
            path = output / 'source' / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(archive.read(name)); source_hashes[name] = paired.file_digest(path)
    if paired.file_digest(install / 'Balatro.exe') != rules_digest:
        raise ValueError('Installed source changed during freeze; preserve incomplete output')
    (output / 'adapter').mkdir()
    helper_hashes = {name: paired.file_digest(HERE / name) for name in HELPERS}
    for name, expected in helper_hashes.items():
        shutil.copyfile(HERE / name, output / 'adapter' / name)
        if paired.file_digest(output / 'adapter' / name) != expected or paired.file_digest(HERE / name) != expected:
            raise ValueError('Fixture helper changed during freeze')
    runner = ROOT / 'tests/run_lua_tests.py'
    runner_digest = paired.file_digest(runner)
    shutil.copyfile(runner, output / 'run_lua_tests.py')
    if paired.file_digest(output / 'run_lua_tests.py') != runner_digest:
        raise ValueError('Lua fixture runner changed during freeze')
    (output / 'source_probe.lua').write_bytes(generated_probe(output))
    registration = {'schema': 1, 'qualification': False, 'scope': 'synthetic_original_source_chicot_startup_callbacks',
        'created_utc': datetime.now(timezone.utc).isoformat(), **policy,
        'rules_digest': rules_digest, 'source_files': source_hashes,
        'runtime': str(install / 'lua51.dll'), 'runtime_digest': paired.file_digest(install / 'lua51.dll'),
        'adapter_files': helper_hashes, 'adapter_digest': paired.digest(helper_hashes),
        'runner_digest': runner_digest, 'generated_probe_digest': paired.file_digest(output / 'source_probe.lua'),
        'cases': list(CASES), 'requested_workers': 1, 'per_worker_seconds': 10,
        'limitations': ['Original set_blind, Chicot/Dagger callbacks, passive/debuff/dissolve methods and EventManager execute unchanged.',
            'Visual/HUD/sound methods and final card-area removal are explicit fixture glue.',
            'Synthetic prepared Boss states and rows; no challenge attempt, source outcome, draw order or win-rate evidence.',
            'Only these listed combinations; no Manacle draw, Burglar/resource interaction or arbitrary passive-reactivation qualification.']}
    registration['registration_digest'] = paired.digest(registration)
    paired.write_json(output / 'registration.json', registration)
    verify(output)
    return registration


def verify(output):
    output = Path(output).resolve()
    registration = json.loads((output / 'registration.json').read_text(encoding='utf-8'))
    unsigned = dict(registration); claimed = unsigned.pop('registration_digest', None)
    if paired.digest(unsigned) != claimed or paired.policy_hashes(output / 'policy') != registration['policy_files']:
        raise ValueError('Frozen registration or policy changed')
    for directory, fields in (('source', 'source_files'), ('adapter', 'adapter_files')):
        if any(paired.file_digest(output / directory / name) != expected for name, expected in registration[fields].items()):
            raise ValueError('Frozen ' + directory + ' changed')
    for relative, key in (('run_lua_tests.py', 'runner_digest'), ('source_probe.lua', 'generated_probe_digest')):
        if paired.file_digest(output / relative) != registration[key]:
            raise ValueError('Frozen runner or generated probe changed')
    if paired.file_digest(registration['runtime']) != registration['runtime_digest']:
        raise ValueError('Lua runtime changed')
    if registration['requested_workers'] != 1 or registration['per_worker_seconds'] != 10 or registration['cases'] != list(CASES):
        raise ValueError('Unsupported source fixture worker budget or scope')
    return registration


def execute(output):
    output = Path(output).resolve(); registration = verify(output)
    with (output / 'execution_started.json').open('x', encoding='utf-8') as lease:
        json.dump({'registration_digest': registration['registration_digest'],
                   'started_utc': datetime.now(timezone.utc).isoformat()}, lease)
    command = [sys.executable, str(output / 'run_lua_tests.py'), '--lua-library',
               registration['runtime'], str(output / 'source_probe.lua')]
    log = output / 'output.log'; started = time.perf_counter()
    with log.open('x', encoding='utf-8') as handle:
        try:
            code = subprocess.run(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT,
                timeout=registration['per_worker_seconds'], creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).returncode
        except subprocess.TimeoutExpired:
            code = 'timeout'
        except OSError as error:
            code = 'launch_error'; handle.write(str(error) + '\n')
    elapsed = time.perf_counter() - started
    text = log.read_text(encoding='utf-8', errors='replace')
    records = case_records(text)
    match = re.search(r'chicot source parity: (\d+) cases, (\d+) comparisons', text)
    cases, comparisons = (map(int, match.groups()) if match else (0, 0))
    status = 'timeout' if code == 'timeout' else 'passed' if code == 0 and cases == len(CASES) else 'error'
    integrity_error = None
    try:
        verify(output)
    except (ValueError, OSError) as error:
        integrity_error = str(error); status = 'error'
    report = {'qualification': False, 'scope': registration['scope'],
        'registration_digest': registration['registration_digest'], 'status': status,
        'exit_code': code, 'cases': cases, 'comparisons': comparisons, 'wall_seconds': elapsed,
        'timeout_seconds': registration['per_worker_seconds'], 'requested_workers': 1,
        'command': command, 'log': str(log), 'log_digest': paired.file_digest(log),
        'case_records': records, 'missing_case_records': [name for name in CASES if not any(r.get('case') == name for r in records)],
        'integrity_error': integrity_error, 'limitations': registration['limitations']}
    paired.write_json(output / 'report.json', report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--execute', type=Path); modes.add_argument('--verify', type=Path)
    parser.add_argument('--policy-root', type=Path); parser.add_argument('--output', type=Path)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    if args.execute:
        report = execute(args.execute); print(json.dumps(report)); return 0 if report['status'] == 'passed' else 1
    if args.verify:
        print(json.dumps({'registration_digest': verify(args.verify)['registration_digest']})); return 0
    if not args.policy_root or not args.output: parser.error('Registration requires policy-root and fresh output')
    registration = register(args.policy_root, args.install, args.output)
    print(json.dumps({'registered': True, 'executed': False, 'registration_digest': registration['registration_digest']}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
