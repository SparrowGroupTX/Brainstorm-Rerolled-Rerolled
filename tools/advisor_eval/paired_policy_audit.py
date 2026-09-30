#!/usr/bin/env python3
"""Frozen paired development comparisons and bounded provenance-checked replay.

This workflow cannot qualify or promote a policy. It runs only the experimental
source adapter, preserves unresolved attempts, and separates each challenge.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import time

from benchmark import CHALLENGES, ORDINARY_START, digest, file_digest, policy_hashes
from development_report import distribution, episode_record, parse_trace

HERE = Path(__file__).resolve().parent
ADAPTER_FILES = ('engine_probe.py', 'engine_probe.lua', 'engine_run.lua', 'engine_contract.lua', 'opening_support.py', 'benchmark.py')
ROLES = ('incumbent', 'candidate')


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def freeze_product(source, destination):
    expected = policy_hashes(source)
    for relative in expected:
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(Path(source) / relative, target)
    if policy_hashes(destination) != expected or policy_hashes(source) != expected:
        raise ValueError('Product changed while freezing; use a stable source and fresh output directory')
    return {'policy_files': expected, 'policy_digest': digest(expected)}


def initialize(directory, roots, install, requests, timeout, action_limit, retry_overhead=0, unlock_profile=None):
    if not 0 < timeout <= 300 or not 0 <= retry_overhead <= 3600:
        raise ValueError('Require timeout 0..300s and declared retry overhead 0..3600s')
    if action_limit is not None and not 1 <= action_limit <= 500:
        raise ValueError('Action cutoff must be 1..500; omitted requests a full episode within the adapter cap')
    if not 1 <= len(requests) <= 20 or len({(r['challenge'], r['seed']) for r in requests}) != len(requests):
        raise ValueError('Require 1..20 unique paired challenge/seed requests')
    if any(r['challenge'] not in CHALLENGES or not r['seed'].isalnum() for r in requests):
        raise ValueError('Use known challenge IDs and alphanumeric development seeds')
    directory = Path(directory).resolve();directory.mkdir(parents=True, exist_ok=False)
    policies = {role: freeze_product(roots[role], directory / role) for role in ROLES}
    adapter = directory / 'adapter';adapter.mkdir()
    adapter_hashes = {name: file_digest(HERE / name) for name in ADAPTER_FILES}
    for name in ADAPTER_FILES:
        shutil.copyfile(HERE / name, adapter / name)
    if any(file_digest(adapter / name) != expected or file_digest(HERE / name) != expected
           for name, expected in adapter_hashes.items()):
        raise ValueError('Adapter changed while freezing')
    manifest = {'schema': 2, 'qualification': False, 'created_utc': datetime.now(timezone.utc).isoformat(),
                'workflow_digest': file_digest(__file__), 'adapter_digest': digest(adapter_hashes),
                'adapter_files': adapter_hashes, 'adapter_validation': 'experimental',
                'rules_digest': file_digest(install / 'Balatro.exe'),
                'runtime_digest': file_digest(install / 'lua51.dll'), 'install': str(install.resolve()),
                'policies': policies, 'start_distribution': dict(ORDINARY_START),
                'requests': requests, 'timeout_seconds': timeout, 'action_limit': action_limit,
                'retry_overhead_seconds': retry_overhead, 'candidate_parameter_source': 'frozen_product_source',
                'execution_order': 'paired_alternating_AB_BA', 'development_seeds': True}
    from engine_probe import retry_context_spec
    manifest['retry_context_spec'] = retry_context_spec()
    manifest['retry_context_spec_digest'] = digest(manifest['retry_context_spec'])
    if unlock_profile is not None:
        from engine_probe import profile_spec
        manifest['profile_spec'] = profile_spec(unlock_profile)
        manifest['profile_spec_digest'] = digest(manifest['profile_spec'])
    manifest['manifest_digest'] = digest(manifest)
    write_json(directory / 'manifest.json', manifest)
    return manifest


def verify_manifest(directory, verify_install=False):
    directory = Path(directory)
    manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))
    unsigned = dict(manifest);claimed = unsigned.pop('manifest_digest', None)
    if digest(unsigned) != claimed:
        raise ValueError('Paired manifest changed after registration')
    if manifest.get('start_distribution') != ORDINARY_START or manifest.get('adapter_validation') != 'experimental':
        raise ValueError('Unsupported start distribution or falsely qualified adapter')
    if manifest.get('schema') not in (1, 2):
        raise ValueError('Unknown paired manifest schema')
    if manifest.get('schema') == 2 or any(key in manifest for key in ('retry_context_spec', 'retry_context_spec_digest')):
        from engine_probe import validate_retry_spec
        validate_retry_spec(manifest.get('retry_context_spec'), manifest.get('retry_context_spec_digest'))
    for role in ROLES:
        expected = manifest['policies'][role]['policy_files']
        # Historical manifests may have included config.lua before the product
        # enumerator was corrected. Preserve and verify those recorded bytes;
        # never rewrite the old manifest or copy preferences into new freezes.
        current_scope = {key: value for key, value in expected.items() if key.lower() != 'brainstorm/config.lua'}
        if (policy_hashes(directory / role) != current_scope or
                any(file_digest(directory / role / key) != value for key, value in expected.items())):
            raise ValueError('Frozen product changed: ' + role)
    for name, expected in manifest['adapter_files'].items():
        if file_digest(directory / 'adapter' / name) != expected:
            raise ValueError('Frozen adapter changed: ' + name)
    if verify_install:
        for key, name in [('rules_digest', 'Balatro.exe'), ('runtime_digest', 'lua51.dll')]:
            if file_digest(Path(manifest['install']) / name) != manifest[key]:
                raise ValueError('Installed source/runtime changed: ' + key)
    return manifest


def command_for(directory, manifest, role, request, full_episode=False):
    directory = Path(directory).resolve()
    command = [sys.executable, '-u', str(directory / 'adapter' / 'engine_probe.py'), '--episode',
               '--install', manifest['install'], '--policy-root', str(directory / role),
               '--challenge', request['challenge'], '--seed', request['seed']]
    if manifest['action_limit'] is not None and not full_episode:
        command += ['--stop-after-step', str(manifest['action_limit'])]
    if manifest.get('profile_spec'):
        command += ['--unlock-profile', manifest['profile_spec']['name']]
    return command


def collect(command, trace, request, timeout):
    started = time.perf_counter()
    with Path(trace).open('x', encoding='utf-8') as output:
        try:
            result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=timeout,
                                    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            exit_code = result.returncode
        except subprocess.TimeoutExpired:
            exit_code = 'timeout'
        except OSError as error:
            exit_code = 'launch_error';output.write(str(error) + '\n')
    return episode_record(trace, request['challenge'], request['seed'], exit_code, time.perf_counter() - started, command)


def checked_record(directory, manifest, record):
    """Re-read the trace; a trusted-looking cached result cannot turn errors into wins."""
    role, index = record.get('role'), record.get('pair_index')
    if role not in ROLES or type(index) is not int or not 0 <= index < len(manifest['requests']):
        raise ValueError('Unknown role or pair index')
    request = manifest['requests'][index]
    if record.get('challenge') != request['challenge'] or record.get('seed') != request['seed']:
        raise ValueError('Record request mismatch')
    trace = Path(record['trace'])
    if not trace.resolve().is_relative_to(Path(directory).resolve()):
        raise ValueError('Trace escaped the registered output directory')
    if file_digest(trace) != record.get('trace_digest'):
        raise ValueError('Trace digest changed')
    elapsed = record.get('elapsed_seconds')
    if isinstance(elapsed, bool) or not isinstance(elapsed, (int, float)) or not math.isfinite(elapsed) or elapsed < 0:
        raise ValueError('Invalid attempt elapsed time')
    expected_command = command_for(directory, manifest, role, request)
    # Python installation can move between audits; all effectful arguments must match.
    if record.get('command', [])[1:] != expected_command[1:]:
        raise ValueError('Recorded execution arguments differ from paired manifest')
    actual = episode_record(trace, request['challenge'], request['seed'], record['exit_code'], elapsed, record['command'])
    provenance = actual['provenance']
    expected = {key: manifest[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest', 'start_distribution')}
    expected.update(manifest['policies'][role])
    expected.update({'challenge': request['challenge'], 'seed': request['seed'], 'opening_policy_loaded': False})
    if manifest.get('profile_spec'):
        expected.update({key: manifest[key] for key in ('profile_spec', 'profile_spec_digest')})
    if manifest.get('retry_context_spec'):
        expected.update({key: manifest[key] for key in ('retry_context_spec', 'retry_context_spec_digest')})
    if any(provenance.get(key) != value for key, value in expected.items()):
        raise ValueError('Trace provenance differs from frozen policy/rules/start/adapter')
    if provenance.get('counterfactual') or provenance.get('followed_advice') is False:
        raise ValueError('Counterfactual or overridden action cannot enter paired policy comparison')
    trace_rows, _ = parse_trace(trace)
    if sum(r.get('type') == 'engine_probe_provenance' for r in trace_rows) != 1:
        raise ValueError('Trace needs exactly one provenance record')
    from engine_probe import applied_retry_context
    actual['retry_context'] = applied_retry_context(trace_rows, provenance, manifest.get('retry_context_spec'))
    actual.update({'role': role, 'pair_index': index,
                   'action_sequence': [(r['step'], r['action']) for r in trace_rows if r.get('type') == 'engine_episode_action']})
    return actual


def retry_proxy(records, retry_overhead=0):
    """Diagnostic E[attempt time]/p, with every terminal failure duration included."""
    if not records or any(r['outcome'] not in ('win', 'loss') for r in records):
        return {'seconds': None, 'reason': 'incomplete_or_invalid_episode_coverage'}
    wins = sum(r['outcome'] == 'win' for r in records)
    if not wins:
        return {'seconds': None, 'reason': 'no_observed_success'}
    failures = len(records) - wins
    return {'seconds': (sum(r['elapsed_seconds'] for r in records) + retry_overhead * failures) / wins,
            'reason': 'development_terminal_proxy_only', 'wins': wins, 'failures': failures,
            'attempted': len(records), 'declared_retry_overhead_seconds': retry_overhead}


def compare(manifest, records, errors=()):
    """Never drop unmatched or unresolved pairs to improve the apparent result."""
    seen = Counter((r['pair_index'], r['role']) for r in records)
    missing = [{'pair_index': i, 'role': role} for i in range(len(manifest['requests'])) for role in ROLES
               if seen[i, role] == 0]
    duplicates = [{'pair_index': i, 'role': role} for (i, role), count in seen.items() if count > 1]
    blockers = ['adapter_unqualified', 'development_seeds', 'live_action_timing_unmeasured']
    if missing: blockers.append('missing_attempts')
    if duplicates: blockers.append('duplicate_attempts')
    if errors: blockers.append('trace_or_provenance_audit_failed')
    if any(r['outcome'] not in ('win', 'loss') for r in records): blockers.append('nonterminal_or_invalid_attempts')
    cohorts = []
    for challenge in sorted({r['challenge'] for r in manifest['requests']}):
        cohort = {'challenge': challenge, 'start_distribution': manifest['start_distribution'], 'roles': {}}
        expected_count = sum(r['challenge'] == challenge for r in manifest['requests'])
        comparable = not errors and not duplicates
        challenge_records = [r for r in records if r['challenge'] == challenge]
        complete_pair_cohort = len(challenge_records) == expected_count * 2 and all(r['outcome'] in ('win', 'loss') for r in challenge_records)
        unlocks = {((r.get('unlock_profile') or {}).get('unlock_profile_digest')) for r in records if r['challenge'] == challenge}
        if None in unlocks or len(unlocks) != 1:
            comparable = False;blockers.append('unlock_profile_mismatch_or_missing')
        for role in ROLES:
            group = [r for r in records if r['challenge'] == challenge and r['role'] == role]
            eligible = comparable and complete_pair_cohort and len(group) == expected_count
            proxy = retry_proxy(group, manifest['retry_overhead_seconds']) if eligible else {'seconds': None, 'reason': 'pair_coverage_or_provenance_failed'}
            cohort['roles'][role] = {'requested': expected_count, 'recorded': len(group),
                'outcomes': dict(Counter(r['outcome'] for r in group)),
                'attempt_seconds': distribution(r['elapsed_seconds'] for r in group),
                'advisor_seconds': distribution(p.get('advisor_seconds') for r in group for p in r['profiles']),
                'score_calls': distribution(p.get('score_calls') for r in group for p in r['profiles']),
                'diagnostic_retry_time_proxy': proxy, 'qualified_win_rate': None}
        a, b = (cohort['roles'][role]['diagnostic_retry_time_proxy']['seconds'] for role in ROLES)
        cohort['diagnostic_candidate_minus_incumbent_seconds'] = b - a if a is not None and b is not None else None
        cohorts.append(cohort)
    paired_prefixes = []
    if not errors and not duplicates:
        for index, request in enumerate(manifest['requests']):
            pair = {r['role']: r for r in records if r['pair_index'] == index}
            if set(pair) != set(ROLES): continue
            a, b = (pair[role] for role in ROLES)
            if (a.get('unlock_profile') or {}).get('unlock_profile_digest') != (b.get('unlock_profile') or {}).get('unlock_profile_digest'): continue
            common = []
            for left, right in zip(a.get('action_sequence', []), b.get('action_sequence', [])):
                if left != right: break
                common.append(left[0])
            def total(row, key): return sum(p.get(key, 0) for p in row['profiles'] if p['step'] in common)
            paired_prefixes.append({'pair_index': index, **request, 'matching_action_prefix': len(common),
                'candidate_minus_incumbent_advisor_seconds': total(b, 'advisor_seconds') - total(a, 'advisor_seconds') if common else None,
                'candidate_minus_incumbent_score_calls': total(b, 'score_calls') - total(a, 'score_calls') if common else None})
    return {'schema': 1, 'qualification': False, 'promotion_allowed': False, 'recommended_policy': None,
            'retry_context': manifest.get('retry_context_spec') or {'mode': 'historical_unreported'},
            'retry_advice_evaluated': False,
            'manifest_digest': manifest['manifest_digest'], 'auditor_digest': file_digest(__file__), 'requested_attempts': len(manifest['requests']) * 2,
            'valid_records': len(records), 'missing': missing, 'duplicates': duplicates, 'audit_errors': list(errors),
            'blockers': sorted(set(blockers)), 'cohorts': cohorts, 'expected_time_all_20_challenges': None,
            'paired_prefix_latency_diagnostics': paired_prefixes,
            'failure_replay_targets': [{'pair_index': r['pair_index'], 'role': r['role'], 'challenge': r['challenge'],
                                       'seed': r['seed'], 'outcome': r['outcome'], 'reason': r['reason'], 'trace': r['trace']}
                                      for r in records if r['outcome'] not in ('win', 'censored')],
            'same_product': manifest['policies']['incumbent']['policy_digest'] == manifest['policies']['candidate']['policy_digest'],
            'timing_scope': 'Hidden source process wall clock including startup; prefix timings do not estimate time to win',
            'limitations': ['Synthetic unlock profile and experimental adapter remain unqualified',
                            'Manual checkpoint restoration and persistent retry-history policy are not evaluated',
                            'Terminal proxies require complete matched cohorts and include failed attempts',
                            'Censoring, timeout, unsupported mechanics, mismatches and missing attempts cannot become losses or wins',
                            'Development candidates are source variants; no unapplied search-option metadata is treated as a tuned policy']}


def audit(directory):
    manifest = verify_manifest(directory)
    records, errors = [], []
    path = Path(directory) / 'episodes.jsonl'
    for number, line in enumerate(path.read_text(encoding='utf-8').splitlines() if path.exists() else (), 1):
        try:
            records.append(checked_record(directory, manifest, json.loads(line)))
        except (ValueError, KeyError, OSError, TypeError) as error:
            errors.append({'record_line': number, 'reason': str(error)})
    report = compare(manifest, records, errors)
    write_json(Path(directory) / 'report.json', report)
    return report


def run_pairs(args):
    requests = [{'challenge': challenge, 'seed': seed} for challenge in args.challenges for seed in args.seeds]
    manifest = initialize(args.output_dir, {role: getattr(args, role + '_root') for role in ROLES}, args.install,
                          requests, args.timeout, None if args.full_episode else args.stop_after_step, args.retry_overhead_seconds)
    for index, request in enumerate(requests):
        order = ROLES if index % 2 == 0 else tuple(reversed(ROLES))
        for role in order:
            command = command_for(args.output_dir, manifest, role, request)
            record = collect(command, args.output_dir / f'{index:03d}_{role}.log', request, args.timeout)
            record.update({'pair_index': index, 'role': role})
            with (args.output_dir / 'episodes.jsonl').open('a', encoding='utf-8') as output:
                output.write(json.dumps(record, allow_nan=False) + '\n')
            print(json.dumps({k: record[k] for k in ('pair_index', 'role', 'challenge', 'seed', 'outcome', 'reason', 'elapsed_seconds')}), flush=True)
            audit(args.output_dir)
    return audit(args.output_dir)


def replay(args):
    manifest = verify_manifest(args.directory, verify_install=True)
    records = [json.loads(line) for line in (args.directory / 'episodes.jsonl').read_text(encoding='utf-8').splitlines()]
    matching = [r for r in records if r.get('pair_index') == args.pair and r.get('role') == args.role]
    if len(matching) != 1:
        raise ValueError('Replay requires exactly one recorded matching attempt')
    original = checked_record(args.directory, manifest, matching[0])
    request = manifest['requests'][args.pair]
    command = command_for(args.directory, manifest, args.role, request, full_episode=args.full_episode)
    result = {'qualification': False, 'source_trace': original['trace'], 'source_trace_digest': original['trace_digest'],
              'provenance': original['provenance'], 'command': command, 'timeout_seconds': args.timeout,
              'full_episode_requested': args.full_episode, 'adapter_action_cap': 500, 'executed': False}
    args.output_dir.mkdir(parents=True, exist_ok=False)
    if args.execute:
        record = collect(command, args.output_dir / 'replay.log', request, args.timeout)
        result['executed'] = True;result['result'] = record
        before, _ = parse_trace(original['trace']);after, _ = parse_trace(record['trace'])
        def actions(rows): return [(r['step'], r['action']) for r in rows if r.get('type') == 'engine_episode_action']
        baseline, repeated = actions(before), actions(after)
        common = min(len(baseline), len(repeated))
        same_provenance = record['provenance'] == original['provenance']
        result['common_action_prefix'] = common
        result['prefix_matches'] = bool(common) and baseline[:common] == repeated[:common] and same_provenance
        result['original_prefix_completed'] = len(repeated) >= len(baseline)
    write_json(args.output_dir / 'replay.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__);sub = parser.add_subparsers(dest='mode', required=True)
    run = sub.add_parser('run', help='Freeze paired source candidates and collect bounded episodes')
    for role in ROLES: run.add_argument('--' + role + '-root', type=Path, required=True)
    run.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    run.add_argument('--challenges', nargs='+', default=['c_omelette_1']);run.add_argument('--seeds', nargs='+', required=True)
    run.add_argument('--stop-after-step', type=int, default=3);run.add_argument('--full-episode', action='store_true')
    run.add_argument('--timeout', type=float, default=45);run.add_argument('--retry-overhead-seconds', type=float, default=0)
    run.add_argument('--output-dir', type=Path, required=True)
    review = sub.add_parser('audit', help='Recheck manifest, trace digests, provenance and coverage')
    review.add_argument('--directory', type=Path, required=True)
    repeat = sub.add_parser('replay', help='Emit or execute the exact frozen command with checked trace provenance')
    repeat.add_argument('--directory', type=Path, required=True);repeat.add_argument('--pair', type=int, default=0)
    repeat.add_argument('--role', choices=ROLES, default='candidate');repeat.add_argument('--full-episode', action='store_true')
    repeat.add_argument('--timeout', type=float, default=45);repeat.add_argument('--execute', action='store_true')
    repeat.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    try:
        if hasattr(args, 'timeout') and not 0 < args.timeout <= 300: raise ValueError('Timeout must be 0..300 seconds')
        result = run_pairs(args) if args.mode == 'run' else audit(args.directory) if args.mode == 'audit' else replay(args)
    except (ValueError, KeyError, OSError) as error:
        parser.error(str(error))
    if args.mode == 'replay':
        summary = {key: result.get(key) for key in ('executed', 'command', 'timeout_seconds', 'full_episode_requested', 'prefix_matches', 'common_action_prefix')}
        summary.update({'report': str((args.output_dir / 'replay.json').resolve()), 'outcome': result.get('result', {}).get('outcome')})
    else:
        directory = args.output_dir if args.mode == 'run' else args.directory
        summary = {key: result[key] for key in ('requested_attempts', 'valid_records', 'audit_errors', 'blockers', 'promotion_allowed')}
        summary['report'] = str((directory / 'report.json').resolve())
    print(json.dumps(summary, indent=2, allow_nan=False))
    if args.mode == 'replay':
        return 2 if result.get('executed') and (not result.get('prefix_matches') or result['result']['outcome'] in ('error', 'unsupported', 'timeout')) else 0
    return 2 if result['audit_errors'] or any(r['roles'][role]['outcomes'].get(outcome, 0) for r in result['cohorts'] for role in ROLES for outcome in ('error', 'unsupported', 'timeout')) else 0


if __name__ == '__main__':
    raise SystemExit(main())
