#!/usr/bin/env python3
"""Four bounded, hidden original-source fixtures; never ordinary win evidence."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from development_report import parse_trace
from paired_policy_audit import collect, write_json

HERE = Path(__file__).resolve().parent


def verify_scenario(scenario, rows, outcome):
    if scenario == 'score_floor_play':
        assert outcome == 'censored', outcome
        score = next(r for r in rows if r.get('type') == 'engine_episode_score_verified')
        assert score['scope'] == 'supported_random_floor' and score['actual'] >= score['predicted']
        return 2
    if scenario == 'dagger_preblind':
        assert outcome == 'censored', outcome
        actions = [r for r in rows if r.get('type') == 'engine_episode_action']
        assert [(r['phase'], r['action']['kind']) for r in actions] == [('blind', 'reorder_jokers'), ('blind', 'select_blind')]
        initial = next(r['jokers'] for r in rows if r.get('type') == 'engine_source_scenario')
        after = [r for r in rows if r.get('type') == 'engine_episode_resolved'][-1]['joker_order']
        assert [j['key'] for j in after] == ['j_ceremonial', 'j_joker']
        assert after[1]['ability']['mult'] == 80, 'The useful core was sacrificed'
        assert after[0]['ability']['mult'] == initial[0]['ability']['mult'] + initial[2]['sell_cost'] * 2
        assert after[0]['pinned'] and actions[0]['action']['order'][0] == 1
        return 5
    terminal = next(r for r in rows if r.get('type') == 'engine_episode_terminal')
    assert terminal['source_game_won'] is True, 'Source final-boss marker must set in both branches'
    won = scenario == 'terminal_win_final'
    assert outcome == ('win' if won else 'loss')
    assert terminal['source_profile_completed'] is won and terminal['game_over'] is not won
    assert terminal['game_won'] is won
    return 4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy-root', type=Path, default=HERE.parents[1])
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--timeout', type=float, default=30)
    args = parser.parse_args()
    if not 0 < args.timeout <= 45:
        parser.error('Source parity timeout must be 0..45 seconds')
    args.output_dir.mkdir(parents=True, exist_ok=False)
    records, failures, checks = [], [], 0
    for scenario in ('dagger_preblind', 'score_floor_play', 'terminal_loss_final', 'terminal_win_final'):
        challenge = 'c_knife_1' if scenario == 'dagger_preblind' else 'c_rich_1' if scenario == 'score_floor_play' else 'c_jokerless_1'
        request = {'challenge': challenge, 'seed': 'ADVISORPHASE331'}
        command = [sys.executable, '-u', str(HERE / 'engine_probe.py'), '--episode',
                   '--challenge', challenge, '--seed', request['seed'], '--policy-root', str(args.policy_root.resolve()),
                   '--test-scenario', scenario]
        if scenario == 'dagger_preblind':
            command += ['--stop-after-step', '2']
        record = collect(command, args.output_dir / (scenario + '.log'), request, args.timeout)
        records.append(record)
        rows, errors = parse_trace(record['trace'])
        try:
            assert not errors, errors
            checks += verify_scenario(scenario, rows, record['outcome'])
        except (AssertionError, KeyError, StopIteration, IndexError) as error:
            failures.append({'scenario': scenario, 'error': str(error), 'reason': record['reason']})
        print(json.dumps({'scenario': scenario, 'outcome': record['outcome'], 'elapsed_seconds': record['elapsed_seconds'],
                          'reason': record['reason']}), flush=True)
    report = {'qualification': False, 'scope': 'synthetic_original_source_phase_and_terminal_parity',
              'checks_passed': checks, 'failures': failures, 'episodes': records}
    write_json(args.output_dir / 'report.json', report)
    print(json.dumps({'report': str(args.output_dir / 'report.json'), 'checks_passed': checks, 'failures': failures}), flush=True)
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
