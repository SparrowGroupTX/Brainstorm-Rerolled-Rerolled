#!/usr/bin/env python3
"""Separate frozen ordinary-prefix / real native filtered-setup comparisons.

These different endpoints expose setup, actions and search cost only. They cannot
estimate win rates, seed prevalence, or human completion time. No seed is invented
after search; native misses retain their cost and cannot become playable episodes.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import shutil
import sys

from benchmark import CHALLENGES, ORDINARY_START, digest, file_digest, policy_hashes
from development_report import parse_trace
from paired_policy_audit import ADAPTER_FILES, HERE, collect, freeze_product, write_json


def register_native_policy(root, policy):
    """Bind the selected frozen loader and binary before signing a cohort."""
    from opening_support import native_library_path
    root = Path(root)
    files = policy['policy_files']
    if file_digest(root / 'Brainstorm/Core/Brainstorm.lua') != files.get('Brainstorm/Core/Brainstorm.lua'):
        raise ValueError('Frozen native loader differs from the registered policy')
    path = native_library_path(root)
    native_hash = file_digest(path)
    if files.get('Brainstorm/' + path.name) != native_hash:
        raise ValueError('Selected native binary differs from the registered policy')
    return {**policy, 'native_file': path.name, 'native_sha256': native_hash}


def verify_native_provenance(opening, policy):
    """A trace cannot choose its own binary; historical cohorts remain on 2.16."""
    files = policy['policy_files']
    if 'native_file' in policy or 'native_sha256' in policy:
        name, expected_hash = policy.get('native_file'), policy.get('native_sha256')
        if (not isinstance(expected_hash, str) or not re.fullmatch('[a-f0-9]{64}', expected_hash) or
                name not in ('Immolate-v2.16.dll', 'Immolate-advisor-' + expected_hash + '.dll') or
                'Brainstorm/Core/Brainstorm.lua' not in files or files.get('Brainstorm/' + name) != expected_hash):
            raise ValueError('Registered native selection does not match the policy manifest')
        if opening.get('native_file') != name:
            raise ValueError('Native provenance mismatch: native_file')
    else:
        name = 'Immolate-v2.16.dll'
        expected_hash = files.get('Brainstorm/' + name)
        if expected_hash is None or opening.get('native_file', name) != name:
            raise ValueError('Historical native provenance requires Immolate-v2.16.dll')
    if opening.get('native_sha256') != expected_hash:
        raise ValueError('Native provenance mismatch: native_sha256')


def inspect_record(record, manifest, role, request):
    if file_digest(Path(record['trace'])) != record.get('trace_digest'):
        raise ValueError('Comparison trace digest changed')
    rows, errors = parse_trace(record['trace'])
    if errors: raise ValueError('Malformed filtered comparison trace')
    provenance = next((r for r in rows if r['type'] == 'engine_probe_provenance'), {})
    expected = {'challenge': request['challenge'], 'seed': request['seed'],
                'policy_digest': manifest['policy']['policy_digest'],
                'policy_files': manifest['policy']['policy_files'],
                **{k: manifest[k] for k in ('rules_digest', 'runtime_digest', 'adapter_digest')}}
    for key, value in expected.items():
        if provenance.get(key) != value: raise ValueError('Comparison provenance mismatch: ' + key)
    out = {'role': role, 'challenge': request['challenge'], 'registered_search_or_run_seed': request['seed'],
           'outcome': record['outcome'], 'reason': record['reason'], 'elapsed_seconds': record['elapsed_seconds'],
           'trace': record['trace'], 'trace_digest': record['trace_digest'], 'setup_complete': False}
    actions = [r for r in rows if r['type'] == 'engine_episode_action']
    out['actions'] = [{'kind': r['action']['kind'], 'card_key': r.get('card_key')} for r in actions]
    out['pair_changes'] = [r for r in rows if r['type'] == 'engine_opening_pair_changed']
    if role == 'ordinary':
        if provenance.get('start_distribution') != ORDINARY_START or provenance.get('opening_policy_loaded'):
            raise ValueError('Ordinary prefix contains a filtered policy')
        return out
    if provenance.get('start_distribution') != {'kind': 'filtered_two_soul_native_v1', 'targets': manifest['targets']}:
        raise ValueError('Filtered distribution mismatch')
    opening = provenance.get('opening', {});native = opening.get('result', {})
    if (opening.get('search_start') != request['seed'] or opening.get('search_limit') != manifest['search_limit'] or
            opening.get('threads') != 1 or opening.get('targets') != manifest['targets']):
        raise ValueError('Native search provenance mismatch')
    verify_native_provenance(opening, manifest['policy'])
    out.update(search_seconds=opening['search_seconds'], native_status=native.get('status'),
               next_seed=native.get('next_seed'), run_seed=provenance.get('run_seed'), expected_pair=native.get('legendary_jokers'))
    if native.get('status') != 'found':
        if actions or provenance.get('opening_policy_loaded') or provenance.get('run_seed'):
            raise ValueError('Unsuccessful native search fabricated a playable seed')
        return out
    if not provenance.get('opening_policy_loaded') or provenance.get('run_seed') != native.get('seed'):
        raise ValueError('Native found seed was not the source run seed')
    complete = [r for r in rows if r['type'] == 'engine_opening_setup_complete']
    if len(complete) > 1: raise ValueError('Repeated setup completion')
    if complete:
        value = complete[0]
        if value['actual_pair'] != native['legendary_jokers'] or value['run_seed'] != native['seed']:
            raise ValueError('Source pair differs from native pair')
        souls = [a for a in actions if a['action']['kind'] == 'choose' and a.get('card_key') == 'c_soul']
        sales = [a for a in actions if a['action']['kind'] == 'sell']
        if len(souls) != 2 or len(sales) != native['required_sales'] or any(a.get('card_key') != 'j_egg' for a in sales):
            raise ValueError('Source setup action trace differs from opening contract')
        if not actions or actions[0]['action'] != {'kind': 'skip_blind', 'blind': 'Small'}:
            raise ValueError('Filtered setup did not follow original Charm skip')
        for key in ('search_seconds', 'setup_seconds', 'search_and_setup_seconds'):
            if not isinstance(value.get(key), (int, float)) or not math.isfinite(value[key]) or value[key] < 0:
                raise ValueError('Missing setup cost')
        if abs(value['search_seconds'] + value['setup_seconds'] - value['search_and_setup_seconds']) > 1e-6:
            raise ValueError('Setup cost excludes search')
        out.update(setup_complete=True, actual_pair=value['actual_pair'], setup_seconds=value['setup_seconds'],
                   search_and_setup_seconds=value['search_and_setup_seconds'])
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy-root', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--challenge', action='append', choices=CHALLENGES, required=True)
    parser.add_argument('--seed', required=True)
    parser.add_argument('--targets', default='')
    parser.add_argument('--search-limit', type=int, default=1)
    parser.add_argument('--timeout', type=float, default=20)
    parser.add_argument('--ordinary-actions', type=int, default=5)
    parser.add_argument('--cohort-label', required=True, help='Explain seed selection, including any preselected known fixture')
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    if not 0 < args.timeout <= 45 or not 1 <= len(args.challenge) <= 4 or not 1 <= args.ordinary_actions <= 12:
        parser.error('Bounded audit requires 1..4 challenges, <=45s per cell and 1..12 ordinary actions')
    directory = args.output_dir.resolve();directory.mkdir(parents=True, exist_ok=False)
    policy = register_native_policy(directory / 'policy', freeze_product(args.policy_root, directory / 'policy'))
    adapter = directory / 'adapter';adapter.mkdir()
    hashes = {name: file_digest(HERE / name) for name in ADAPTER_FILES}
    for name in ADAPTER_FILES: shutil.copyfile(HERE / name, adapter / name)
    if any(file_digest(adapter / name) != value or file_digest(HERE / name) != value for name, value in hashes.items()):
        raise ValueError('Adapter changed while freezing')
    manifest = {'qualification': False, 'scope': 'different_distribution_setup_and_prefix_only',
                'created_utc': datetime.now(timezone.utc).isoformat(), 'cohort_label': args.cohort_label,
                'seed_role': 'ordinary run seed / filtered native search start', 'policy': policy,
                'adapter_files': hashes, 'adapter_digest': digest(hashes), 'targets': args.targets,
                'rules_digest': file_digest(args.install / 'Balatro.exe'), 'runtime_digest': file_digest(args.install / 'lua51.dll'),
                'search_limit': args.search_limit, 'timeout_seconds': args.timeout, 'ordinary_actions': args.ordinary_actions,
                'requests': [{'challenge': challenge, 'seed': args.seed} for challenge in args.challenge]}
    manifest['manifest_digest'] = digest(manifest);write_json(directory / 'manifest.json', manifest)
    records = []
    for index, request in enumerate(manifest['requests']):
        for role in (('ordinary', 'filtered') if index % 2 == 0 else ('filtered', 'ordinary')):
            command = [sys.executable, '-u', str(adapter / 'engine_probe.py'), '--episode', '--policy-root', str(directory / 'policy'),
                       '--install', str(args.install), '--challenge', request['challenge'], '--seed', request['seed']]
            if role == 'filtered':
                command += ['--opening-targets', args.targets, '--opening-search-limit', str(args.search_limit), '--stop-on-opening-complete']
            else: command += ['--stop-after-step', str(args.ordinary_actions)]
            trace = directory / (request['challenge'] + '_' + role + '.log')
            record = collect(command, trace, request, args.timeout)
            try: result = inspect_record(record, manifest, role, request)
            except ValueError as error:
                result = {'role': role, **request, 'outcome': record['outcome'], 'trace': str(trace),
                          'elapsed_seconds': record['elapsed_seconds'], 'verification_error': str(error), 'setup_complete': False}
            records.append(result)
            write_json(directory / 'report.json', {'qualification': False, 'manifest_digest': manifest['manifest_digest'],
                'win_rate_estimate': None, 'time_to_win_estimate': None, 'records': records,
                'limitations': ['Preselected development requests; no representative seed denominator.',
                    'Ordinary action prefixes and filtered setup have different endpoints.',
                    'Source CPU time includes native search and setup; no live animation, human action, or restart time.',
                    'Native misses/errors/timeouts remain attempts, never wins or losses.']})
            print(json.dumps({k: v for k, v in result.items() if k not in ('actions', 'trace', 'trace_digest')}), flush=True)
    if policy_hashes(directory / 'policy') != policy['policy_files'] or any(file_digest(adapter / n) != v for n, v in hashes.items()):
        raise ValueError('Frozen audit product or adapter changed during execution')


if __name__ == '__main__': main()
