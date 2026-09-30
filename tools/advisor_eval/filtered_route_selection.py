#!/usr/bin/env python3
"""Reaudit retained-engine cohorts and compare complete search-to-win costs.

No search, episode, policy promotion, or user save access occurs. Incomplete
cohorts yield no completion-time ranking. Explicit cost scenarios are assumptions.
"""
from __future__ import annotations

import argparse
from collections import Counter
import itertools
import json
import math
from pathlib import Path

from development_report import episode_record, parse_trace
import filtered_engine_compare as filtered
from paired_policy_audit import digest, file_digest, write_json


def finite(value, label, minimum=0):
    if type(value) not in (int, float) or not math.isfinite(value) or value < minimum:
        raise ValueError('Invalid ' + label)
    return value


def cost_model(value):
    keys = {'action_seconds', 'failed_run_restart_seconds', 'search_invocation_seconds'}
    if value is None:
        return None
    if not isinstance(value, dict) or set(value) != keys:
        raise ValueError('Explicit cost model needs action, failed-run restart and search-invocation seconds')
    return {key: finite(value[key], key) for key in sorted(keys)}


def complete_attempt(record):
    """Re-derive terminal truth; a cached outcome or acquired pair is insufficient."""
    if record.get('challenge') == 'c_jokerless_1':
        raise ValueError('Jokerless is excluded from filtered route selection')
    if record.get('verification_error'):
        return 'unresolved_verification'
    trace = Path(record['trace'])
    if record.get('trace_digest') != file_digest(trace):
        raise ValueError('Filtered attempt trace changed')
    rows, errors = parse_trace(trace)
    if errors:
        return 'unresolved_parse'
    # Legacy reports did not preserve the host exit result. Retain their useful
    # costs/attrition but do not infer successful termination from a final line.
    if record.get('exit_code') is None:
        return 'unresolved_legacy_exit_status'
    if record['exit_code'] != 0:
        return 'unresolved_' + str(record.get('outcome', 'process_error'))
    actual = episode_record(trace, record['challenge'], record['seed'], record['exit_code'],
                            record['elapsed_seconds'], record.get('command') or [])
    if actual['outcome'] in ('win', 'loss') and record.get('native_status') == 'found' and record.get('setup_complete'):
        return actual['outcome']
    stops = [r for r in rows if r.get('type') == 'engine_episode_stopped']
    if (record.get('native_status') == 'not_found' and not record.get('setup_complete')
            and len(stops) == 1 and stops[0].get('reason') == 'development_opening_not_found'
            and not any(r.get('type') == 'engine_episode_action' for r in rows)):
        return 'resolved_search_miss'
    return 'unresolved_' + str(actual['outcome'])


def terminal_engine(record, status):
    rows, errors = parse_trace(record['trace'])
    if errors or status not in ('win', 'loss'):
        return None
    contexts = [r for r in rows if r.get('type') == 'engine_episode_terminal_context']
    if len(contexts) != 1 or not isinstance(contexts[0].get('snapshot'), dict):
        return None
    snapshot = contexts[0]['snapshot']
    return {'outcome': status, 'step': contexts[0].get('step'),
            'retained_row': filtered.retained_row(snapshot),
            'acquired_pair_features': filtered.engine_features(snapshot, record.get('acquired_pair') or []),
            'scope': 'Actual terminal resource counters; no utility inferred from Joker names'}


def summarize_records(records, costs=None, statuses=None):
    costs = cost_model(costs)
    identities = [(r['challenge'], r['targets'], r['seed']) for r in records]
    if len(identities) != len(set(identities)):
        raise ValueError('Duplicate registered search attempts')
    if any(r['challenge'] == 'c_jokerless_1' for r in records):
        raise ValueError('Jokerless is excluded from filtered route selection')
    statuses = [complete_attempt(r) for r in records] if statuses is None else statuses
    if len(statuses) != len(records):
        raise ValueError('Attempt status count differs')
    groups = []
    for challenge, targets in sorted({(r['challenge'], r['targets']) for r in records}):
        pairs = [(r, status) for r, status in zip(records, statuses) if (r['challenge'], r['targets']) == (challenge, targets)]
        source_cost = sum(finite(r['elapsed_seconds'], 'elapsed_seconds') for r, _ in pairs)
        actions = sum(finite(r.get('actions_observed', 0), 'actions_observed') for r, _ in pairs)
        outcomes = Counter(status for _, status in pairs)
        wins, losses = outcomes['win'], outcomes['loss']
        complete = all(status in ('win', 'loss', 'resolved_search_miss') for _, status in pairs)
        total = (source_cost + actions * costs['action_seconds'] + losses * costs['failed_run_restart_seconds']
                 + len(pairs) * costs['search_invocation_seconds']) if costs is not None else None
        groups.append({'challenge': challenge, 'targets': targets, 'attempts': len(pairs), 'resolved_statuses': dict(outcomes),
            'source_attempt_seconds': source_cost, 'observed_actions': actions,
            'declared_total_seconds': total, 'all_acquisitions_terminal_or_search_miss': complete,
            'recorded_wins': wins, 'recorded_losses': losses, 'resolved_search_misses': outcomes['resolved_search_miss'],
            'observed_native_misses': sum(r.get('native_status') == 'not_found' for r, _ in pairs),
            'observed_pair_attritions': sum(bool(r.get('first_loss_of_pair')) for r, _ in pairs),
            'diagnostic_source_seconds_per_win': source_cost / wins if complete and wins else None,
            'diagnostic_declared_seconds_per_win': total / wins if complete and wins and total is not None else None,
            'registered_starts': sorted(r['seed'] for r, _ in pairs),
            'last_observed_rows': [{'seed': r['seed'], 'outcome': status,
                                   'row': (r.get('observations') or [{}])[-1].get('retained_row'),
                                   'acquired_pair': r.get('acquired_pair'),
                                   'last_observed_pair_keys': r.get('last_observed_pair_keys')}
                                  for r, status in pairs]})
    comparisons = []
    for challenge in sorted({g['challenge'] for g in groups}):
        routes = [g for g in groups if g['challenge'] == challenge]
        paired_starts = len({tuple(g['registered_starts']) for g in routes}) == 1
        ready = len(routes) >= 2 and paired_starts and all(g['diagnostic_declared_seconds_per_win'] is not None for g in routes)
        preferred = None
        if ready:
            ordered = sorted(routes, key=lambda g: g['diagnostic_declared_seconds_per_win'])
            if ordered[0]['diagnostic_declared_seconds_per_win'] < ordered[1]['diagnostic_declared_seconds_per_win']:
                preferred = ordered[0]['targets']
        comparisons.append({'challenge': challenge, 'status': 'diagnostic_comparison_only' if ready else 'inconclusive',
                            'paired_registered_starts': paired_starts, 'diagnostic_preferred_targets': preferred,
                            'runtime_filter_change_allowed': False,
                            'reason': 'Complete matched terminal cohorts with explicit cost assumptions' if ready else
                              'Need matched starts, terminal acquired runs, a recorded win per route and explicit action/restart/setup costs'})
    return {'groups': groups, 'comparisons': comparisons, 'cost_model': costs,
            'qualified_win_rate': None, 'expected_real_time_all_20_challenges': None, 'promotion_allowed': False}


