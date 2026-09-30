#!/usr/bin/env python3
"""Compare registered native filters by observed engines and complete attempt cost.

Fresh searches, including misses, precede bounded original-source episodes.
Jokerless is excluded. Acquisition and observed later retention are separate;
no censoring, setup success, or engine feature establishes a challenge win rate.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import shutil
import sys

from benchmark import CHALLENGES, digest, file_digest, policy_hashes
from development_report import distribution, parse_trace
from filtered_opening_audit import register_native_policy, verify_native_provenance
from paired_policy_audit import ADAPTER_FILES, HERE, collect, freeze_product, write_json

LEGENDARY = {'j_caino', 'j_triboulet', 'j_yorick', 'j_chicot', 'j_perkeo'}


def numeric(value, default=0):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) else default


def retained_row(snapshot):
    """Current counters expose value transferred by sacrifices or replacements."""
    cards = snapshot.get('jokers') or []
    result = []
    for c in cards if isinstance(cards, list) else []:
        a = c.get('ability') or {};extra = a.get('extra') or {}
        e = extra if isinstance(extra, dict) else {}
        result.append({'key': c.get('key'), 'id': c.get('id'), 'pinned': bool(c.get('pinned') or a.get('pinned')),
            'active': not (c.get('debuff') or a.get('perma_debuff') or a.get('perishable') and numeric(a.get('perish_tally'), 5) <= 0),
            'mult_counter': numeric(a.get('mult')), 'chips_counter': numeric(e.get('chips'), numeric(a.get('t_chips'))),
            'xmult_counter': numeric(a.get('x_mult'), None) if c.get('key')=='j_yorick' else
                max(numeric(a.get('x_mult'), 1), numeric(a.get('caino_xmult'), 1), numeric(e.get('xmult'), 1)),
            'sell_value': numeric(c.get('sell_cost')), 'rental': bool(a.get('rental')),
            'scope': 'Observed counters only; conditional scoring and transfer utility are not evaluated.'})
    return result


def engine_features(snapshot, pair):
    """Describe observed engine resources without converting names into utility."""
    rows = snapshot.get('jokers') or []
    if not isinstance(rows, list):
        rows = []
    inventory = snapshot.get('consumeables') or []
    if not isinstance(inventory, list):
        inventory = []
    cards = snapshot.get('playing_cards') or []
    if not isinstance(cards, list):
        cards = []
    result = []
    for card in rows:
        key = card.get('key')
        if key not in pair:
            continue
        ability = card.get('ability') or {}
        active = not (card.get('debuff') or ability.get('perma_debuff') or
                      ability.get('perishable') and numeric(ability.get('perish_tally'), 5) <= 0)
        item = {'key': key, 'active': active, 'id': card.get('id')}
        if key == 'j_perkeo':
            item['inventory_count'] = len(inventory)
            item['copy_pool_keys'] = [c.get('key') for c in inventory]
            item['negative_inventory_count'] = sum(isinstance(c.get('edition'), dict) and c['edition'].get('negative', False)
                                                     or c.get('edition') == 'negative' for c in inventory)
            item['has_observed_copy_target'] = bool(inventory) and active
            item['copy_quality'] = 'unscored; whole inventory and next shop timing still matter'
        elif key == 'j_yorick':
            extra = ability.get('extra') or {}
            item['current_xmult'] = numeric(ability.get('x_mult'), None)
            item['remaining_discard_counter'] = numeric(ability.get('yorick_discards'), None)
            item['xmult_gain_per_trigger'] = numeric(extra.get('xmult'), None) if isinstance(extra, dict) else None
            item['discard_trigger_size'] = numeric(extra.get('discards'), None) if isinstance(extra, dict) else None
            item['counters_known'] = item['current_xmult'] is not None and item['remaining_discard_counter'] is not None
        elif key == 'j_caino':
            item['current_xmult'] = numeric(ability.get('caino_xmult'), 1)
        elif key == 'j_triboulet':
            item['owned_kings_queens'] = sum(numeric(c.get('rank'), (c.get('base') or {}).get('id')) in (12, 13)
                and c.get('enhancement') != 'm_stone' and (c.get('ability') or {}).get('effect') != 'Stone Card' for c in cards)
            item['population_known'] = bool(cards)
        elif key == 'j_chicot':
            item['observed_boss_disabled'] = bool((snapshot.get('blind') or {}).get('boss') and
                                                   (snapshot.get('blind') or {}).get('disabled'))
        result.append(item)
    return result


def inspect(record, manifest, request):
    if file_digest(Path(record['trace'])) != record.get('trace_digest'):
        raise ValueError('Trace digest changed')
    rows, errors = parse_trace(record['trace'])
    if errors:
        raise ValueError('Malformed trace; preserve the raw attempt')
    provenance = [r for r in rows if r.get('type') == 'engine_probe_provenance']
    if len(provenance) != 1:
        raise ValueError('Require exactly one provenance record')
    p = provenance[0]
    expected = {'challenge': request['challenge'], 'seed': request['seed'],
        'policy_digest': manifest['policy']['policy_digest'], 'policy_files': manifest['policy']['policy_files'],
        **{k: manifest[k] for k in ('rules_digest', 'runtime_digest', 'adapter_digest')},
        'start_distribution': {'kind': 'filtered_two_soul_native_v1', 'targets': request['targets']}}
    if manifest.get('profile_spec'):
        expected.update({k: manifest[k] for k in ('profile_spec', 'profile_spec_digest')})
    if request['challenge'] == 'c_jokerless_1':
        raise ValueError('Jokerless is excluded from this filtered route')
    for key, value in expected.items():
        if p.get(key) != value:
            raise ValueError('Provenance mismatch: ' + key)
    opening = p.get('opening') or {};native = opening.get('result') or {}
    for key, value in {'search_start': request['seed'], 'search_limit': manifest['search_limit'],
                       'targets': request['targets'], 'threads': 1}.items():
        if opening.get(key) != value:
            raise ValueError('Native provenance mismatch: ' + key)
    verify_native_provenance(opening, manifest['policy'])
    search_seconds = opening.get('search_seconds')
    if numeric(search_seconds, -1) < 0:
        raise ValueError('Missing measured native search cost')
    actions = [r for r in rows if r.get('type') == 'engine_episode_action']
    complete = [r for r in rows if r.get('type') == 'engine_opening_setup_complete']
    if len(complete) > 1:
        raise ValueError('Repeated setup completion')
    out = {**request, 'outcome': record['outcome'], 'reason': record['reason'],
        'exit_code': record.get('exit_code'), 'command': record.get('command'),
        'trace': record['trace'], 'trace_digest': record['trace_digest'], 'elapsed_seconds': record['elapsed_seconds'],
        'search_seconds': search_seconds, 'native_status': native.get('status'), 'setup_complete': False,
        'next_search_seed': native.get('next_seed'), 'registered_search_limit': manifest['search_limit'],
        'actions_observed': len(actions), 'cashouts_observed': sum(a['action']['kind'] == 'cash_out' for a in actions),
        'observations': [], 'pair_changes': [], 'retention_scope': 'Observed key presence, not proof of original physical-card continuity.'}
    if native.get('status') != 'found':
        if actions or complete or p.get('run_seed') or p.get('opening_policy_loaded'):
            raise ValueError('Native miss fabricated a playable seed or setup')
        return out
    if p.get('run_seed') != native.get('seed') or not p.get('opening_policy_loaded'):
        raise ValueError('Found seed was not loaded by source')
    out['run_seed'] = p['run_seed']
    if not complete:
        return out
    setup = complete[0];pair = native.get('legendary_jokers')
    if not isinstance(pair, list) or len(pair) != 2 or not set(pair) <= LEGENDARY or setup.get('actual_pair') != pair:
        raise ValueError('Acquisition differs from native pair')
    if setup.get('run_seed') != p['run_seed']:
        raise ValueError('Setup run seed changed')
    for key in ('search_seconds', 'setup_seconds', 'search_and_setup_seconds'):
        if numeric(setup.get(key), -1) < 0:
            raise ValueError('Missing setup cost: ' + key)
    if abs(setup['search_seconds'] + setup['setup_seconds'] - setup['search_and_setup_seconds']) > 1e-6:
        raise ValueError('Setup cost excludes search')
    if abs(setup['search_seconds'] - search_seconds) > 1e-6:
        raise ValueError('Setup search cost differs from provenance')
    setup_step = setup.get('decisions')
    if not isinstance(setup_step, int) or setup_step < 1:
        raise ValueError('Missing acquisition action boundary')
    prefix = [a for a in actions if a.get('step', math.inf) <= setup_step]
    souls = [a for a in prefix if a['action']['kind'] == 'choose' and a.get('card_key') == 'c_soul']
    sales = [a for a in prefix if a['action']['kind'] == 'sell']
    if (not prefix or prefix[0]['action'] != {'kind': 'skip_blind', 'blind': 'Small'} or len(souls) != 2
            or len(sales) != native.get('required_sales') or any(a.get('card_key') != 'j_egg' for a in sales)):
        raise ValueError('Acquisition actions violate native setup contract')
    out.update(setup_complete=True, acquired_pair=pair, setup_actions=len(prefix), setup_seconds=setup['setup_seconds'],
               search_and_setup_seconds=setup['search_and_setup_seconds'])
    retained = list(pair)
    latest_step = setup_step
    seen = set()
    for row in rows:
        kind = row.get('type');snapshot = None
        if kind == 'engine_opening_setup_complete':
            snapshot = row.get('snapshot');step = setup_step
        elif kind == 'engine_opening_pair_changed':
            if row.get('step', 0) < setup_step or not set(row.get('retained') or []) <= set(pair):
                raise ValueError('Invalid retention transition')
            retained = row.get('retained') or []
            if sorted(row.get('missing') or []) != sorted(set(pair) - set(retained)):
                raise ValueError('Incomplete retention transition')
            out['pair_changes'].append({k: row.get(k) for k in ('step', 'ante', 'round', 'retained', 'missing', 'action')})
        elif kind in ('engine_episode_decision', 'engine_episode_checkpoint') and row.get('step', 0) > setup_step:
            snapshot = row.get('snapshot');step = row['step']
        elif kind in ('engine_episode_terminal_context', 'engine_episode_failure_context'):
            snapshot = row.get('snapshot');step = (row.get('last_decision') or {}).get('step', latest_step)
        if not isinstance(snapshot, dict):
            continue
        latest_step = max(step, latest_step)
        features = engine_features(snapshot, pair);row_counters = retained_row(snapshot)
        actual = [c['key'] for c in features]
        identity = (snapshot.get('ante'), snapshot.get('round'), snapshot.get('phase'), tuple(actual), digest([features, row_counters]))
        if identity in seen:
            continue
        seen.add(identity)
        out['observations'].append({'step': step, 'ante': snapshot.get('ante'), 'round': snapshot.get('round'),
            'phase': snapshot.get('phase'), 'retained_pair_keys': actual, 'engine_features': features,
            'retained_row': row_counters})
    out['last_observed_pair_keys'] = retained
    out['first_loss_of_pair'] = next((r for r in out['pair_changes'] if r['missing']), None)
    out['observed_rounds'] = sorted({o['round'] for o in out['observations'] if isinstance(o.get('round'), int)})
    return out


def summarize(records):
    groups = []
    for challenge, targets in sorted({(r['challenge'], r['targets']) for r in records}):
        rows = [r for r in records if (r['challenge'], r['targets']) == (challenge, targets)]
        groups.append({'challenge': challenge, 'targets': targets, 'attempts': len(rows),
            'outcomes': dict(Counter(r['outcome'] for r in rows)),
            'native_statuses': dict(Counter(r.get('native_status', 'unverified') for r in rows)),
            'verified_acquisitions': sum(bool(r.get('setup_complete')) for r in rows),
            'observed_pair_attritions': sum(bool(r.get('first_loss_of_pair')) for r in rows),
            'verification_errors': sum('verification_error' in r for r in rows),
            'total_attempt_seconds': distribution([r['elapsed_seconds'] for r in rows]),
            'search_seconds': distribution([r.get('search_seconds') for r in rows]),
            'actions_observed': sum(r.get('actions_observed', 0) for r in rows),
            'cashouts_observed': sum(r.get('cashouts_observed', 0) for r in rows)})
    return {'qualification': False, 'win_rate_estimate': None, 'time_to_win_estimate': None, 'groups': groups,
        'records': records, 'limitations': [
            'Registered development starts are not a representative population; the adapter uses a synthetic unlock profile.',
            'Elapsed attempt time already includes search and setup; component times must not be added again.',
            'Later observations can be censored at different progress; acquisition is not engine retention or a win.',
            'Engine fields describe observed resources, not calibrated usefulness or a predicted future scoring plan.',
            'Human action, animation, restart, and external search-overhead times are not measured.']}


def summarize_chains(records):
    """Join only exact native-returned continuation starts; keep miss costs."""
    identities = [(r['challenge'], r['targets'], r['seed']) for r in records]
    if len(set(identities)) != len(identities):
        raise ValueError('Repeated search attempts cannot be silently counted twice')
    parents = {}
    for i, row in enumerate(records):
        candidates = [j for j, other in enumerate(records) if j != i and
            (other['challenge'], other['targets'], other.get('next_search_seed')) ==
            (row['challenge'], row['targets'], row['seed'])]
        if len(candidates) > 1:
            raise ValueError('Ambiguous native continuation chain')
        if candidates:
            parents[i] = candidates[0]
    groups = {}
    for i, row in enumerate(records):
        root = i;visited = set()
        while root in parents:
            if root in visited:
                raise ValueError('Cyclic native continuation chain')
            visited.add(root);root = parents[root]
        groups.setdefault(root, []).append(row)
    chains = []
    for root, rows in sorted(groups.items()):
        initial = records[root]
        chains.append({'challenge': initial['challenge'], 'targets': initial['targets'],
            'initial_registered_search_start': initial['seed'], 'attempts': len(rows),
            'search_starts': [r['seed'] for r in rows],
            'total_attempt_seconds': sum(r['elapsed_seconds'] for r in rows),
            'search_seconds': sum(numeric(r.get('search_seconds')) for r in rows),
            'outcomes': dict(Counter(r['outcome'] for r in rows)),
            'acquisitions': sum(bool(r.get('setup_complete')) for r in rows),
            'observed_pair_attritions': sum(bool(r.get('first_loss_of_pair')) for r in rows),
            'actions_observed': sum(r.get('actions_observed', 0) for r in rows)})
    return {'chains': chains, **summarize(records)}


def merge_verified_cohorts(directories):
    """Recheck registered attempts before aggregating separate bounded passes."""
    records = [];cohorts = [];basis = None
    for directory in map(Path, directories):
        manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))
        unsigned = dict(manifest);claimed = unsigned.pop('manifest_digest', None)
        if digest(unsigned) != claimed:
            raise ValueError('Cohort registration changed')
        report = json.loads((directory / 'report.json').read_text(encoding='utf-8'))
        if report.get('manifest_digest') != claimed:
            raise ValueError('Report registration mismatch')
        current = tuple(manifest[k] if k != 'policy' else manifest[k]['policy_digest']
                        for k in ('policy', 'adapter_digest', 'rules_digest', 'runtime_digest'))
        if basis is not None and basis != current:
            raise ValueError('Cannot pool different policy/adapter/source cohorts')
        basis = current
        if policy_hashes(directory / 'policy') != manifest['policy']['policy_files'] or any(
                file_digest(directory / 'adapter' / n) != v for n, v in manifest['adapter_files'].items()):
            raise ValueError('Frozen cohort policy or adapter changed')
        if 'native_file' in manifest['policy'] or 'native_sha256' in manifest['policy']:
            registered = register_native_policy(directory / 'policy', manifest['policy'])
            if registered != manifest['policy']:
                raise ValueError('Registered native selection differs from the frozen loader')
        requests = {(r['challenge'], r['targets'], r['seed']): r for r in manifest['requests']}
        if len(report['records']) != len(requests):
            raise ValueError('Incomplete cohort cannot hide unrecorded attempts')
        for record in report['records']:
            key = (record['challenge'], record['targets'], record['seed'])
            if key not in requests:
                raise ValueError('Unregistered cohort attempt')
            request = requests.pop(key)
            try:
                records.append(inspect(record, manifest, request))
            except ValueError as error:
                records.append({**request, 'outcome': record['outcome'], 'reason': record['reason'],
                    'trace': record['trace'], 'elapsed_seconds': record['elapsed_seconds'],
                    'verification_error': str(error), 'setup_complete': False})
        cohorts.append({'directory': str(directory.resolve()), 'manifest_digest': claimed,
                        'report_sha256': file_digest(directory / 'report.json')})
    return {'cohorts': cohorts, 'aggregation_workflow_sha256': file_digest(__file__), **summarize_chains(records)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy-root', type=Path, required=True)
    parser.add_argument('--adapter-root', type=Path, default=HERE)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--challenge', choices=[c for c in CHALLENGES if c != 'c_jokerless_1'], required=True)
    parser.add_argument('--seed', action='append', required=True)
    parser.add_argument('--targets', action='append', required=True, help='CSV Legendary keys; pass empty string for Any')
    parser.add_argument('--search-limit', type=int, default=1000)
    parser.add_argument('--actions', type=int, default=30)
    parser.add_argument('--timeout', type=float, default=30)
    parser.add_argument('--cohort-label', required=True)
    from engine_probe import PROFILE_NAMES, profile_spec
    parser.add_argument('--unlock-profile', choices=PROFILE_NAMES, default=PROFILE_NAMES[0])
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    if not 1 <= len(args.seed) <= 3 or not 1 <= len(args.targets) <= 3 or len(args.seed)*len(args.targets) > 6:
        parser.error('Use at most six cells, at most three fresh starts and three filters')
    if len(set(args.seed)) != len(args.seed) or len(set(args.targets)) != len(args.targets):
        parser.error('Duplicate registered starts or filters')
    if any(not re.fullmatch('[1-9A-Z]{1,8}', seed) for seed in args.seed):
        parser.error('Native search starts use one to eight uppercase letters or nonzero digits')
    for targets in args.targets:
        keys = targets.split(',') if targets else []
        if len(keys) > 2 or len(keys) != len(set(keys)) or not set(keys) <= LEGENDARY:
            parser.error('Filter must contain zero to two distinct Legendary keys')
    if not 1 <= args.search_limit <= 100000 or not 5 <= args.actions <= 60 or not 0 < args.timeout <= 45:
        parser.error('Require 1..100000 searched seeds, 5..60 actions and <=45s per attempt')
    directory = args.output_dir.resolve();directory.mkdir(parents=True, exist_ok=False)
    policy = register_native_policy(directory / 'policy', freeze_product(args.policy_root, directory / 'policy'))
    adapter = directory / 'adapter';adapter.mkdir()
    hashes = {name: file_digest(args.adapter_root / name) for name in ADAPTER_FILES}
    for name in ADAPTER_FILES:
        shutil.copyfile(args.adapter_root / name, adapter / name)
    if any(file_digest(adapter / n) != v or file_digest(args.adapter_root / n) != v for n, v in hashes.items()):
        raise ValueError('Adapter changed while freezing')
    workflow_files = ('filtered_engine_compare.py', 'filtered_opening_audit.py', 'opening_support.py',
                      'paired_policy_audit.py', 'development_report.py', 'benchmark.py')
    workflow_hashes = {name: file_digest(HERE / name) for name in workflow_files}
    for name in workflow_files:
        shutil.copyfile(HERE / name, directory / name)
    if any(file_digest(directory / n) != v for n, v in workflow_hashes.items()):
        raise ValueError('Workflow changed while freezing')
    requests = [{'challenge': args.challenge, 'seed': seed, 'targets': targets}
                for i, seed in enumerate(args.seed) for targets in (args.targets if i % 2 == 0 else list(reversed(args.targets)))]
    manifest = {'schema': 1, 'qualification': False, 'created_utc': datetime.now(timezone.utc).isoformat(),
        'workflow_sha256': file_digest(__file__), 'workflow_files': workflow_hashes,
        'policy': policy, 'adapter_files': hashes, 'adapter_digest': digest(hashes),
        'rules_digest': file_digest(args.install / 'Balatro.exe'), 'runtime_digest': file_digest(args.install / 'lua51.dll'),
        'search_limit': args.search_limit, 'action_limit': args.actions, 'timeout_seconds': args.timeout,
        'requests': requests, 'cohort_label': args.cohort_label, 'seed_role': 'Registered native search starts, not selected found seeds'}
    manifest['profile_spec'] = profile_spec(args.unlock_profile)
    manifest['profile_spec_digest'] = digest(manifest['profile_spec'])
    manifest['manifest_digest'] = digest(manifest);write_json(directory / 'manifest.json', manifest)
    records = []
    for index, request in enumerate(requests):
        command = [sys.executable, '-u', str(adapter / 'engine_probe.py'), '--episode', '--debug-decisions',
            '--policy-root', str(directory / 'policy'), '--install', str(args.install), '--challenge', request['challenge'],
            '--seed', request['seed'], '--opening-targets', request['targets'], '--opening-search-limit', str(args.search_limit),
            '--stop-after-step', str(args.actions), '--unlock-profile', args.unlock_profile]
        record = collect(command, directory / f'attempt_{index+1}.log', request, args.timeout)
        try:
            result = inspect(record, manifest, request)
        except ValueError as error:
            result = {**request, 'outcome': record['outcome'], 'reason': record['reason'], 'trace': record['trace'],
                'exit_code': record.get('exit_code'), 'command': record.get('command'),
                'trace_digest': record['trace_digest'], 'elapsed_seconds': record['elapsed_seconds'],
                'setup_complete': False, 'verification_error': str(error)}
        records.append(result)
        write_json(directory / 'report.json', {'manifest_digest': manifest['manifest_digest'], **summarize(records)})
        print(json.dumps({k: v for k, v in result.items() if k not in ('observations', 'trace', 'pair_changes')}), flush=True)
    if policy_hashes(directory / 'policy') != policy['policy_files'] or any(file_digest(adapter / n) != v for n, v in hashes.items()):
        raise ValueError('Frozen policy or adapter changed during comparison')


if __name__ == '__main__':
    main()
