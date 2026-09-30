#!/usr/bin/env python3
"""Freeze and compare candidate decisions after a verified original-source prefix.

The prefix follows recorded baseline actions, so this is counterfactual
development evidence, never an ordinary policy episode or qualification.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import time

import engine_probe
import paired_policy_audit as paired


def checkpoint_result(record, boundary):
    rows, errors = paired.parse_trace(record['trace'])
    checkpoints = [row for row in rows if row.get('type') == 'engine_episode_checkpoint' and row.get('step') == boundary]
    verified = [row for row in rows if row.get('type') == 'engine_episode_replay_verified']
    profiles = [row for row in rows if row.get('type') == 'engine_episode_profile']
    return {'outcome': record['outcome'], 'reason': record['reason'], 'elapsed_seconds': record['elapsed_seconds'],
            'trace': record['trace'], 'trace_digest': record['trace_digest'],
            'checkpoint': checkpoints[0] if len(checkpoints) == 1 else None,
            'verified_prefix_actions': len(verified),
            'skipped_advisor_decisions': sum(row.get('advisor_skipped') is True for row in profiles),
            'decision_metrics': record['decision_metrics'], 'parse_errors': errors,
            'provenance': record['provenance'], 'terminal': record['terminal']}


def command_for(directory, manifest, registration, role):
    command = paired.command_for(directory, manifest, role, manifest['requests'][0])
    command += ['--replay-trace', str(directory / 'source.log'), '--replay-policy-root', str(directory / 'incumbent'),
                '--replay-until-step', str(registration['boundary_step'])]
    if not registration['full_episode_requested']:
        command += ['--stop-at-replay-decision']
    if registration['evaluate_prefix']:
        command += ['--replay-evaluate-prefix']
    return command


def audit(directory):
    directory = Path(directory).resolve()
    manifest = paired.verify_manifest(directory)
    registration = json.loads((directory / 'decision_registration.json').read_text(encoding='utf-8'))
    unsigned = dict(registration);claimed = unsigned.pop('registration_digest', None)
    if paired.digest(unsigned) != claimed or registration['manifest_digest'] != manifest['manifest_digest']:
        raise ValueError('Decision registration changed')
    if paired.file_digest(directory / 'source.log') != registration['source_trace_digest']:
        raise ValueError('Replay source trace changed')
    request = manifest['requests'][0]
    replay = engine_probe.verified_replay(directory / 'source.log', directory / 'incumbent', manifest,
                                         request['challenge'], request['seed'], registration['boundary_step'])
    records, commands = {}, {}
    for role in paired.ROLES:
        commands[role] = command_for(directory, manifest, registration, role)
        record_path = directory / (role + '_record.json')
        if not record_path.exists():
            continue
        record = json.loads(record_path.read_text(encoding='utf-8'))
        trace = directory / (role + '.log')
        if (Path(record['trace']).resolve() != trace or paired.file_digest(trace) != record['trace_digest'] or
                record['command'][1:] != commands[role][1:]):
            raise ValueError('Decision trace or execution command changed: ' + role)
        actual = paired.episode_record(trace, request['challenge'], request['seed'], record['exit_code'],
                                       record['elapsed_seconds'], record['command'])
        expected = {key: manifest[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest', 'start_distribution')}
        expected.update(manifest['policies'][role])
        expected.update(request)
        if manifest.get('profile_spec'):
            expected.update({key: manifest[key] for key in ('profile_spec', 'profile_spec_digest')})
        provenance = actual['provenance']
        # Launch errors/timeouts before provenance remain explicit failed requests.
        if provenance and (any(provenance.get(key) != value for key, value in expected.items()) or
                           provenance.get('replay', {}).get('source_trace_digest') != replay['source_trace_digest'] or
                           provenance.get('counterfactual') is not True):
            raise ValueError('Decision trace provenance mismatch: ' + role)
        records[role] = checkpoint_result(actual, registration['boundary_step'])
    checkpoints = [records.get(role, {}).get('checkpoint') for role in paired.ROLES]
    matched = (all(checkpoints) and all(records[role]['verified_prefix_actions'] == registration['boundary_step'] - 1 for role in paired.ROLES)
               and all(records[role]['outcome'] in ('censored', 'win', 'loss') for role in paired.ROLES)
               and checkpoints[0]['state_fingerprint'] == checkpoints[1]['state_fingerprint'])
    report = {'schema': 1, 'qualification': False, 'promotion_allowed': False,
              'registration_digest': registration['registration_digest'], 'commands': commands,
              'requests': {role: records.get(role, {'outcome': 'missing', 'reason': 'not_executed_or_wall_budget'})
                           for role in paired.ROLES},
              'matched_checkpoint': bool(matched),
              'actions_differ': checkpoints[0]['action'] != checkpoints[1]['action'] if matched else None,
              'interpretation': 'Recorded baseline prefix, source-verified counterfactual decisions; no population win-rate or retry-time claim'}
    paired.write_json(directory / 'decision_report.json', report)
    return report


def run(args):
    if not 0 < args.timeout <= 45 or not 0 < args.wall_budget <= 180:
        raise ValueError('Require per-attempt timeout <=45s and total wall budget <=180s')
    rows, errors = paired.parse_trace(args.source_trace)
    if errors:
        raise ValueError('Malformed source trace')
    origins = [row for row in rows if row.get('type') == 'engine_probe_provenance']
    if len(origins) != 1:
        raise ValueError('Source trace needs exactly one provenance record')
    origin = origins[0]
    request = {key: origin[key] for key in ('challenge', 'seed')}
    manifest = paired.initialize(args.output_dir,
        {'incumbent': args.source_policy_root, 'candidate': args.candidate_root}, args.install,
        [request], args.timeout, None, 0, unlock_profile=(origin.get('profile_spec') or {}).get('name'))
    directory = args.output_dir.resolve()
    source_trace = directory / 'source.log'
    shutil.copyfile(args.source_trace, source_trace)
    replay = engine_probe.verified_replay(source_trace, directory / 'incumbent', manifest,
                                         request['challenge'], request['seed'], args.step)
    registration = {'schema': 1, 'qualification': False, 'manifest_digest': manifest['manifest_digest'],
                    'source_trace_digest': replay['source_trace_digest'], 'boundary_step': args.step,
                    'full_episode_requested': args.full_episode, 'evaluate_prefix': args.evaluate_prefix,
                    'wall_budget_seconds': args.wall_budget, 'timeout_seconds': args.timeout,
                    'workflow_digest': paired.file_digest(__file__), 'executed': args.execute}
    registration['registration_digest'] = paired.digest(registration)
    paired.write_json(directory / 'decision_registration.json', registration)
    deadline = time.perf_counter() + args.wall_budget
    for role in paired.ROLES:
        command = command_for(directory, manifest, registration, role)
        if args.execute and time.perf_counter() + args.timeout <= deadline:
            record = paired.collect(command, directory / (role + '.log'), request, args.timeout)
            paired.write_json(directory / (role + '_record.json'), record)
    # Recheck all frozen bytes and source trace after running both candidates.
    paired.verify_manifest(directory, verify_install=True)
    if paired.file_digest(source_trace) != replay['source_trace_digest']:
        raise ValueError('Replay source trace changed during comparison')
    return audit(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit', type=Path)
    parser.add_argument('--source-trace', type=Path)
    parser.add_argument('--source-policy-root', type=Path)
    parser.add_argument('--candidate-root', type=Path)
    parser.add_argument('--step', type=int)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--timeout', type=float, default=15)
    parser.add_argument('--wall-budget', type=float, default=90)
    parser.add_argument('--full-episode', action='store_true')
    parser.add_argument('--evaluate-prefix', action='store_true', help='Diagnostic parity and latency comparator; source policy actions must match')
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    try:
        if args.audit:
            report = audit(args.audit);args.output_dir = args.audit
        else:
            if not all((args.source_trace, args.source_policy_root, args.candidate_root, args.step, args.output_dir)):
                raise ValueError('Require source-trace, source-policy-root, candidate-root, step and output-dir')
            report = run(args)
    except (ValueError, KeyError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({'report': str((args.output_dir / 'decision_report.json').resolve()),
                      'matched_checkpoint': report['matched_checkpoint'], 'actions_differ': report['actions_differ'],
                      'outcomes': {key: value['outcome'] for key, value in report['requests'].items()}}, indent=2))
    return 0 if not args.execute or report['matched_checkpoint'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
