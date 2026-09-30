"""Read-only summaries of normalized, registered seed-paired outcome records.

This module never opens traces, source, saves or the game and cannot certify an
upstream terminal audit. See COHORT_PROGRESS.md for its deliberately strict schema.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re


DIGEST_KEYS = ('profile', 'source', 'adapter', 'runtime', 'start_distribution')
OUTCOMES = ('win', 'loss', 'error', 'timeout', 'unsupported', 'censored', 'unverified')
SAMPLING_KEYS = ('independent_seeds', 'prespecified', 'fixed_sample_size', 'previously_uninspected')
HEX = re.compile(r'^[0-9a-f]{64}$')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(value):
    return isinstance(value, str) and HEX.fullmatch(value) is not None


def finite_nonnegative(value):
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def milestone_id(value):
    require(isinstance(value, dict) and set(value) == {'ante', 'blind', 'event'},
            'A milestone needs exactly ante, blind and event')
    require(type(value['ante']) is int and 1 <= value['ante'] <= 8,
            'Milestone ante must be an integer from 1 through 8')
    require(value['blind'] in ('small', 'big', 'boss') and value['event'] in ('entered', 'cleared'),
            'Milestones distinguish entering a blind from clearing it')
    return f"ante_{value['ante']}_{value['blind']}_{value['event']}"


def validate(document):
    """Reject pooling, retries and duplicate records before any statistics."""
    require(isinstance(document, dict) and type(document.get('schema')) is int
            and document['schema'] == 1, 'Require schema 1')
    reg = document.get('registration')
    require(isinstance(reg, dict), 'Require registration')
    require(digest(reg.get('digest')), 'Require exact registration digest')
    require(isinstance(reg.get('challenge'), str) and bool(reg['challenge']), 'Require one challenge')
    require(reg.get('split') in ('development', 'holdout'), 'Require one development or holdout split')
    provenance = reg.get('provenance')
    require(isinstance(provenance, dict) and set(provenance) == set(DIGEST_KEYS)
            and all(digest(v) for v in provenance.values()), 'Require every exact shared provenance digest')
    policies = reg.get('policies')
    require(isinstance(policies, dict) and len(policies) in (2, 4)
            and all(isinstance(k, str) and bool(k) and digest(v) for k, v in policies.items()),
            'Register two or four named frozen policies')
    seeds = reg.get('seeds')
    require(isinstance(seeds, list) and bool(seeds)
            and all(isinstance(s, str) and bool(s) for s in seeds), 'Require registered seeds')
    require(len(set(seeds)) == len(seeds), 'A seed cannot be replicated or split into dependent episodes')
    require(reg.get('initial_state') == 'fresh_run' and reg.get('retry_context') == 'disabled_clean',
            'Only fresh runs with disabled clean retry context can form this cohort')
    sampling = reg.get('sampling')
    require(isinstance(sampling, dict) and set(sampling) == set(SAMPLING_KEYS)
            and all(type(v) is bool for v in sampling.values()), 'Declare every sampling assumption explicitly')
    require(isinstance(reg.get('milestones'), list), 'Require an explicit milestone list, possibly empty')
    milestones = [milestone_id(m) for m in reg['milestones']]
    require(len(set(milestones)) == len(milestones), 'Duplicate milestone')
    baseline = reg.get('baseline')
    require(isinstance(baseline, str) and baseline in policies, 'Declare the baseline policy')
    factorial = reg.get('factorial')
    if factorial is not None:
        require(isinstance(factorial, dict) and set(factorial) == {'baseline', 'a', 'b', 'ab'}
                and all(isinstance(v, str) for v in factorial.values())
                and set(factorial.values()) == set(policies) and len(set(factorial.values())) == 4
                and factorial['baseline'] == baseline, 'Factorial roles require four distinct registered variants')
    rows = document.get('records')
    require(isinstance(rows, list), 'Require normalized records')
    indexed = {}
    for row in rows:
        require(isinstance(row, dict), 'Every record must be an object')
        variant, seed = row.get('variant'), row.get('seed')
        require(isinstance(variant, str) and variant in policies and isinstance(seed, str) and seed in seeds,
                'Record is outside the registered policy/seed grid')
        key = variant, seed
        require(key not in indexed, 'Duplicate or dependent attempt: retain it separately, never pool it')
        require(row.get('registration_digest') == reg['digest'] and row.get('challenge') == reg['challenge']
                and row.get('split') == reg['split'], 'Mixed registration, challenge or split')
        require(row.get('provenance') == provenance and row.get('policy_digest') == policies[variant],
                'Mixed or missing frozen provenance')
        require(row.get('initial_state') == 'fresh_run' and row.get('retry_context') == 'disabled_clean'
                and row.get('dependent_attempt') is False, 'Dependent/retry continuations cannot enter this cohort')
        require(row.get('outcome') in OUTCOMES and type(row.get('terminal_verified')) is bool,
                'Require explicit normalized outcome and terminal verification flag')
        require(not row['terminal_verified'] or row['outcome'] in ('win', 'loss'),
                'Unresolved outcomes cannot be marked terminal verified')
        if row['terminal_verified']:
            require(digest(row.get('terminal_audit_digest')), 'Verified terminals require an upstream audit digest')
        reached = row.get('milestones', {})
        require(isinstance(reached, dict) and set(reached) <= set(milestones)
                and all(v is None or type(v) is bool for v in reached.values()),
                'Milestone values must be explicit true, false or null; omitted means unknown')
        for name, reached_value in reached.items():
            if name.endswith('_cleared') and reached_value is True:
                require(reached.get(name.replace('_cleared', '_entered')) is not False,
                        'A blind cannot be cleared but explicitly not entered')
        skips = row.get('skipped_blinds')
        require(skips is None or isinstance(skips, list), 'Skipped blinds must be a complete list or null')
        if skips is not None:
            seen_skips = set()
            for skipped in skips:
                require(isinstance(skipped, dict) and set(skipped) == {'ante', 'blind'}, 'Malformed skipped blind')
                skipped_id = milestone_id(dict(skipped, event='entered'))
                require(skipped['blind'] != 'boss' and skipped_id not in seen_skips,
                        'A boss cannot be skipped and each skip is counted once')
                require(reached.get(skipped_id) is not True
                        and reached.get(skipped_id.replace('_entered', '_cleared')) is not True,
                        'A skipped blind cannot also be entered or cleared')
                seen_skips.add(skipped_id)
        for metric in ('attempt_seconds', 'user_actions', 'failure_round'):
            if row.get(metric) is not None:
                require(finite_nonnegative(row[metric]), f'{metric} must be finite and nonnegative')
                if metric != 'attempt_seconds':
                    require(type(row[metric]) is int, f'{metric} must be an integer')
        require(row.get('failure_round') is None or row['outcome'] == 'loss' and row['terminal_verified'],
                'Failure round is only defined for verified losses')
        indexed[key] = row
    return reg, indexed, milestones


def outcome(row):
    if row is None:
        return 'missing'
    if row['outcome'] in ('win', 'loss') and not row['terminal_verified']:
        return 'unverified'
    return row['outcome']


def endpoint(row, milestone=None):
    if milestone is not None:
        return None if row is None else row.get('milestones', {}).get(milestone)
    status = outcome(row)
    return 1 if status == 'win' else 0 if status == 'loss' else None


def interval(value):
    return (0, 1) if value is None else (int(value), int(value))


def binary_summary(values):
    n = len(values)
    positive = sum(v == 1 for v in values if v is not None)
    unknown = sum(v is None for v in values)
    return {'registered': n, 'positive': positive, 'negative': n - positive - unknown, 'unknown': unknown,
            'observed_complete_fraction': positive / n if not unknown else None,
            'missing_outcome_bounds': [positive / n, (positive + unknown) / n]}


def bounded_interval(values, low, high, enabled):
    """Pointwise 95% Hoeffding interval; bounded independent seed observations.

    P(|mean-E mean| >= t) <= 2 exp(-2*n*t*t/(high-low)^2).
    This stays honest for all-zero samples; no independence is inferred here.
    """
    if not enabled or not values or any(v is None for v in values):
        return None
    average = sum(values) / len(values)
    radius = (high - low) * math.sqrt(math.log(40) / (2 * len(values)))
    return {'level': .95, 'method': 'bounded_independent_seed_hoeffding',
            'bounds': [max(low, average - radius), min(high, average + radius)],
            'scope': 'pointwise; not simultaneous or valid after adaptive selection/stopping'}


def paired_summary(left, right, uncertainty=False):
    bounds, known = [], []
    for a, b in zip(left, right):
        al, au = interval(a)
        bl, bu = interval(b)
        bounds.append((bl - au, bu - al))
        known.append(None if a is None or b is None else int(b) - int(a))
    n = len(bounds)
    complete = [v for v in known if v is not None]
    return {'registered_pairs': n, 'complete_pairs': len(complete),
            'complete_pair_mean_difference': sum(complete) / len(complete) if complete else None,
            'complete_pair_mean_scope': 'resolved subset only; may be selected by missingness',
            'full_cohort_difference_bounds': [sum(b[0] for b in bounds) / n, sum(b[1] for b in bounds) / n],
            'sampling_interval': bounded_interval(known, -1, 1, uncertainty)}


def measured_summary(rows, key):
    values = [r[key] for r in rows if r is not None and r.get(key) is not None]
    return {'observed': len(values), 'missing': len(rows) - len(values),
            'observed_total': sum(values), 'observed_mean': sum(values) / len(values) if values else None,
            'scope': 'observed records only; missing costs are not zero'}


def report(document):
    reg, indexed, milestones = validate(document)
    seeds, policies = reg['seeds'], reg['policies']
    eligible = all(reg['sampling'].values())
    variants = {}
    for variant in policies:
        rows = [indexed.get((variant, seed)) for seed in seeds]
        counts = Counter(outcome(row) for row in rows)
        completion = [endpoint(row) for row in rows]
        loss_rounds = [r['failure_round'] for r in rows if outcome(r) == 'loss' and r.get('failure_round') is not None]
        skips = [len(r['skipped_blinds']) for r in rows if r is not None and r.get('skipped_blinds') is not None]
        variants[variant] = {'policy_digest': policies[variant], 'outcomes': dict(sorted(counts.items())),
            'reported_unverified_terminals': dict(Counter(r['outcome'] for r in rows if r is not None
                and r['outcome'] in ('win', 'loss') and not r['terminal_verified'])),
            'completion': dict(binary_summary(completion),
                               sampling_interval=bounded_interval(completion, 0, 1, eligible)),
            'milestones': {m: binary_summary([endpoint(r, m) for r in rows]) for m in milestones},
            'skipped_blinds': {'records_with_complete_skip_list': len(skips), 'records_without_complete_skip_list': len(rows) - len(skips),
                              'observed_total': sum(skips), 'observed_mean': sum(skips) / len(skips) if skips else None},
            'failure_round_diagnostic': {'verified_losses': counts['loss'], 'losses_with_round': len(loss_rounds),
                'mean': sum(loss_rounds) / len(loss_rounds) if loss_rounds else None,
                'interpretation': 'Failure-only selected population; can decrease when late losses become wins'},
            'attempt_seconds': measured_summary(rows, 'attempt_seconds'),
            'user_actions': measured_summary(rows, 'user_actions')}
    paired = {}
    baseline = reg['baseline']
    for variant in policies:
        if variant == baseline:
            continue
        a = [indexed.get((baseline, s)) for s in seeds]
        b = [indexed.get((variant, s)) for s in seeds]
        paired[variant] = {'direction': f'{variant} minus {baseline}',
            'completion': paired_summary([endpoint(r) for r in a], [endpoint(r) for r in b], eligible),
            'milestones': {m: paired_summary([endpoint(r, m) for r in a], [endpoint(r, m) for r in b]) for m in milestones}}
    interaction = None
    if reg.get('factorial'):
        roles = reg['factorial']
        interaction = {'formula': 'ab - a - b + baseline', 'inference': 'descriptive only', 'endpoints': {}}
        for metric in [None, *milestones]:
            contrasts = []
            for seed in seeds:
                group = {k: endpoint(indexed.get((v, seed)), metric) for k, v in roles.items()}
                # Do not use a milestone-only partial trajectory for a 2x2 outcome interaction.
                terminal_complete = all(endpoint(indexed.get((v, seed))) is not None for v in roles.values())
                if terminal_complete and all(v is not None for v in group.values()):
                    contrasts.append(int(group['ab']) - int(group['a']) - int(group['b']) + int(group['baseline']))
            interaction['endpoints'][metric or 'completion'] = {'registered_seed_blocks': len(seeds),
                'complete_seed_blocks': len(contrasts), 'excluded_seed_blocks': len(seeds) - len(contrasts),
                'mean_complete_block_contrast': sum(contrasts) / len(contrasts) if contrasts else None,
                'scope': 'complete four-variant subset only; exclusions may select this subset', 'sampling_interval': None}
    return {'schema': 1, 'registration': reg, 'qualification': False, 'player_win_rate': None,
            'expected_real_completion_seconds': None, 'submitted_records': len(indexed),
            'registered_attempts': len(seeds) * len(policies), 'variants': variants, 'paired': paired,
            'interaction': interaction,
            'sampling_intervals_eligible_by_declaration': eligible,
            'limitations': ['Normalized terminal verification and digests are upstream assertions, not independently reaudited here',
                'Missing-outcome bounds describe this finite registered cohort; they are not confidence intervals',
                'Independent prespecified fixed-size uninspected sampling is declared, not established by the reporter',
                'All sampling intervals are pointwise and do not correct multiple comparisons or candidate selection',
                'Milestone entry, actual clearing and skips are distinct; omitted progress is unknown',
                'Attempt seconds and user actions do not establish opening/filter/retry/animation or total real completion costs',
                'No player-population, policy promotion, superiority or causal qualification']}


def parse_input(data):
    """Do not silently shadow duplicate provenance or accept nonfinite JSON."""
    def unique_object(items):
        result = {}
        for key, value in items:
            require(key not in result, f'Duplicate JSON key: {key}')
            result[key] = value
        return result

    def reject_constant(value):
        raise ValueError(f'Nonfinite JSON constant: {value}')

    return json.loads(data.decode('utf-8-sig'), object_pairs_hook=unique_object, parse_constant=reject_constant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    args = parser.parse_args()
    data = args.input.read_bytes()
    document = parse_input(data)
    result = report(document)
    result['input_sha256'] = hashlib.sha256(data).hexdigest()
    result['reporter_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    print(json.dumps(result, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
