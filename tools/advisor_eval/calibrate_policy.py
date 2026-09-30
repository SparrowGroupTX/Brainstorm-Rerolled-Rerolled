#!/usr/bin/env python3
"""Bounded CPU development screening of applied, frozen policy coefficients.

This never installs or promotes a candidate. Experimental adapter results and
prefix latency cannot establish win rates or real completion time.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import time

import paired_policy_audit as paired

REGISTRY = 'Brainstorm/Advisor/policy_weights.lua'
BOUNDS = {'growth_action_cost': (0, 12), 'growth_utility_scale': (.5, 1.5), 'discard_action_penalty': (0, .2)}
BLOCK = re.compile(r'(-- POLICY_WEIGHTS_BEGIN\s*\n)local VALUES=\{(.*?)\}\s*\n(-- POLICY_WEIGHTS_END)', re.S)
ENTRY = re.compile(r'\s*([a-z_]+)\s*=\s*([0-9.eE+-]+)\s*,\s*')


def validate_values(values, complete=True, bounds=None):
    bounds = BOUNDS if bounds is None else bounds
    if not isinstance(values, dict) or set(values) - bounds.keys() or complete and set(values) != set(bounds):
        raise ValueError('Unknown or missing policy coefficients')
    for key, value in values.items():
        if type(value) not in (int, float) or not math.isfinite(value) or not bounds[key][0] <= value <= bounds[key][1]:
            raise ValueError('Out-of-range policy coefficient: ' + key)
    return dict(values)


def registry_spec(source):
    header = re.search(r"local M=\{schema=(\d+),version='([0-9]+\.[0-9]+)'\}", source)
    if not header or (int(header[1]), header[2]) not in ((1, '1.0'), (2, '2.0')):
        raise ValueError('Unsupported policy coefficient schema')
    found = re.findall(r'local bounds=\{(.*?)\}\s*-- POLICY_WEIGHTS_BEGIN', source, re.S)
    if len(found) != 1:
        raise ValueError('Require exactly one declared coefficient bounds table')
    remaining = found[0];bounds = {}
    entry = re.compile(r'\s*([a-z_]+)\s*=\s*\{\s*([0-9.eE+-]+)\s*,\s*([0-9.eE+-]+)\s*\}\s*,?\s*')
    while remaining.strip():
        match = entry.match(remaining)
        if not match or match[1] in bounds:
            raise ValueError('Invalid or duplicate declared coefficient bounds')
        low, high = float(match[2]), float(match[3])
        if not math.isfinite(low) or not math.isfinite(high) or low >= high:
            raise ValueError('Invalid declared coefficient range')
        bounds[match[1]] = (low, high);remaining = remaining[match.end():]
    if not bounds or len(bounds) > 30:
        raise ValueError('Require one to thirty bounded policy coefficients')
    return {'schema': int(header[1]), 'version': header[2], 'bounds': bounds}


def read_values(source):
    spec = registry_spec(source)
    blocks = list(BLOCK.finditer(source))
    if len(blocks) != 1:
        raise ValueError('Require exactly one delimited policy coefficient block')
    remaining = blocks[0].group(2);values = {}
    while remaining.strip():
        entry = ENTRY.match(remaining)
        if not entry or entry[1] in values:
            raise ValueError('Invalid or duplicate policy coefficient')
        values[entry[1]] = float(entry[2]);remaining = remaining[entry.end():]
    return validate_values(values, bounds=spec['bounds'])


def apply_values(source, values):
    read_values(source);bounds = registry_spec(source)['bounds'];validate_values(values, bounds=bounds)
    body = 'local VALUES={\n' + ''.join(f'  {key}={values[key]:.17g},\n' for key in bounds) + '}\n'
    return BLOCK.sub(lambda m: m[1] + body + m[3], source)


def validate_grid(grid, defaults, bounds=None):
    bounds = BOUNDS if bounds is None else bounds
    if not isinstance(grid, list) or not 1 <= len(grid) <= 6:
        raise ValueError('Require one to six registered candidates')
    names, vectors, result = set(), set(), []
    for candidate in grid:
        if not isinstance(candidate, dict) or set(candidate) != {'name', 'values'}:
            raise ValueError('Each candidate requires only name and values')
        name = candidate['name']
        if not isinstance(name, str) or not re.fullmatch(r'[a-z][a-z0-9_]{0,29}', name) or name in names:
            raise ValueError('Use unique simple candidate names')
        values = {**defaults, **validate_values(candidate['values'], complete=False, bounds=bounds)}
        vector = tuple(values[key] for key in bounds)
        if vector in vectors or values == defaults:
            raise ValueError('Candidate vectors must be distinct and change a coefficient')
        names.add(name);vectors.add(vector);result.append({'name': name, 'values': values})
    return result


def activation_check(root, adapter):
    # Source activation is mandatory. Merely recording unused option metadata
    # cannot count as testing a candidate policy.
    for relative, tokens in {
        'Brainstorm/Advisor/runtime.lua': ('policy_weights',),
        'Brainstorm/Advisor/growth.lua': ('policy_weights', 'growth_action_cost', 'growth_utility_scale'),
        'Brainstorm/Advisor/search.lua': ('policy_weights', 'discard_action_penalty'),
    }.items():
        source = (Path(root) / relative).read_text(encoding='utf-8')
        if any(token not in source for token in tokens):
            raise ValueError('Policy coefficient not activated in ' + relative)
    if 'probe_policy_policy_weights' not in (Path(adapter) / 'engine_run.lua').read_text(encoding='utf-8'):
        raise ValueError('Experimental engine has not loaded the policy coefficient registry')
    registry = Path(root) / REGISTRY
    declared = read_values(registry.read_text(encoding='utf-8')) if registry.exists() else {}
    for key, filename in {'shop_scoring_gain_weight': 'shop_scoring.lua',
                          'computation_cost_scale': 'shop_scoring.lua',
                          'reroll_min_target_gain': 'paid_reroll.lua'}.items():
        if key in declared:
            source = (Path(root) / 'Brainstorm/Advisor' / filename).read_text(encoding='utf-8')
            if key not in source or 'policy_weights' not in source:
                raise ValueError('Policy coefficient not activated in ' + filename + ': ' + key)


def initialize(args):
    requests = [{'challenge': c, 'seed': s} for c in args.challenges for s in args.seeds]
    if not 1 <= len(requests) <= 4:
        raise ValueError('A calibration screen permits one to four paired challenge/seed requests')
    if not 0 < args.wall_budget <= 180 or not 0 < args.timeout <= 45:
        raise ValueError('Require wall budget <=180s and per-attempt timeout <=45s')
    directory = args.output_dir.resolve();directory.mkdir(parents=True, exist_ok=False)
    baseline = paired.freeze_product(args.policy_root, directory / 'baseline')
    source = (directory / 'baseline' / REGISTRY).read_text(encoding='utf-8')
    defaults = read_values(source)
    spec = registry_spec(source)
    grid = validate_grid(json.loads(args.grid.read_text(encoding='utf-8')), defaults, bounds=spec['bounds'])
    candidates = []
    for candidate in grid:
        variant = directory / 'variants' / candidate['name']
        paired.freeze_product(directory / 'baseline', variant)
        (variant / REGISTRY).write_text(apply_values(source, candidate['values']), encoding='utf-8')
        pair = directory / 'pairs' / candidate['name']
        manifest = paired.initialize(pair, {'incumbent': directory / 'baseline', 'candidate': variant},
                                     args.install, requests, args.timeout,
                                     None if args.full_episode else args.stop_after_step, args.retry_overhead_seconds)
        activation_check(pair / 'candidate', pair / 'adapter')
        candidates.append({**candidate, 'manifest_digest': manifest['manifest_digest'],
                           'adapter_digest': manifest['adapter_digest'], 'pair_directory': str(pair)})
    if len({candidate['adapter_digest'] for candidate in candidates}) != 1:
        raise ValueError('Adapter changed while registering candidates; start a fresh stable screen')
    screen = {'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
              'workflow_digest': paired.file_digest(__file__), 'qualification': False,
              'baseline': baseline, 'coefficient_schema': spec['schema'], 'default_values': defaults,
              'requests': requests, 'candidates': candidates, 'wall_budget_seconds': args.wall_budget,
              'execution_requested': args.execute, 'promotion_allowed': False,
              'scope': 'bounded paired CPU development screen; no live timing or policy promotion'}
    screen['screen_digest'] = paired.digest(screen)
    paired.write_json(directory / 'screen.json', screen)
    return screen


def verify(directory):
    directory = Path(directory).resolve()
    screen = json.loads((directory / 'screen.json').read_text(encoding='utf-8'))
    unsigned = dict(screen);claimed = unsigned.pop('screen_digest', None)
    if paired.digest(unsigned) != claimed:
        raise ValueError('Registered calibration screen changed')
    if paired.policy_hashes(directory / 'baseline') != screen['baseline']['policy_files']:
        raise ValueError('Frozen calibration baseline changed')
    for candidate in screen['candidates']:
        pair = Path(candidate['pair_directory'])
        if pair.resolve() != directory / 'pairs' / candidate['name']:
            raise ValueError('Candidate escaped its registered screen')
        manifest = paired.verify_manifest(pair)
        if manifest['manifest_digest'] != candidate['manifest_digest'] or manifest['requests'] != screen['requests']:
            raise ValueError('Candidate registration mismatch')
        if manifest['policies']['incumbent'] != screen['baseline']:
            raise ValueError('Candidate compared against a different incumbent')
        actual = manifest['policies']['candidate']['policy_files']
        expected = screen['baseline']['policy_files']
        if {key for key in set(actual) | set(expected) if actual.get(key) != expected.get(key)} != {REGISTRY}:
            raise ValueError('A calibration candidate changed non-coefficient policy code')
        if read_values((pair / 'candidate' / REGISTRY).read_text(encoding='utf-8')) != candidate['values']:
            raise ValueError('Frozen values differ from registered candidate')
        activation_check(pair / 'candidate', pair / 'adapter')
    return screen


def summarize(directory):
    screen = verify(directory);rows = []
    for candidate in screen['candidates']:
        report = paired.audit(candidate['pair_directory'])
        differences = [cohort['diagnostic_candidate_minus_incumbent_seconds'] for cohort in report['cohorts']]
        terminal_diagnostic = sum(differences) if differences and all(v is not None for v in differences) else None
        rows.append({'name': candidate['name'], 'values': candidate['values'], 'blockers': report['blockers'],
                     'audit_errors': report['audit_errors'], 'valid_records': report['valid_records'],
                     'cohorts': report['cohorts'], 'paired_prefix_latency_diagnostics': report['paired_prefix_latency_diagnostics'],
                     'diagnostic_sum_challenge_retry_proxy_delta_seconds': terminal_diagnostic,
                     'qualified_win_rate': None})
    result = {'schema': 1, 'screen_digest': screen['screen_digest'], 'qualification': False,
              'promotion_allowed': False, 'recommended_policy': None, 'default_values': screen['default_values'],
              'candidates': rows, 'expected_time_all_20_challenges': None,
              'limitations': ['The source adapter is experimental and uses development seeds',
                              'Each challenge remains separate; missing/censored/error attempts are never wins or losses',
                              'Terminal diagnostics include failures but omit real user action and restart timing',
                              'No candidate is installed, promoted or accepted as calibrated by this tool']}
    paired.write_json(Path(directory) / 'calibration_report.json', result)
    return result


def execute(directory):
    screen = verify(directory)
    if not screen['execution_requested']:
        raise ValueError('Screen was registered without execution')
    deadline = time.perf_counter() + screen['wall_budget_seconds']
    # Complete a paired request before moving to the next candidate, with AB/BA
    # alternating across requests. Existing output cannot be silently repeated.
    for index, request in enumerate(screen['requests']):
        for candidate in screen['candidates']:
            pair = Path(candidate['pair_directory']);manifest = paired.verify_manifest(pair, verify_install=True)
            if time.perf_counter() + 2 * manifest['timeout_seconds'] > deadline:
                return summarize(directory)
            for role in paired.ROLES if index % 2 == 0 else tuple(reversed(paired.ROLES)):
                record = paired.collect(paired.command_for(pair, manifest, role, request),
                                        pair / f'{index:03d}_{role}.log', request, manifest['timeout_seconds'])
                record.update({'pair_index': index, 'role': role})
                with (pair / 'episodes.jsonl').open('a', encoding='utf-8') as output:
                    output.write(json.dumps(record, allow_nan=False) + '\n')
                print(json.dumps({'candidate': candidate['name'], **{k: record[k] for k in
                                  ('role', 'challenge', 'seed', 'outcome', 'elapsed_seconds')}}), flush=True)
            summarize(directory)
    return summarize(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit', type=Path)
    parser.add_argument('--policy-root', type=Path)
    parser.add_argument('--grid', type=Path)
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    parser.add_argument('--challenges', nargs='+', default=['c_omelette_1'])
    parser.add_argument('--seeds', nargs='+', default=['COEFFICIENTSCREEN1'])
    parser.add_argument('--stop-after-step', type=int, default=3)
    parser.add_argument('--full-episode', action='store_true')
    parser.add_argument('--timeout', type=float, default=20)
    parser.add_argument('--wall-budget', type=float, default=90)
    parser.add_argument('--retry-overhead-seconds', type=float, default=0)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    try:
        if args.audit:
            result = summarize(args.audit);directory = args.audit
        else:
            if not args.policy_root or not args.grid or not args.output_dir:
                raise ValueError('Require policy-root, grid and output-dir when registering a screen')
            initialize(args);directory = args.output_dir
            result = execute(directory) if args.execute else summarize(directory)
    except (ValueError, KeyError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({'report': str((directory / 'calibration_report.json').resolve()),
                      'promotion_allowed': result['promotion_allowed'],
                      'candidates': [{'name': row['name'], 'valid_records': row['valid_records'], 'blockers': row['blockers']}
                                     for row in result['candidates']]}, indent=2))
    return 2 if any(row['audit_errors'] for row in result['candidates']) else 0


if __name__ == '__main__':
    raise SystemExit(main())
