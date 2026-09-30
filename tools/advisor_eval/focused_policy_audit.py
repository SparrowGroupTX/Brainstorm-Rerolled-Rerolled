"""Register two prospective development-only pairs under one four-worker lease.

This narrow protocol reuses outcome_validation's frozen provenance, complete
attempt auditing and cumulative admission. It generates requests only after the
fixed products are selected. No holdout evaluation or policy promotion is claimed.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import secrets
import shutil

import outcome_validation as outcome
import paired_policy_audit as paired

HERE = Path(__file__).resolve().parent
AUDITORS = outcome.AUDITORS + ('focused_policy_audit.py',)
SCOPE = 'prospective_development_only_two_pairs'
WORKER_SECONDS = 80
WALL_SECONDS = 340


def fresh_requests(challenges):
    if len(challenges) != 2 or len(set(challenges)) != 2 or any(c not in paired.CHALLENGES for c in challenges):
        raise ValueError('Choose exactly two distinct known challenges before request generation')
    alphabet = '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    return [{'challenge': challenge, 'seed': ''.join(secrets.choice(alphabet) for _ in range(8)),
             'split': 'development'} for challenge in challenges]


def initialize(args):
    if not outcome.finite_range(args.action_seconds, 0, 30) or not outcome.finite_range(args.retry_seconds, 0, 3600):
        raise ValueError('Action/retry timings must be finite declared scenarios')
    out = args.output.resolve()
    if out.exists():
        raise FileExistsError('A fresh output directory is required; never renew a spent lease')
    requests = fresh_requests(args.challenges)
    manifest = paired.initialize(out, {'incumbent': args.incumbent, 'candidate': args.candidate},
        args.install, requests, WORKER_SECONDS, None, args.retry_seconds, unlock_profile=args.unlock_profile)
    registration = {'schema': 1, 'manifest_digest': manifest['manifest_digest'],
        'created_utc': datetime.now(timezone.utc).isoformat(), 'requests': requests,
        'wall_budget_seconds': WALL_SECONDS, 'action_seconds': args.action_seconds,
        'retry_seconds': args.retry_seconds, 'full_episode_requested': True,
        'auditor_files': {name: paired.file_digest(HERE / name) for name in AUDITORS},
        'qualification': False, 'promotion_allowed': False, 'scope': SCOPE,
        'requested_workers': 4, 'holdout_requests': 0,
        'request_origin': 'Cryptographically generated at prospective registration; no prior traces inspected',
        'limitations': ['Two development requests cannot qualify population win rates or a heldout comparison.',
            'Four workers maximum, 80 seconds each, 340 seconds cumulative including audit overhead; one exclusive lease.',
            'Errors, timeouts, unsupported, censored and missing attempts remain explicit; unused time does not renew workers.',
            'Source startup/computation are already in worker wall; clicks/retries are declared scenarios.']}
    registration['registration_digest'] = paired.digest(registration)
    (out / 'auditors').mkdir()
    for name, expected in registration['auditor_files'].items():
        shutil.copyfile(HERE / name, out / 'auditors' / name)
        if paired.file_digest(out / 'auditors' / name) != expected or paired.file_digest(HERE / name) != expected:
            raise ValueError('Auditor changed during freeze; retain this incomplete registration')
    paired.write_json(out / 'outcome_registration.json', registration)
    verify(out)
    return registration


def verify(directory):
    registration, manifest = outcome.verify(directory)
    requests = registration['requests']
    if (registration.get('scope') != SCOPE or registration.get('requested_workers') != 4 or
            registration.get('holdout_requests') != 0 or registration.get('qualification') is not False or
            registration.get('promotion_allowed') is not False or
            registration['wall_budget_seconds'] != WALL_SECONDS or manifest['timeout_seconds'] != WORKER_SECONDS or
            len(requests) != 2 or len({r['challenge'] for r in requests}) != 2 or
            any(r.get('split') != 'development' for r in requests) or
            set(registration['auditor_files']) != set(AUDITORS)):
        raise ValueError('Unsupported focused development scope, frozen auditors or one-use caps')
    return registration, manifest


def annotate(directory, report):
    registration, _ = verify(directory)
    report.update(scope=SCOPE, holdout_requests=0, requested_workers=4,
                  registered_worker_seconds=WORKER_SECONDS, registered_workflow_seconds=WALL_SECONDS)
    report['limitations'] = registration['limitations'] + [s for s in report['limitations']
        if not s.startswith('Heldout results')]
    paired.write_json(Path(directory) / 'outcome_report.json', report)
    return report


def execute(directory):
    verify(directory)
    return annotate(directory, outcome.execute(directory))


def audit(directory):
    verify(directory)
    return annotate(directory, outcome.audit(directory))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    modes = p.add_mutually_exclusive_group()
    modes.add_argument('--execute', type=Path); modes.add_argument('--audit', type=Path)
    modes.add_argument('--verify', type=Path)
    p.add_argument('--incumbent', type=Path); p.add_argument('--candidate', type=Path)
    p.add_argument('--challenges', nargs=2); p.add_argument('--output', type=Path)
    p.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    p.add_argument('--unlock-profile', default='all_unlocked_discovered_v1')
    p.add_argument('--action-seconds', type=float, default=1.5); p.add_argument('--retry-seconds', type=float, default=5)
    args = p.parse_args()
    if args.execute or args.audit:
        report = execute(args.execute) if args.execute else audit(args.audit)
        print(json.dumps({k: report[k] for k in ('scope', 'requested_attempts', 'recorded_attempts', 'audit_errors')}))
    elif args.verify:
        print(json.dumps({'registration_digest': verify(args.verify)[0]['registration_digest']}))
    else:
        if not all((args.incumbent, args.candidate, args.challenges, args.output)):
            p.error('Registration needs fixed incumbent/candidate roots, two challenges and a fresh output')
        registration = initialize(args)
        print(json.dumps({'registered': True, 'executed': False,
                          'registration_digest': registration['registration_digest']}))


if __name__ == '__main__':
    main()
