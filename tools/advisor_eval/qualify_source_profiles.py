#!/usr/bin/env python3
"""Qualify declared source flag populations, without qualifying episode outcomes."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import zipfile

import engine_probe
import paired_policy_audit as paired


def checked_trace(trace, command, registration, name, exit_code):
    rows, errors = paired.parse_trace(trace)
    profiles = [r for r in rows if r.get('type') == 'engine_probe_profile']
    origins = [r for r in rows if r.get('type') == 'engine_probe_provenance']
    expected = {k: registration[k] for k in ('rules_digest', 'runtime_digest', 'adapter_digest')}
    outcome = 'passed' if exit_code == 0 else 'timeout' if exit_code == 'timeout' else 'failed'
    if (errors or len(origins) != 1 or any(origins[0].get(k) != v for k, v in expected.items())
            or origins[0].get('profile_spec') != engine_probe.profile_spec(name)
            or any(r.get('type', '').startswith('engine_episode_') for r in rows)):
        outcome = 'invalid_provenance_or_scope'
    return {'outcome': outcome, 'profile': profiles[0] if len(profiles) == 1 else None, 'parse_errors': errors}


def audit(directory):
    directory = Path(directory).resolve()
    registration = json.loads((directory / 'registration.json').read_text())
    unsigned = dict(registration);claimed = unsigned.pop('registration_digest', None)
    if paired.digest(unsigned) != claimed:
        raise ValueError('Source profile registration changed')
    if any(paired.file_digest(directory / 'adapter' / n) != h for n, h in registration['adapter_files'].items()):
        raise ValueError('Frozen profile adapter changed')
    flags = json.loads((directory / 'source_default_jokers.json').read_text())
    if paired.digest(flags) != registration['source_default_jokers_digest']:
        raise ValueError('Recorded original source flags changed')
    records = {}
    for name in engine_probe.PROFILE_NAMES:
        record = json.loads((directory / (name + '_record.json')).read_text())
        trace = directory / (name + '.log')
        command = [sys.executable, '-u', str(directory / 'adapter' / 'engine_probe.py'), '--install', registration['install'],
                   '--unlock-profile', name, '--profile-only']
        if (record['command'][1:] != command[1:] or Path(record['trace']).resolve() != trace
                or record['trace_digest'] != paired.file_digest(trace)):
            raise ValueError('Recorded profile trace or command changed')
        records[name] = {**record, **checked_trace(trace, command, registration, name, record['exit_code'])}
    return {**assess(records, flags), 'registration_digest': claimed, 'records': records}


def assess(records, source_jokers):
    errors = []
    inventories = {}
    for name in engine_probe.PROFILE_NAMES:
        record = records.get(name) or {}
        profile = record.get('profile')
        if record.get('outcome') != 'passed' or not profile:
            errors.append(name + ': missing, failed or timed out')
            continue
        spec = engine_probe.profile_spec(name)
        if (profile.get('profile_spec') != spec or profile.get('profile_spec_digest') != engine_probe.digest(spec)
                or not profile.get('emitted_before_episode') or not profile.get('declared_scope_verified')):
            errors.append(name + ': inconsistent declaration')
            continue
        inventory = profile.get('inventory') or []
        text = '\n'.join(':'.join(row[k] for k in ('scope', 'key', 'unlocked', 'discovered')) for row in inventory).encode()
        try:
            if engine_probe.profile_record(name, text) != profile:
                raise ValueError('inventory or fingerprint changed')
        except ValueError as error:
            errors.append(name + ': ' + str(error));continue
        inventories[name] = {(r['scope'], r['key']): r for r in inventory}
    defaults = inventories.get(engine_probe.PROFILE_NAMES[0], {})
    full = inventories.get(engine_probe.PROFILE_NAMES[1], {})
    observed = {key: row['unlocked'] == 'true' for (scope, key), row in defaults.items()
                if scope == 'P_CENTERS' and key.startswith('j_')}
    if observed != source_jokers:
        errors.append('Default Joker flags differ from original game.lua prototypes')
    if not defaults or defaults.keys() != full.keys():
        errors.append('Declared populations do not preserve exactly the same source prototype identities')
    return {'declared_profile_qualified': not errors, 'errors': errors,
            'source_default_jokers': len(source_jokers), 'source_default_unlocked': sum(source_jokers.values()),
            'all_unlocked_jokers': sum(scope == 'P_CENTERS' and key.startswith('j_') for scope, key in full),
            'episode_adapter_qualified': False, 'user_profile_qualified': False, 'qualified_win_rate': None}


def run(args):
    output = args.output.resolve();output.mkdir(parents=True, exist_ok=False)
    adapter = output / 'adapter';adapter.mkdir()
    hashes = {name: paired.file_digest(paired.HERE / name) for name in paired.ADAPTER_FILES}
    for name in hashes:
        shutil.copyfile(paired.HERE / name, adapter / name)
    if any(paired.file_digest(adapter / n) != h or paired.file_digest(paired.HERE / n) != h for n, h in hashes.items()):
        raise ValueError('Adapter changed while freezing')
    with zipfile.ZipFile(args.install / 'Balatro.exe') as archive:
        game = archive.read('game.lua')
    prototypes = [(m[1], m[2]) for m in re.finditer(r'^\s+(j_\w+)\s*=\s*(\{.*\}),?\s*$', game.decode(), re.M)
                  if "set = 'Joker'" in m[2] or 'set = "Joker"' in m[2]]
    if len(prototypes) != 150:
        raise ValueError('Original prototype layout changed; source review required')
    flags = {key: re.search(r'\bunlocked\s*=\s*(true|false)', value)[1] == 'true' for key, value in prototypes}
    registration = {'schema': 1, 'scope': 'two declared source flag populations, no episode actions',
                    'adapter_files': hashes, 'adapter_digest': paired.digest(hashes),
                    'rules_digest': paired.file_digest(args.install / 'Balatro.exe'),
                    'runtime_digest': paired.file_digest(args.install / 'lua51.dll'),
                    'game_source_digest': hashlib.sha256(game).hexdigest(), 'workflow_digest': paired.file_digest(__file__),
                    'source_default_jokers_digest': paired.digest(flags), 'install': str(args.install.resolve()),
                    'profiles': [engine_probe.profile_spec(n) for n in engine_probe.PROFILE_NAMES],
                    'timeout_seconds_per_profile': 15, 'total_requested_cap_seconds': 30}
    registration['registration_digest'] = paired.digest(registration)
    paired.write_json(output / 'registration.json', registration)
    paired.write_json(output / 'source_default_jokers.json', flags)
    records = {}
    for name in engine_probe.PROFILE_NAMES:
        command = [sys.executable, '-u', str(adapter / 'engine_probe.py'), '--install', str(args.install.resolve()),
                   '--unlock-profile', name, '--profile-only']
        trace = output / (name + '.log');started = time.perf_counter()
        with trace.open('x', encoding='utf-8') as handle:
            try:
                result = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT, timeout=15,
                                        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                outcome, code = ('passed' if result.returncode == 0 else 'failed'), result.returncode
            except subprocess.TimeoutExpired:
                outcome, code = 'timeout', 'timeout'
            except OSError as error:
                handle.write(str(error));outcome, code = 'launch_error', 'launch_error'
        records[name] = {'exit_code': code, 'command': command, 'trace': str(trace),
                         'trace_digest': paired.file_digest(trace), 'elapsed_seconds': time.perf_counter() - started,
                         **checked_trace(trace, command, registration, name, code)}
        paired.write_json(output / (name + '_record.json'), records[name])
    result = {**assess(records, flags), 'registration_digest': registration['registration_digest'], 'records': records,
              'limitations': ['Populations are explicitly named source-defined scenarios, never an inferred user save',
                 'Challenge bans, rarity, dependency and in-run pool gates remain original source logic',
                 'Profile qualification alone does not qualify phase mechanics, terminal parity or a measured win rate']}
    if any(paired.file_digest(adapter / n) != h for n, h in hashes.items()):
        result['errors'].append('Frozen adapter changed');result['declared_profile_qualified'] = False
    paired.write_json(output / 'report.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--audit', type=Path)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    try:
        if not args.audit and not args.output:
            raise ValueError('Require --output or --audit')
        report = audit(args.audit) if args.audit else run(args)
    except (ValueError, OSError, KeyError) as error:
        parser.error(str(error))
    print(json.dumps({key: report[key] for key in ('declared_profile_qualified', 'source_default_jokers',
                    'source_default_unlocked', 'all_unlocked_jokers', 'episode_adapter_qualified', 'errors')}, indent=2))
    return 0 if report['declared_profile_qualified'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
