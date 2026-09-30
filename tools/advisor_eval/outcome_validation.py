"""Register full paired attempts and separate development from unseen holdouts.

All requested attempts remain visible. This small source-adapter experiment can
expose regressions; it cannot qualify population win rates or promote a policy.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import shutil
import time

import engine_probe
import paired_policy_audit as paired

HERE = Path(__file__).resolve().parent
AUDITORS = ('outcome_validation.py', 'paired_policy_audit.py', 'development_report.py',
            'engine_probe.py', 'benchmark.py', 'opening_support.py')


def requests_from(value):
    if not isinstance(value, list) or not 2 <= len(value) <= 10:
        raise ValueError('Register two to ten complete pairs')
    seen = set()
    for row in value:
        if not isinstance(row, dict) or set(row) != {'challenge', 'seed', 'split'}:
            raise ValueError('Each request needs exactly challenge, seed and split')
        if row['challenge'] not in paired.CHALLENGES or not isinstance(row['seed'], str) or not row['seed'].isalnum():
            raise ValueError('Use known challenges and alphanumeric fresh seeds')
        if row['split'] not in ('development', 'holdout'):
            raise ValueError('Declare development or holdout before execution')
        identity = row['challenge'], row['seed']
        if identity in seen:
            raise ValueError('A trajectory cannot be reused, including across development and holdout')
        seen.add(identity)
    if {r['split'] for r in value} != {'development', 'holdout'}:
        raise ValueError('Both development and unseen holdout requests are required')
    return sorted(value, key=lambda r: r['split'] == 'holdout')


def finite_range(value, low, high):
    return type(value) in (int, float) and math.isfinite(value) and low <= value <= high


def applied_profile(rows, manifest):
    profiles = [row for row in rows if row.get('type') == 'engine_probe_profile']
    if len(profiles) != 1:
        raise ValueError('Require one actual source profile inventory')
    profile = profiles[0]; spec = manifest.get('profile_spec')
    if not spec or profile.get('profile_spec') != spec:
        raise ValueError('Actual and declared source profiles differ')
    inventory = profile.get('inventory') or []
    data = '\n'.join(':'.join(row[key] for key in ('scope', 'key', 'unlocked', 'discovered'))
                     for row in inventory).encode()
    if engine_probe.profile_record(spec['name'], data) != profile:
        raise ValueError('Actual profile inventory or digest was altered')
    return profile['unlock_profile_digest']


def initialize(args):
    requests = requests_from(json.loads(args.requests.read_text(encoding='utf-8-sig')))
    if not finite_range(args.timeout, 1, 120) or not finite_range(args.wall_budget, 1, 1440):
        raise ValueError('Per-worker cap must be 1..120s and cumulative cap 1..1440s')
    if not finite_range(args.action_seconds, 0, 30) or not finite_range(args.retry_seconds, 0, 3600):
        raise ValueError('Declare finite action/retry time scenarios within bounds')
    out = args.output.resolve()
    manifest = paired.initialize(out, {'incumbent': args.incumbent, 'candidate': args.candidate},
        args.install, requests, args.timeout, None, args.retry_seconds, unlock_profile=args.unlock_profile)
    registration = {'schema': 1, 'manifest_digest': manifest['manifest_digest'],
        'created_utc': datetime.now(timezone.utc).isoformat(), 'requests': requests,
        'wall_budget_seconds': args.wall_budget, 'action_seconds': args.action_seconds,
        'retry_seconds': args.retry_seconds, 'full_episode_requested': True,
        'auditor_files': {name: paired.file_digest(HERE / name) for name in AUDITORS},
        'qualification': False, 'promotion_allowed': False,
        'scope': 'Fixed policies, terminal development/holdout pilot; unknown outcomes retained'}
    registration['registration_digest'] = paired.digest(registration)
    (out / 'auditors').mkdir()
    for name, expected in registration['auditor_files'].items():
        shutil.copyfile(HERE / name, out / 'auditors' / name)
        if paired.file_digest(out / 'auditors' / name) != expected or paired.file_digest(HERE / name) != expected:
            raise ValueError('Auditor changed during registration; preserve this incomplete output')
    paired.write_json(out / 'outcome_registration.json', registration)
    return registration


def verify(directory):
    out = Path(directory).resolve()
    registration = json.loads((out / 'outcome_registration.json').read_text())
    unsigned = dict(registration); claimed = unsigned.pop('registration_digest', None)
    if paired.digest(unsigned) != claimed:
        raise ValueError('Outcome registration changed')
    manifest = paired.verify_manifest(out)
    if registration['manifest_digest'] != manifest['manifest_digest'] or registration['requests'] != manifest['requests']:
        raise ValueError('Outcome and pair registrations disagree')
    if manifest['action_limit'] is not None or not registration['full_episode_requested']:
        raise ValueError('Opening cutoffs cannot enter terminal outcome validation')
    if any(paired.file_digest(out / 'auditors' / name) != expected for name, expected in registration['auditor_files'].items()):
        raise ValueError('Frozen auditor bytes changed')
    return registration, manifest


def cohort_summary(requests, records, role, action_seconds, retry_seconds, rejected=()):
    indices = {r['pair_index'] for r in requests}
    members = [r for r in records if r['pair_index'] in indices and r['role'] == role]
    outcomes = Counter(r['outcome'] for r in members)
    verified_indices = {r['pair_index'] for r in members}
    unverified = {r['pair_index']: r for r in rejected
                  if r.get('pair_index') in indices - verified_indices and r.get('role') == role}
    missing = len(indices) - len(members) - len(unverified)
    if missing:
        outcomes['missing'] += missing
    if unverified:
        outcomes['unverified'] += len(unverified)
    complete = not missing and not unverified and all(r['outcome'] in ('win', 'loss') for r in members)
    wins = outcomes['win']
    raw_seconds = sum(r['elapsed_seconds'] for r in members)
    actions = sum(sum(r['actions'].values()) for r in members)
    scenario = raw_seconds + actions * action_seconds + outcomes['loss'] * retry_seconds
    anomaly_fields = ('missing_verification_steps', 'duplicate_verification_steps',
                      'unmatched_verification_steps', 'invalid_verification_scope_steps')
    gaps = sum((r.get('score_verification') or {}).get('explicit_unverified_scores', 0) +
               sum(len((r.get('score_verification') or {}).get(key, [])) for key in anomaly_fields) for r in members)
    return {'requested': len(indices), 'outcomes': dict(outcomes), 'complete_terminal_coverage': complete,
        'reported_unverified_outcomes': dict(Counter(str(r['unverified_record'].get('outcome', 'unknown'))
                                                     for r in unverified.values())),
        'observed_source_wins': wins, 'qualified_win_rate': None,
        'observed_seconds': raw_seconds, 'observed_actions': actions, 'score_gap_count': gaps,
        'diagnostic_seconds_per_win': scenario / wins if complete and wins else None,
        'time_scope': 'Source wall time includes startup/compute; added clicks/retries are declared scenarios',
        'reason': 'complete_small_source_pilot' if complete else 'unresolved_attempts_prevent_rate_or_retry_time_inference'}


def audit(directory):
    out = Path(directory).resolve(); registration, manifest = verify(out)
    records, errors = [], []
    path = out / 'episodes.jsonl'
    seen, submitted = set(), set()
    line_number = 0
    for line_number, line in enumerate(path.read_text().splitlines() if path.exists() else (), 1):
        value, identity = None, None
        try:
            def nonfinite(number):
                raise ValueError('Nonfinite JSON value: ' + number)
            value = json.loads(line, parse_constant=nonfinite)
            if not isinstance(value, dict):
                raise ValueError('Attempt record must be an object')
            index, role = value.get('pair_index'), value.get('role')
            if type(index) is int and 0 <= index < len(manifest['requests']) and role in paired.ROLES:
                request = manifest['requests'][index]
                if all(value.get(key) == request[key] for key in ('challenge', 'seed')):
                    identity = index, role
                    submitted.add(identity)
            if identity is None:
                raise ValueError('Unknown or mismatched attempt identity')
            if identity in seen:
                raise ValueError('Duplicate attempt record')
            seen.add(identity)
            checked = paired.checked_record(out, manifest, value)
            rows, _ = paired.parse_trace(checked['trace'])
            checked['validated_profile_digest'] = applied_profile(rows, manifest)
            records.append(checked)
        except (ValueError, KeyError, OSError, TypeError) as error:
            detail = {'line': line_number, 'reason': str(error), 'raw_record_line': line,
                      'unverified_record': value, 'interpretation': 'Rejected metadata is preserved, not a validated outcome'}
            if identity is not None:
                detail.update(pair_index=identity[0], role=identity[1])
            errors.append(detail)
    groups, divergences, prefix_ends, failures = [], [], [], []
    for split in ('development', 'holdout'):
        for challenge in sorted({r['challenge'] for r in registration['requests'] if r['split'] == split}):
            requests = [dict(r, pair_index=i) for i, r in enumerate(registration['requests'])
                        if r['split'] == split and r['challenge'] == challenge]
            roles = {role: cohort_summary(requests, records, role, registration['action_seconds'],
                                         registration['retry_seconds'], errors) for role in paired.ROLES}
            if errors:
                for summary in roles.values():
                    summary.update(complete_terminal_coverage=False, diagnostic_seconds_per_win=None,
                                   reason='audit_errors_prevent_comparison')
            complete = not errors and all(r['complete_terminal_coverage'] for r in roles.values())
            selected_indices = {r['pair_index'] for r in requests}
            profiles = {r.get('validated_profile_digest') for r in records if r['pair_index'] in selected_indices}
            if None in profiles or len(profiles) != 1:
                complete = False
                for summary in roles.values():
                    summary.update(complete_terminal_coverage=False, diagnostic_seconds_per_win=None,
                                   reason='actual_source_profile_mismatch_or_missing')
            change = roles['candidate']['observed_source_wins'] - roles['incumbent']['observed_source_wins']
            groups.append({'split': split, 'challenge': challenge, 'roles': roles,
                'paired_terminal_coverage': complete, 'observed_win_difference': change if complete else None,
                'interpretation': 'small_terminal_comparison_not_population_estimate' if complete else 'inconclusive'})
    for i, request in enumerate(registration['requests']):
        pair = {r['role']: r for r in records if r['pair_index'] == i}
        pair_errors = any(error.get('pair_index') == i for error in errors)
        profiles = {r['validated_profile_digest'] for r in pair.values()}
        if set(pair) == set(paired.ROLES) and not pair_errors and len(profiles) == 1:
            a, b = (pair[role]['action_sequence'] for role in paired.ROLES)
            different = next(((left, right) for left, right in zip(a, b) if left != right), None)
            if different:
                divergences.append({'pair_index': i, **request, 'incumbent': different[0], 'candidate': different[1],
                    'interpretation': 'Replay entry point only; later progress does not establish causation'})
            elif len(a) != len(b):
                ended_role = paired.ROLES[0] if len(a) < len(b) else paired.ROLES[1]
                prefix_ends.append({'pair_index': i, **request, 'matching_action_prefix': min(len(a), len(b)),
                    'ended_role': ended_role, 'ended_outcome': pair[ended_role]['outcome'],
                    'ended_reason': pair[ended_role]['reason'], 'next_observed_action': (b if len(a) < len(b) else a)[min(len(a), len(b))],
                    'interpretation': 'One observed sequence ended; no different action is established at this boundary'})
        for record in pair.values():
            if record['outcome'] != 'win':
                failures.append({'pair_index': i, **request, 'role': record['role'], 'outcome': record['outcome'],
                    'reason': record['reason'], 'trace': record['trace'], 'loss_analysis': record['loss_analysis']})
    report = {'schema': 1, 'registration_digest': registration['registration_digest'],
        'auditor_files': {name: paired.file_digest(HERE / name) for name in AUDITORS},
        'auditors_match_registration': all(paired.file_digest(HERE / name) == value
                                          for name, value in registration['auditor_files'].items()),
        'qualification': False, 'promotion_allowed': False, 'qualified_win_rate': None,
        'retry_context': manifest.get('retry_context_spec') or {'mode': 'historical_unreported'},
        'retry_advice_evaluated': False,
        'requested_attempts': 2 * len(registration['requests']), 'recorded_attempts': len(records),
        'submitted_attempt_records': line_number,
        'missing_attempts': [{'pair_index': i, **request, 'role': role}
                             for i, request in enumerate(registration['requests']) for role in paired.ROLES
                             if (i, role) not in submitted],
        'audit_errors': errors, 'cohorts': groups, 'first_divergences': divergences, 'failure_targets': failures,
        'action_prefix_ends': prefix_ends,
        'limitations': ['Every missing/error/timeout/unsupported/censored attempt remains explicit',
            'Checkpoint restoration, persistent retry history and manual reload policy are not evaluated',
            'Heldout results cannot select this already frozen candidate',
            'Source profile and synthetic mechanics checks do not qualify user-population odds',
            'Declared action time is a scenario, not measured user latency']}
    paired.write_json(out / 'outcome_report.json', report)
    return report


def execute(directory):
    out = Path(directory).resolve(); registration, manifest = verify(out)
    if any(paired.file_digest(HERE / name) != expected for name, expected in registration['auditor_files'].items()):
        raise ValueError('Auditors changed since registration; do not execute a mixed workflow')
    paired.verify_manifest(out, verify_install=True)
    with (out / 'outcome_execution_started.json').open('x') as lease:
        json.dump({'started_utc': datetime.now(timezone.utc).isoformat(),
                   'registration_digest': registration['registration_digest']}, lease)
    deadline = time.perf_counter() + registration['wall_budget_seconds']
    for i, request in enumerate(manifest['requests']):
        # Admit the complete pair before either side. Faster earlier requests
        # leave budget; interrupted/exhausted workflows never renew their lease.
        if time.perf_counter() + 2 * manifest['timeout_seconds'] > deadline:
            break
        for role in paired.ROLES if i % 2 == 0 else tuple(reversed(paired.ROLES)):
            # Auditing and filesystem work also consume the cumulative budget.
            # If the full registered worker no longer fits, leave it missing;
            # never silently renew its allowance or truncate its declared cap.
            if time.perf_counter() + manifest['timeout_seconds'] > deadline:
                return audit(out)
            record = paired.collect(paired.command_for(out, manifest, role, request),
                out / f'{i:03d}_{role}.log', request, manifest['timeout_seconds'])
            record.update(pair_index=i, role=role)
            with (out / 'episodes.jsonl').open('a') as handle:
                handle.write(json.dumps(record, allow_nan=False) + '\n')
            print(json.dumps({'split': request['split'], **{key: record[key] for key in
                ('pair_index', 'role', 'challenge', 'seed', 'outcome', 'reason', 'elapsed_seconds')}}), flush=True)
            audit(out)
    paired.verify_manifest(out, verify_install=True)
    return audit(out)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    modes = p.add_mutually_exclusive_group()
    modes.add_argument('--execute', type=Path); modes.add_argument('--audit', type=Path)
    p.add_argument('--incumbent', type=Path); p.add_argument('--candidate', type=Path)
    p.add_argument('--requests', type=Path); p.add_argument('--output', type=Path)
    p.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    p.add_argument('--timeout', type=float, default=90); p.add_argument('--wall-budget', type=float, default=1080)
    p.add_argument('--action-seconds', type=float, default=1.5); p.add_argument('--retry-seconds', type=float, default=5)
    p.add_argument('--unlock-profile', default='all_unlocked_discovered_v1')
    a = p.parse_args()
    if a.execute or a.audit:
        report = execute(a.execute) if a.execute else audit(a.audit)
        print(json.dumps({key: report[key] for key in ('requested_attempts', 'recorded_attempts', 'audit_errors')}))
    else:
        if not all((a.incumbent, a.candidate, a.requests, a.output)):
            p.error('Require incumbent, candidate, requests and fresh output for registration')
        report = initialize(a); print(json.dumps({'registration_digest': report['registration_digest']}))


if __name__ == '__main__':
    main()
