#!/usr/bin/env python3
"""Freeze and audit bounded original-source boundary fixtures, never policy wins.

Original challenge initialization and final-Boss success/failure run for every
challenge. Explicit state mutations skip the intervening run, so passing this
matrix qualifies only the stated boundary cases, never a challenge win rate.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

import engine_probe
import paired_policy_audit as paired
from development_report import classify, parse_trace

HERE = Path(__file__).resolve().parent
EXTRAS = ('empty_hand_refill', 'empty_hand_zero_limit', 'selected_action_play',
          'terminal_saved_final', 'terminal_unsaved_final', 'failure_context', 'forced_selection')


def requests():
    return [{'challenge': challenge, 'scenario': scenario, 'seed': 'BOUNDARY263'}
            for challenge in paired.CHALLENGES
            for scenario in ('terminal_loss_final', 'terminal_win_final')] + [
        {'challenge': 'c_city_1', 'scenario': scenario, 'seed': 'BOUNDARY263'} for scenario in EXTRAS]


def verify(rows, request, registration, code, errors=()):
    outcome, reason = classify(rows, code, errors)
    scenario = request['scenario']
    expected = ('unsupported' if scenario == 'failure_context' else
                'win' if scenario in ('terminal_win_final', 'terminal_saved_final') else
                'censored' if scenario in ('empty_hand_refill', 'selected_action_play', 'forced_selection') else 'loss')
    findings = []
    origins = [r for r in rows if r.get('type') == 'engine_probe_provenance']
    profiles = [r for r in rows if r.get('type') == 'engine_probe_profile']
    if len(origins) != 1 or len(profiles) != 1:
        findings.append('missing_or_duplicate_provenance')
    else:
        origin, profile = origins[0], profiles[0]
        expected_origin = {k: registration[k] for k in ('rules_digest', 'runtime_digest', 'adapter_digest', 'policy_digest')}
        expected_origin.update(challenge=request['challenge'], seed=request['seed'], test_scenario=scenario,
                               counterfactual=True, followed_advice=False, profile_spec=registration['profile_spec'],
                               profile_spec_digest=paired.digest(registration['profile_spec']))
        if any(origin.get(k) != v for k, v in expected_origin.items()):
            findings.append('source_or_policy_provenance_mismatch')
        if origin.get('start_distribution') != {'kind': 'source_parity_fixture', 'scenario': scenario}:
            findings.append('fixture_incorrectly_marked_ordinary')
        try:
            text = '\n'.join(':'.join(r[k] for k in ('scope', 'key', 'unlocked', 'discovered'))
                             for r in profile['inventory']).encode()
            if engine_probe.profile_record(registration['profile_spec']['name'], text) != profile:
                findings.append('profile_inventory_mismatch')
        except (ValueError, KeyError, TypeError):
            findings.append('invalid_profile_inventory')
    if outcome != expected:
        findings.append('expected_' + expected + '_observed_' + outcome)
    if scenario == 'failure_context':
        contexts = [r for r in rows if r.get('type') == 'engine_episode_failure_context']
        failure = contexts[0] if contexts else {}
        if len(contexts) != 1:
            findings.append('missing_or_duplicate_failure_context')
        if not (failure.get('last_decision', {}).get('step') == 0 and failure.get('snapshot', {}).get('phase') == 'blind'
                and 'synthetic failure context qualification' in reason):
            findings.append('original_failure_or_detached_context_missing')
    elif scenario == 'empty_hand_refill':
        phase = next((r for r in rows if r.get('type') == 'engine_source_phase_verified'), {})
        if not (phase.get('held_after', 0) > 0 and phase.get('deck_before', 0) - phase.get('deck_after', 0) == phase.get('held_after')
                and phase.get('game_over') is False):
            findings.append('refill_population_mismatch')
    elif scenario == 'forced_selection':
        selections = [r for r in rows if r.get('type') == 'engine_source_selection_verified']
        selection = selections[0] if len(selections) == 1 else {}
        if not all(selection.get(k) is True for k in ('legacy_duplicate_reproduced', 'omitted_forced_rejected',
                'zero_target_preserves_forced', 'targeted_omission_rejected', 'targeted_exact', 'ankh_noop_rejected', 'unique_population')):
            findings.append('forced_selection_semantics_not_verified')
        if not (selection.get('discarded_count') == 1 and selection.get('population_before', 0) > 0
                and selection.get('population_before') == selection.get('population_after')):
            findings.append('forced_selection_population_mismatch')
    elif scenario == 'selected_action_play':
        score = next((r for r in rows if r.get('type') == 'engine_episode_score_verified'), {})
        if not (score.get('scope') == 'deterministic_score' and score.get('prediction_source') == 'selected_action_rescore'
                and score.get('predicted') == score.get('actual') and isinstance(score.get('actual'), (int, float))):
            findings.append('selected_action_score_not_verified')
    elif scenario.startswith('terminal_'):
        terminal = next((r for r in rows if r.get('type') == 'engine_episode_terminal'), {})
        if terminal.get('source_game_won') is not True:
            findings.append('final_boss_source_marker_missing')
        if terminal.get('source_profile_completed') is not (expected == 'win'):
            findings.append('fresh_profile_completion_mismatch')
    return {'passed': not findings, 'findings': findings, 'outcome': outcome, 'reason': reason,
            'expected_outcome': expected, 'parse_errors': list(errors)}


def audit(directory):
    directory = Path(directory).resolve()
    registration = json.loads((directory / 'registration.json').read_text())
    unsigned = dict(registration); claimed = unsigned.pop('registration_digest')
    if paired.digest(unsigned) != claimed:
        raise ValueError('Boundary registration changed')
    if any(paired.file_digest(directory / 'adapter' / k) != v for k, v in registration['adapter_files'].items()):
        raise ValueError('Frozen source adapter changed')
    if paired.digest(paired.policy_hashes(directory / 'policy')) != registration['policy_digest']:
        raise ValueError('Frozen policy changed')
    records = []
    for i, request in enumerate(registration['requests']):
        record = json.loads((directory / f'{i:02d}.json').read_text())
        trace = directory / f'{i:02d}.log'
        if record['request'] != request or record['trace_digest'] != paired.file_digest(trace):
            raise ValueError('Boundary request or trace changed')
        expected = command(directory, registration, request)
        if record['command'][1:] != expected[1:] or Path(record['trace']).resolve() != trace:
            raise ValueError('Boundary command or trace identity changed')
        rows, errors = parse_trace(trace)
        records.append({**record, **verify(rows, request, registration, record['exit_code'], errors)})
    return {'registration_digest': claimed, 'boundary_matrix_passed': all(r['passed'] for r in records),
            'complete_matrix_requested': registration['requests'] == requests(),
            'registered_scenarios': sorted({r['scenario'] for r in registration['requests']}),
            'registered_challenges': sorted({r['challenge'] for r in registration['requests']}),
            'auditor_digest': paired.file_digest(__file__),
            'registered_workflow_digest': registration['workflow_digest'],
            'passed': sum(r['passed'] for r in records), 'attempted_or_retained': len(records),
            'source_engine_seconds': sum(r['elapsed_seconds'] for r in records), 'fixtures': records,
            'episode_adapter_qualified': False, 'qualified_win_rate': None,
            'scope': 'Only the explicitly registered synthetic source scenarios; completion and scores are not policy wins',
            'not_covered': ['Intervening full-run transitions', 'Every Joker/Boss/consumable combination',
                            'Unknown or random score predictions', 'Actual user unlock profiles', 'Live frame or user action timing']}


def command(directory, registration, request):
    return [sys.executable, '-u', str(directory / 'adapter' / 'engine_probe.py'), '--install', registration['install'],
            '--policy-root', str(directory / 'policy'), '--episode', '--challenge', request['challenge'],
            '--seed', request['seed'], '--test-scenario', request['scenario'],
            '--unlock-profile', registration['profile_spec']['name']]


def run(args):
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=False)
    adapter = output / 'adapter'; adapter.mkdir()
    hashes = {n: paired.file_digest(HERE / n) for n in paired.ADAPTER_FILES}
    for name in hashes:
        shutil.copyfile(HERE / name, adapter / name)
    frozen = paired.freeze_product(args.policy_root, output / 'policy')
    cases = [r for r in requests() if not args.scenarios or r['scenario'] in args.scenarios]
    registration = {'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(), 'requests': cases,
                    'rules_digest': paired.file_digest(args.install / 'Balatro.exe'),
                    'runtime_digest': paired.file_digest(args.install / 'lua51.dll'), 'install': str(args.install.resolve()),
                    'adapter_files': hashes, 'adapter_digest': paired.digest(hashes), **frozen,
                    'profile_spec': engine_probe.profile_spec('source_defaults_v1'),
                    'per_worker_seconds': 5, 'cumulative_seconds': min(90, 5 * len(cases)), 'max_workers': len(cases),
                    'qualification': False, 'synthetic_fixtures': True, 'workflow_digest': paired.file_digest(__file__),
                    'reporter_digest': paired.file_digest(HERE / 'development_report.py')}
    if any(paired.file_digest(adapter / k) != v or paired.file_digest(HERE / k) != v for k, v in hashes.items()):
        raise ValueError('Source adapter changed during freeze')
    registration['registration_digest'] = paired.digest(registration)
    paired.write_json(output / 'registration.json', registration)
    # Directory creation and registration are durable, one-shot leases. Run has
    # no resume mode; audit never runs a worker or resets an exhausted allowance.
    consumed = 0
    for i, request in enumerate(registration['requests']):
        cmd = command(output, registration, request); trace = output / f'{i:02d}.log'
        remaining = registration['cumulative_seconds'] - consumed
        started = time.perf_counter()
        with trace.open('x', encoding='utf-8') as handle:
            if remaining <= 0:
                code = 'not_run_budget_exhausted'; handle.write('Registered fixture not run: cumulative budget exhausted\n')
            else:
                try:
                    result = subprocess.run(cmd, stdout=handle, stderr=subprocess.STDOUT,
                                            timeout=min(5, remaining), creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = 'timeout'
                except OSError as error:
                    code = 'launch_error'; handle.write(str(error))
        elapsed = time.perf_counter() - started; consumed += elapsed
        record = {'request': request, 'command': cmd, 'exit_code': code, 'trace': str(trace),
                  'trace_digest': paired.file_digest(trace), 'elapsed_seconds': elapsed}
        paired.write_json(output / f'{i:02d}.json', record)
        rows, errors = parse_trace(trace); checked = verify(rows, request, registration, code, errors)
        print(json.dumps({'fixture': i, **request, **checked, 'elapsed_seconds': elapsed}), flush=True)
    report = audit(output); paired.write_json(output / 'report.json', report)
    return 0 if report['boundary_matrix_passed'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--audit', action='store_true')
    parser.add_argument('--scenarios', nargs='+', choices=tuple(dict.fromkeys(r['scenario'] for r in requests())),
                        help='Run only named boundary regressions; default is the complete registered matrix')
    parser.add_argument('--policy-root', type=Path, default=HERE / 'runs/development262_installed/policy')
    parser.add_argument('--install', type=Path, default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    args = parser.parse_args()
    if args.audit:
        report = audit(args.output)
        print(json.dumps({k: v for k, v in report.items() if k != 'fixtures'}))
        return 0 if report['boundary_matrix_passed'] else 1
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())
