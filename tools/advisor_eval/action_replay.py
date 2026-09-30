#!/usr/bin/env python3
"""Register a source-legal visible shop alternative after a verified prefix.

This is a diagnostic action intervention, not a fitted policy or an ordinary
episode. It cannot promote defaults or qualify win rates. Original source checks
remain responsible for legality and all resolved effects.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import time

import decision_replay
import engine_probe
import paired_policy_audit as paired


def validate_intervention(value):
    if not isinstance(value, dict) or set(value) != {'step', 'action', 'card_key', 'reason'}:
        raise ValueError('Require step, action, card_key and preregistered reason')
    if type(value['step']) is not int or not 1 <= value['step'] <= 500:
        raise ValueError('Invalid boundary step')
    action = value['action']
    if not isinstance(action, dict) or action.get('kind') not in ('buy', 'open', 'leave_shop', 'reroll'):
        raise ValueError('Only visible shop buy/open/save/reroll interventions are supported')
    if action['kind'] in ('buy', 'open'):
        expected_area = 'shop_booster' if action['kind'] == 'open' else 'shop_jokers'
        if (set(action) != {'kind', 'area', 'index'} or action['area'] != expected_area or
                type(action['index']) is not int or action['index'] < 1 or
                not isinstance(value['card_key'], str) or not value['card_key']):
            raise ValueError('Require a concrete visible card index, area and key')
    elif set(action) != {'kind'} or value['card_key'] is not None:
        raise ValueError('Save/reroll have no selected card')
    if not isinstance(value['reason'], str) or not value['reason'].strip():
        raise ValueError('Require the hypothesis before execution')
    return value


def command_for(directory, manifest, registration, role):
    command = paired.command_for(directory, manifest, role, manifest['requests'][0])
    command += ['--replay-trace', str(directory / 'source.log'), '--replay-policy-root',
                str(directory / 'incumbent'), '--replay-until-step', str(registration['intervention']['step'])]
    if role == 'candidate':
        command += ['--override', str(directory / 'override.json')]
    return command


def verify_registration(directory):
    directory = Path(directory).resolve()
    manifest = paired.verify_manifest(directory)
    registration = json.loads((directory / 'action_registration.json').read_text(encoding='utf-8'))
    unsigned = dict(registration); claimed = unsigned.pop('registration_digest', None)
    if paired.digest(unsigned) != claimed or registration['manifest_digest'] != manifest['manifest_digest']:
        raise ValueError('Action registration changed')
    intervention = validate_intervention(registration['intervention'])
    if manifest['policies']['incumbent'] != manifest['policies']['candidate']:
        raise ValueError('Action intervention must hold policy constant')
    for name, key in (('source.log', 'source_trace_digest'), ('override.json', 'override_digest')):
        if paired.file_digest(directory / name) != registration[key]:
            raise ValueError('Registered action input changed: ' + name)
    if paired.file_digest(directory / 'action_workflow.py') != registration['workflow_digest']:
        raise ValueError('Frozen action workflow changed')
    if json.loads((directory / 'override.json').read_text()) != {key: intervention[key] for key in ('step', 'action')}:
        raise ValueError('Override differs from intervention')
    return manifest, registration


def audit(directory):
    directory = Path(directory).resolve()
    manifest, registration = verify_registration(directory)
    request = manifest['requests'][0]; intervention = registration['intervention']; records = {}
    replay = engine_probe.verified_replay(directory / 'source.log', directory / 'incumbent', manifest,
                                         request['challenge'], request['seed'], intervention['step'])
    for role in paired.ROLES:
        path = directory / (role + '_record.json')
        if not path.exists():
            records[role] = {'outcome': 'missing', 'reason': 'not_executed_or_wall_budget'}; continue
        record = json.loads(path.read_text()); trace = directory / (role + '.log')
        if (Path(record['trace']).resolve() != trace or paired.file_digest(trace) != record['trace_digest'] or
                record['command'][1:] != command_for(directory, manifest, registration, role)[1:]):
            raise ValueError('Trace or execution command changed: ' + role)
        actual = paired.episode_record(trace, request['challenge'], request['seed'], record['exit_code'],
                                       record['elapsed_seconds'], record['command'])
        provenance = actual['provenance']
        expected = {key: manifest[key] for key in ('rules_digest', 'runtime_digest', 'adapter_digest', 'start_distribution')}
        expected.update(manifest['policies'][role]); expected.update(request)
        if provenance and (any(provenance.get(k) != v for k, v in expected.items()) or
                           provenance.get('counterfactual') is not True or
                           provenance.get('replay', {}).get('source_trace_digest') != replay['source_trace_digest']):
            raise ValueError('Provenance mismatch: ' + role)
        item = decision_replay.checkpoint_result(actual, intervention['step']); checkpoint = item['checkpoint']
        if checkpoint and checkpoint['phase'] != 'shop':
            raise ValueError('Intervention checkpoint is outside the shop')
        if checkpoint and role == 'candidate':
            if checkpoint['action'] != intervention['action']:
                raise ValueError('Boundary did not apply the registered action')
            action = intervention['action']
            if intervention['card_key'] is not None:
                cards = checkpoint['snapshot'].get(action['area'], [])
                if action['index'] > len(cards) or cards[action['index'] - 1]['key'] != intervention['card_key']:
                    raise ValueError('Registered offered card identity differs at checkpoint')
        records[role] = item
    checkpoints = [records[role].get('checkpoint') for role in paired.ROLES]
    matched = (all(checkpoints) and checkpoints[0]['state_fingerprint'] == checkpoints[1]['state_fingerprint'] and
               all(records[role].get('verified_prefix_actions') == intervention['step'] - 1 for role in paired.ROLES))
    report = {'schema': 1, 'qualification': False, 'promotion_allowed': False,
              'registration_digest': registration['registration_digest'], 'intervention': intervention,
              'matched_checkpoint': bool(matched), 'requests': records,
              'interpretation': 'Selected source-verified action intervention; no learned policy, general win-rate or retry-time claim'}
    paired.write_json(directory / 'action_report.json', report)
    return report


def run(args):
    if not 0 < args.timeout <= 45 or not 0 < args.wall_budget <= 180:
        raise ValueError('Require timeout <=45s and wall budget <=180s')
    intervention = validate_intervention(json.loads(args.intervention.read_text(encoding='utf-8-sig')))
    rows, errors = paired.parse_trace(args.source_trace)
    origins = [row for row in rows if row.get('type') == 'engine_probe_provenance']
    if errors or len(origins) != 1:
        raise ValueError('Require a single valid source provenance record')
    request = {key: origins[0][key] for key in ('challenge', 'seed')}
    manifest = paired.initialize(args.output_dir, dict.fromkeys(paired.ROLES, args.source_policy_root),
                                 args.install, [request], args.timeout, None, 0)
    directory = args.output_dir.resolve(); shutil.copyfile(args.source_trace, directory / 'source.log')
    replay = engine_probe.verified_replay(directory / 'source.log', directory / 'incumbent', manifest,
                                         request['challenge'], request['seed'], intervention['step'])
    paired.write_json(directory / 'override.json', {key: intervention[key] for key in ('step', 'action')})
    registration = {'schema': 1, 'qualification': False, 'manifest_digest': manifest['manifest_digest'],
                    'source_trace_digest': replay['source_trace_digest'], 'intervention': intervention,
                    'override_digest': paired.file_digest(directory / 'override.json'),
                    'workflow_digest': paired.file_digest(__file__), 'timeout_seconds': args.timeout,
                    'wall_budget_seconds': args.wall_budget, 'executed': args.execute}
    registration['registration_digest'] = paired.digest(registration)
    paired.write_json(directory / 'action_registration.json', registration)
    shutil.copyfile(__file__, directory / 'action_workflow.py')
    deadline = time.perf_counter() + args.wall_budget
    for role in paired.ROLES:
        if args.execute and time.perf_counter() + args.timeout <= deadline:
            record = paired.collect(command_for(directory, manifest, registration, role), directory / (role + '.log'),
                                    request, args.timeout)
            paired.write_json(directory / (role + '_record.json'), record)
    paired.verify_manifest(directory, verify_install=True)
    return audit(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit', type=Path)
    parser.add_argument('--source-trace', type=Path)
    parser.add_argument('--source-policy-root', type=Path)
    parser.add_argument('--intervention', type=Path)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--timeout', type=float, default=35)
    parser.add_argument('--wall-budget', type=float, default=90)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    try:
        if args.audit:
            report = audit(args.audit); directory = args.audit
        else:
            if not all((args.source_trace, args.source_policy_root, args.intervention, args.output_dir)):
                raise ValueError('Require source-trace, source-policy-root, intervention and output-dir')
            report = run(args); directory = args.output_dir
    except (ValueError, KeyError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({'report': str((directory / 'action_report.json').resolve()),
                      'matched_checkpoint': report['matched_checkpoint'],
                      'outcomes': {key: value['outcome'] for key, value in report['requests'].items()}}, indent=2))
    return 0 if not args.execute or report['matched_checkpoint'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
