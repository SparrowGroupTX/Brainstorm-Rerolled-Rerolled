#!/usr/bin/env python3
"""Screen frozen numeric variants only at meaningful source-verified decisions.

Action sensitivity admits a later outcome experiment; it never establishes that
the changed action is better. This tool does not install or promote defaults.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time

import calibrate_policy as coefficients
import decision_replay
import engine_probe
import paired_policy_audit as paired


def meaningful_checkpoint(rows, step):
    boundaries = [r for r in rows if r.get('step') == step and r.get('type') == 'engine_episode_checkpoint']
    if len(boundaries) != 1:
        raise ValueError('Require one full recorded decision checkpoint, not an opening action prefix')
    point = boundaries[0]
    state, result = point.get('snapshot'), point.get('result')
    if not isinstance(state, dict) or not isinstance(result, dict) or not isinstance(point.get('action'), dict):
        raise ValueError('Checkpoint must retain observation, complete result and action')
    if result.get('truncated') or result.get('uncertain') or (result.get('shop_diagnostics') or {}).get('truncated'):
        raise ValueError('Incomplete or uncertain decision cannot calibrate a coefficient')
    phase = point.get('phase')
    if phase == 'shop' and any(state.get(key) for key in ('shop_jokers', 'shop_vouchers', 'shop_booster')):
        return 'reroll' if point['action'].get('kind') == 'reroll' else 'shop'
    if phase == 'pack' and len(state.get('pack_cards') or []) >= 2:
        pack = result.get('pack_diagnostics') or {}
        if pack.get('incomplete') or pack.get('tactical_fallback'):
            raise ValueError('Incomplete pack comparison cannot calibrate a coefficient')
        return 'pack'
    if phase == 'hand' and (result.get('growth') or result.get('growth_diagnostics')):
        return 'growth'
    raise ValueError('Action-insensitive opening/empty decision: require revealed shop, pack or evaluated growth')


def source_cases(path, baseline):
    cases = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    if not isinstance(cases, list) or not 1 <= len(cases) <= 4:
        raise ValueError('Register one to four meaningful decision checkpoints')
    result, names, seeds = [], set(), {}
    for case in cases:
        if not isinstance(case, dict) or set(case) != {'name', 'trace', 'step', 'split'}:
            raise ValueError('Checkpoint requires only name, trace, step and split')
        name = case['name']
        if not isinstance(name, str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,29}', name) or name in names:
            raise ValueError('Use unique simple checkpoint names')
        if case['split'] not in ('development', 'holdout') or type(case['step']) is not int or not 1 <= case['step'] <= 500:
            raise ValueError('Checkpoint requires development/holdout split and integer step 1..500')
        trace = Path(case['trace']).resolve()
        rows, errors = paired.parse_trace(trace)
        origins = [r for r in rows if r.get('type') == 'engine_probe_provenance']
        if errors or len(origins) != 1:
            raise ValueError('Checkpoint source has malformed or ambiguous provenance')
        origin = origins[0]
        if origin.get('policy_files') != baseline['policy_files'] or origin.get('policy_digest') != baseline['policy_digest']:
            raise ValueError('Every checkpoint must come from the registered frozen baseline')
        profile = origin.get('profile_spec')
        if not profile or profile != engine_probe.profile_spec(profile.get('name')):
            raise ValueError('Require a fresh checkpoint with an explicit source-defined profile')
        identity = (origin['challenge'], origin['seed'])
        if identity in seeds and seeds[identity] != case['split']:
            raise ValueError('Development and holdout cannot reuse a challenge/seed trajectory')
        seeds[identity] = case['split'];names.add(name)
        kind = meaningful_checkpoint(rows, case['step'])
        point = next(r for r in rows if r.get('type') == 'engine_episode_checkpoint' and r.get('step') == case['step'])
        result.append({**case, 'trace': str(trace), 'trace_digest': paired.file_digest(trace),
                       'kind': kind, 'challenge': identity[0], 'seed': identity[1],
                       'profile_spec': profile, 'coefficient_opportunities': coefficient_opportunities(point),
                       'opportunity_scope': 'nonzero_effect_counters' if 'coefficient_opportunities' in
                           ((point['result'].get('shop_diagnostics') or {}).get('metrics') or {}) else
                           'legacy_completed_comparison_or_decision_diagnostics_not_nonzero_effect_proof'})
    return result


def coefficient_opportunities(point):
    result = point.get('result') or {};opportunities = []
    metrics = (result.get('shop_diagnostics') or {}).get('metrics') or {}
    if 'coefficient_opportunities' in metrics:
        opportunities.extend(key for key in ('shop_scoring_gain_weight', 'computation_cost_scale')
                             if metrics['coefficient_opportunities'].get(key, 0) > 0)
    elif metrics.get('paired_comparisons', 0) > 0:
        opportunities.extend(('shop_scoring_gain_weight', 'computation_cost_scale'))
    if (result.get('strategy') or {}).get('reroll_forecast'):
        opportunities.append('reroll_min_target_gain')
    if result.get('growth') or result.get('growth_diagnostics'):
        opportunities.extend(('growth_action_cost', 'growth_utility_scale'))
    if result.get('discard') and result.get('play') and not result.get('fast_clear'):
        opportunities.append('discard_action_penalty')
    return opportunities


def initialize(args):
    if not 0 < args.timeout <= 30 or not 0 < args.wall_budget <= 180:
        raise ValueError('Require checkpoint timeout <=30s and total wall budget <=180s')
    directory = args.output_dir.resolve();directory.mkdir(parents=True, exist_ok=False)
    baseline = paired.freeze_product(args.policy_root, directory / 'baseline')
    source = (directory / 'baseline' / coefficients.REGISTRY).read_text(encoding='utf-8')
    spec, defaults = coefficients.registry_spec(source), coefficients.read_values(source)
    grid = coefficients.validate_grid(json.loads(args.grid.read_text(encoding='utf-8-sig')), defaults, spec['bounds'])
    cases = source_cases(args.checkpoints, baseline)
    for variant in grid:
        changed = {key for key, value in variant['values'].items() if value != defaults[key]}
        for case in cases:
            if not changed.intersection(case['coefficient_opportunities']):
                raise ValueError('No recorded coefficient opportunity for ' + variant['name'] + ' at ' + case['name'])
    pairs = []
    for variant in grid:
        root = directory / 'variants' / variant['name']
        paired.freeze_product(directory / 'baseline', root)
        (root / coefficients.REGISTRY).write_text(coefficients.apply_values(source, variant['values']), encoding='utf-8')
        for case in cases:
            pair = directory / 'pairs' / variant['name'] / case['name']
            decision_replay.run(argparse.Namespace(source_trace=Path(case['trace']), source_policy_root=directory / 'baseline',
                candidate_root=root, step=case['step'], output_dir=pair, install=args.install, timeout=args.timeout,
                wall_budget=args.wall_budget, full_episode=False, evaluate_prefix=False, execute=False))
            coefficients.activation_check(pair / 'candidate', pair / 'adapter')
            manifest = paired.verify_manifest(pair)
            pairs.append({'candidate': variant['name'], 'case': case['name'], 'directory': str(pair),
                          'manifest_digest': manifest['manifest_digest'], 'adapter_digest': manifest['adapter_digest']})
    if len({pair['adapter_digest'] for pair in pairs}) != 1:
        raise ValueError('Adapter changed during registration; preserve this incomplete output and use a fresh stable input')
    screen = {'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(), 'baseline': baseline,
              'registry_spec': spec, 'default_values': defaults, 'candidates': grid, 'cases': cases, 'pairs': pairs,
              'wall_budget_seconds': args.wall_budget, 'execution_requested': args.execute,
              'workflow_digest': paired.file_digest(__file__), 'promotion_allowed': False,
              'qualification': False, 'scope': 'source-verified decision sensitivity, not outcome fitting'}
    screen['screen_digest'] = paired.digest(screen)
    paired.write_json(directory / 'checkpoint_screen.json', screen)
    return screen


def verify(directory):
    directory = Path(directory).resolve()
    screen = json.loads((directory / 'checkpoint_screen.json').read_text(encoding='utf-8'))
    unsigned = dict(screen);claimed = unsigned.pop('screen_digest', None)
    if claimed != paired.digest(unsigned):
        raise ValueError('Registered checkpoint screen changed')
    if paired.policy_hashes(directory / 'baseline') != screen['baseline']['policy_files']:
        raise ValueError('Frozen checkpoint baseline changed')
    candidates = {r['name']: r for r in screen['candidates']}
    for entry in screen['pairs']:
        pair = Path(entry['directory']).resolve()
        if pair != directory / 'pairs' / entry['candidate'] / entry['case']:
            raise ValueError('Checkpoint pair escaped registration')
        manifest = paired.verify_manifest(pair)
        if manifest['manifest_digest'] != entry['manifest_digest'] or manifest['policies']['incumbent'] != screen['baseline']:
            raise ValueError('Checkpoint pair registration differs')
        expected, actual = screen['baseline']['policy_files'], manifest['policies']['candidate']['policy_files']
        if {k for k in set(expected) | set(actual) if expected.get(k) != actual.get(k)} != {coefficients.REGISTRY}:
            raise ValueError('Checkpoint variant changed non-coefficient code')
        if coefficients.read_values((pair / 'candidate' / coefficients.REGISTRY).read_text()) != candidates[entry['candidate']]['values']:
            raise ValueError('Checkpoint variant values changed')
        coefficients.activation_check(pair / 'candidate', pair / 'adapter')
    return screen


def classify_pair(report):
    if not report['matched_checkpoint']:
        return 'unresolved'
    for role in paired.ROLES:
        point = report['requests'][role]['checkpoint']
        try:
            meaningful_checkpoint([point], point['step'])
        except ValueError:
            return 'unsupported_or_incomplete'
    return 'action_sensitive' if report['actions_differ'] else 'action_insensitive'


def audit(directory):
    directory = Path(directory).resolve();screen = verify(directory)
    cases = {r['name']: r for r in screen['cases']};rows = []
    for entry in screen['pairs']:
        report = decision_replay.audit(entry['directory'])
        rows.append({'candidate': entry['candidate'], 'case': entry['case'], 'split': cases[entry['case']]['split'],
                     'challenge': cases[entry['case']]['challenge'], 'kind': cases[entry['case']]['kind'],
                     'status': classify_pair(report), 'requests': report['requests'], 'actions_differ': report['actions_differ']})
    candidate_rows = []
    for candidate in screen['candidates']:
        items = [r for r in rows if r['candidate'] == candidate['name']]
        development = [r for r in items if r['split'] == 'development']
        changed = [r['case'] for r in development if r['status'] == 'action_sensitive']
        unresolved = any(r['status'] in ('unresolved', 'unsupported_or_incomplete') for r in items)
        status = ('incomplete' if unresolved else 'eligible_for_bounded_outcome_comparison' if changed else
                  'rejected_action_insensitive' if development else 'holdout_only_no_selection')
        candidate_rows.append({'name': candidate['name'], 'status': status, 'changed_development_cases': changed,
                               'values': candidate['values'], 'recommended': False})
    report = {'schema': 1, 'screen_digest': screen['screen_digest'], 'candidates': candidate_rows, 'pairs': rows,
              'promotion_allowed': False, 'qualification': False, 'qualified_win_rate': None, 'recommended_policy': None,
              'limitations': ['A changed action proves sensitivity, not improvement',
                 'Holdout trajectories remain separate and cannot select this screen\'s candidates',
                 'Errors/timeouts/unsupported/missing attempts remain unresolved; no repeat or continuation is automatic',
                 'Use fresh registered bounded continuations for eligible cases, then separate unseen terminal evaluation',
                 'Declared source profiles do not establish the user population or qualify the entire adapter']}
    paired.write_json(directory / 'checkpoint_calibration_report.json', report)
    return report


def execute(directory):
    directory = Path(directory).resolve();screen = verify(directory)
    if not screen['execution_requested']:
        raise ValueError('Checkpoint screen was registered without execution')
    # A durable lease forbids a retry from silently renewing this cumulative cap.
    with (directory / 'execution_started.json').open('x', encoding='utf-8') as handle:
        json.dump({'started_utc': datetime.now(timezone.utc).isoformat(), 'screen_digest': screen['screen_digest']}, handle)
    deadline = time.perf_counter() + screen['wall_budget_seconds']
    for index, entry in enumerate(screen['pairs']):
        pair = Path(entry['directory']);manifest = paired.verify_manifest(pair, verify_install=True)
        if time.perf_counter() + 2 * manifest['timeout_seconds'] > deadline:
            break
        report = decision_replay.audit(pair)
        for role in paired.ROLES if index % 2 == 0 else reversed(paired.ROLES):
            record = paired.collect(report['commands'][role], pair / (role + '.log'), manifest['requests'][0], manifest['timeout_seconds'])
            paired.write_json(pair / (role + '_record.json'), record)
        audit(directory)
    return audit(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit', type=Path)
    parser.add_argument('--policy-root', type=Path)
    parser.add_argument('--checkpoints', type=Path)
    parser.add_argument('--grid', type=Path)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--timeout', type=float, default=10)
    parser.add_argument('--wall-budget', type=float, default=90)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    try:
        if args.audit:
            report = audit(args.audit)
        else:
            if not all((args.policy_root, args.checkpoints, args.grid, args.output_dir)):
                raise ValueError('Require policy-root, checkpoints, grid and fresh output-dir')
            initialize(args);report = execute(args.output_dir) if args.execute else audit(args.output_dir)
    except (ValueError, KeyError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({'promotion_allowed': False, 'candidates': report['candidates']}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
