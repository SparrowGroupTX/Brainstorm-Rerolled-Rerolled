"""Summarize existing diagnostic287 receipts without executing any experiment."""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CYCLE = ROOT / 'tools/advisor_eval/runs/diagnostic287_20260913_222344'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def reference(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

def rows(path):
    result = []
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.startswith('{'):
            try:
                result.append(json.loads(line))
            except ValueError:
                # The original raw log and episode_record parse_errors retain
                # truncated output; it is not a completed observation.
                continue
    return result

def attempt(job):
    directory = CYCLE / job
    record = read(directory / 'record.json')
    trace = rows(directory / 'attempt.log')
    snapshots = {r['step']: r for r in trace if r.get('type') == 'engine_episode_decision_started'}
    actions = [r for r in trace if r.get('type') == 'engine_episode_action']
    resolved = {r['step']: r for r in trace if r.get('type') == 'engine_episode_resolved'}
    entered = []
    cleared = []
    completed_play = None
    for action in actions:
        if action['step'] not in snapshots:
            continue
        s = snapshots[action['step']]['snapshot']
        blind = s.get('blind', {})
        item = (s.get('ante'), blind.get('key'))
        if s.get('phase') == 'hand' and item not in entered:
            entered.append(item)
        if s.get('phase') == 'hand' and action['action']['kind'] == 'play' and action['step'] in resolved:
            delta = resolved[action['step']].get('chips_delta')
            completed_play = (item, s.get('chips', 0) + delta, blind.get('chips')) if isinstance(delta, (int, float)) else None
        if (action['action']['kind'] == 'cash_out' and action['step'] in resolved
                and completed_play is not None):
            prior_blind, chips, target = completed_play
            if isinstance(target, (int, float)) and target > 0 and chips >= target and prior_blind not in cleared:
                cleared.append(prior_blind)
            completed_play = None
    loss = (record.get('loss_analysis') or {}).get('snapshot', {})
    return {'job': job, 'seed': record['seed'], 'policy_digest': record.get('provenance', {}).get('policy_digest'),
            'outcome': record['outcome'], 'reason': record['reason'], 'terminal': record.get('terminal'),
            'final_chips': loss.get('chips'), 'final_target': loss.get('blind', {}).get('chips'),
            'provenance_verified': record['provenance_verified'], 'audit_errors': record['audit_errors'],
            'entered_blinds': entered, 'cleared_blinds': cleared,
            'skips': record['actions'].get('skip_blind', 0), 'actions': len(actions),
            'resolved_actions': len(resolved), 'action_kinds': record['actions'],
            'elapsed_seconds': record['elapsed_seconds'], 'decision_metrics': record['decision_metrics'],
            'score_verification': record['score_verification'], 'record': reference(directory / 'record.json'),
            'parse_errors': record['parse_errors'], 'progress_scope': 'observed completed trace events only; missing milestones are unknown',
            'registration': reference(directory / 'registration.json'), 'trace': reference(directory / 'attempt.log')}

def divergence(left, right):
    a = rows(CYCLE / left / 'attempt.log'); b = rows(CYCLE / right / 'attempt.log')
    starts = [{r['step']: r for r in rs if r.get('type') == 'engine_episode_decision_started'} for rs in (a, b)]
    decisions = [{r['step']: r for r in rs if r.get('type') == 'engine_episode_action'} for rs in (a, b)]
    for step in sorted(set(decisions[0]) | set(decisions[1])):
        x, y = decisions[0].get(step), decisions[1].get(step)
        if x is None or y is None:
            return {'step': step, 'kind': 'different_completed_prefix', 'causal_claim': False}
        if step not in starts[0] or step not in starts[1]:
            return {'step': step, 'kind': 'missing_public_start_record', 'causal_claim': False}
        same = starts[0][step]['state_fingerprint'] == starts[1][step]['state_fingerprint']
        if x['action'] != y['action'] or not same:
            return {'step': step, 'same_public_state': same, 'left_action': x['action'], 'right_action': y['action'],
                    'left_state_fingerprint': starts[0][step]['state_fingerprint'],
                    'right_state_fingerprint': starts[1][step]['state_fingerprint'], 'causal_claim': False}
    return {'identical_completed_actions_and_public_states': True, 'causal_claim': False}

def main():
    records = [attempt(job) for job in ('C1', 'C2', 'C3', 'C4')]
    outcomes = Counter(r['outcome'] for r in records)
    components = read(CYCLE / 'components_coordinator_record.json')
    search = read(CYCLE / 'search/report.json')
    report = {'created_at_utc': datetime.now(timezone.utc).isoformat(), 'status': 'CLOSED',
              'authority': reference(CYCLE / 'authority.json'), 'protocol': reference(CYCLE / 'cycle_protocol.json'),
              'attempts': records, 'outcomes': dict(outcomes),
              'pairs': [{'baseline': a, 'candidate': b, 'first_divergence': divergence(a, b)}
                        for a, b in (('C1', 'C3'), ('C2', 'C4'))],
              'component_receipt': reference(CYCLE / 'components_coordinator_record.json'),
              'source_audit': reference(CYCLE / 'B_source_audit.json'),
              'captured_failure_audit': reference(CYCLE / 'A_failure_audit.json'),
              'baseline_postmortem': reference(CYCLE / 'C1_C2_postmortem.json'),
              'search_report': reference(CYCLE / 'search/report.json'),
              'limits': {'selected_dependent_development': True, 'synthetic_profile': 'all_unlocked_discovered_v1',
                         'player_population_qualified': False, 'unseen_holdout': False, 'full_adapter_qualified': False,
                         'confidence_interval': None, 'win_odds': None, 'human_performance_comparison': None,
                         'actual_user_gameplay_time_measured': False,
                         'timing_note': 'Descriptive worker timings include setup and trace output. Baseline jobs overlapped routine regression load; no policy speed effect is inferred.'}}
    # Exact original search timings remain authoritative; this recorded total
    # was audited after all four fixed-range jobs completed, with no retries.
    search_seconds = 3.675609199970495
    budget = {'status': 'CLOSED', 'reserved_seconds': 1080,
              'source_and_captured_actual_seconds': components['elapsed_seconds'],
              'search_actual_outer_seconds': search_seconds,
              'complete_attempt_actual_seconds': sum(r['elapsed_seconds'] for r in records),
              'actual_seconds': components['elapsed_seconds'] + search_seconds + sum(r['elapsed_seconds'] for r in records),
              'source_components': 2, 'captured_pair_jobs': 4, 'captured_policy_errors': 8, 'search_workers': 4,
              'complete_attempts': 4, 'replacements': 0, 'unused_capacity': 'closed',
              'historical_authority': 'closed', 'search_report': reference(CYCLE / 'search/report.json')}
    for name, value in (('FINAL_RESULTS.json', report), ('FINAL_BUDGET.json', budget)):
        with (CYCLE / name).open('x', encoding='utf-8') as stream:
            json.dump(value, stream, indent=2)
    print(json.dumps({'outcomes': dict(outcomes), 'actual_seconds': budget['actual_seconds'],
                      'pairs': report['pairs']}))

if __name__ == '__main__':
    main()