def interval(value, label, maximum=None):
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(label + ' must be [minimum, maximum]')
    low, high = (finite(item, label) for item in value)
    if high < low or maximum is not None and high > maximum:
        raise ValueError('Invalid bounds for ' + label)
    return low, high


def one_more_search_scenario(values):
    """One bounded extra search, then use found engine or retain current engine.

    Future engine time must already include setup, failure/retry, computation and
    action costs. The scenario makes no claims about unknown hit/usefulness rates.
    """
    required = {'current_remaining_seconds', 'search_seconds', 'hit_probability', 'found_remaining_seconds'}
    if not isinstance(values, dict) or set(values) != required:
        raise ValueError('Search scenario needs current/search/found time bounds and hit-probability bounds')
    current = interval(values['current_remaining_seconds'], 'current remaining time')
    search = interval(values['search_seconds'], 'search time')
    hit = interval(values['hit_probability'], 'hit probability', 1)
    found = interval(values['found_remaining_seconds'], 'found engine remaining time')
    # Increment relative to using the same current engine now. This preserves
    # correlation of current time in both choices, rather than combining
    # incompatible best and worst cases independently.
    deltas = [s + p * (f - c) for c, s, p, f in itertools.product(current, search, hit, found)]
    low, high = min(deltas), max(deltas)
    choice = 'one_more_bounded_search' if high < 0 else 'use_current_engine' if low > 0 else 'inconclusive'
    return {'scope': 'Assumed one-search scenario; misses fall back to the same current engine',
            'input_bounds': values, 'extra_expected_seconds_bounds': [low, high], 'conditional_choice': choice,
            'search_execution_authorized': False, 'measured_estimate': False}


def run(args):
    output = args.output.resolve();output.mkdir(parents=True, exist_ok=False)
    verified = filtered.merge_verified_cohorts(args.cohort)
    costs = cost_model(json.loads(args.cost_model.read_text()) if args.cost_model else None)
    statuses = [complete_attempt(r) for r in verified['records']]
    report = summarize_records(verified['records'], costs, statuses)
    report['terminal_engines'] = [terminal_engine(r, status) for r, status in zip(verified['records'], statuses)
                                  if status in ('win', 'loss')]
    report['verified_cohorts'] = verified['cohorts']
    report['workflow_digest'] = file_digest(__file__)
    report['source_aggregation_digest'] = verified['aggregation_workflow_sha256']
    report['cost_model_digest'] = digest(costs)
    report['scenario'] = one_more_search_scenario(json.loads(args.scenario.read_text())) if args.scenario else None
    report['limitations'] = ['Source attempt elapsed time already includes native search/setup/computation; do not add them twice',
        'Observed attrition can transfer value into another retained engine; names and acquisitions receive no win credit',
        'Historical reports missing host exit status cannot establish terminal completion',
        'Cost inputs and search scenario probabilities are explicit assumptions, not fitted measurements',
        'A finite cohort diagnostic is not a qualified population forecast or justification to change the runtime filter']
    write_json(output / 'report.json', report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cohort', type=Path, action='append', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cost-model', type=Path)
    parser.add_argument('--scenario', type=Path)
    args = parser.parse_args()
    try:
        report = run(args)
    except (ValueError, KeyError, OSError) as error:
        parser.error(str(error))
    print(json.dumps({'comparisons': report['comparisons'], 'promotion_allowed': False}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
