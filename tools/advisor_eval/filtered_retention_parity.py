#!/usr/bin/env python3
"""Bounded original-source regression: native pair acquisition is not retention.

The known Knife fixture has a pinned Eternal Dagger and no expendable blocker.
Souls in Arcana packs are used immediately by the original game; they cannot be
stored for later. Assert the actual surviving engine and first-play score, never
claim preservation of both advertised engines. No live game process or saves.
"""
import argparse
from pathlib import Path
import sys
from development_report import parse_trace
from paired_policy_audit import collect, write_json


def verify(rows):
    complete = [r for r in rows if r['type'] == 'engine_opening_setup_complete']
    changes = [r for r in rows if r['type'] == 'engine_opening_pair_changed']
    actions = [r for r in rows if r['type'] == 'engine_episode_action']
    verified = [r for r in rows if r['type'] == 'engine_episode_score_verified']
    assert len(complete) == 1 and complete[0]['actual_pair'] == ['j_yorick', 'j_perkeo']
    assert len(changes) == 1 and changes[0]['missing'] == ['j_yorick'] and changes[0]['retained'] == ['j_perkeo']
    assert changes[0]['action'] == {'kind': 'select_blind', 'blind': 'Big'}
    resolved = next(r for r in rows if r['type'] == 'engine_episode_resolved' and r['step'] == changes[0]['step'])
    assert [j['key'] for j in resolved['joker_order']] == ['j_ceremonial', 'j_perkeo']
    assert resolved['joker_order'][0]['pinned'] and resolved['joker_order'][0]['ability']['eternal']
    assert resolved['joker_order'][0]['ability']['mult'] == 20
    assert verified and all(r['predicted'] == r['actual'] for r in verified if r['scope'] == 'deterministic_score')
    assert any(r['action']['kind'] == 'play' for r in actions) and any(r['action']['kind'] == 'cash_out' for r in actions)
    assert not any(r['type'] == 'engine_episode_terminal' for r in rows)
    return 9


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--policy-root', type=Path, required=True)
    p.add_argument('--output-dir', type=Path, required=True)
    p.add_argument('--timeout', type=float, default=20)
    args = p.parse_args()
    if not 0 < args.timeout <= 45: p.error('Require bounded timeout <=45 seconds')
    args.output_dir.mkdir(parents=True, exist_ok=False)
    request = {'challenge': 'c_knife_1', 'seed': 'I1L21111'}
    cmd = [sys.executable, '-u', str(Path(__file__).with_name('engine_probe.py')), '--episode',
           '--policy-root', str(args.policy_root), '--challenge', request['challenge'], '--seed', request['seed'],
           '--opening-targets', 'j_yorick,j_perkeo', '--opening-search-limit', '1', '--stop-after-step', '7']
    record = collect(cmd, args.output_dir / 'source.log', request, args.timeout)
    rows, errors = parse_trace(record['trace'])
    assert not errors and record['outcome'] == 'censored', record['reason']
    checks = verify(rows)
    report = {'qualification': False, 'scope': 'preselected_native_fixture_source_retention_parity',
              'checks_passed': checks, 'record': record, 'win_rate_estimate': None,
              'limitation': 'Knife Dagger consumes immature Yorick; Perkeo survives and the next original hand clears.'}
    write_json(args.output_dir / 'report.json', report)
    print({'checks_passed': checks, 'outcome': record['outcome'], 'elapsed_seconds': record['elapsed_seconds']})


if __name__ == '__main__': main()
