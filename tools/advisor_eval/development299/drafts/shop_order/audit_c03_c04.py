"""Read-only audits of preserved C03/C04 source traces; never executes source/Lua."""
from pathlib import Path
from collections import Counter, defaultdict
import json
import sys
from audit_c02 import sha, digest, read_trace, indexed, slim, compact_snapshot

ROOT = Path(__file__).resolve().parents[5]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
PHASES = {'play': ('hand',), 'discard': ('hand',), 'buy': ('shop',), 'open': ('shop',),
          'buy_and_use': ('shop',), 'choose': ('pack',), 'cash_out': ('round',), 'leave_shop': ('shop',),
          'reroll': ('shop',), 'skip_pack': ('pack',), 'select_blind': ('blind',), 'skip_blind': ('blind',),
          'reorder_hand': ('hand', 'pack'), 'use': ('hand', 'shop', 'blind', 'pack', 'round'),
          'sell': ('hand', 'shop', 'blind', 'pack', 'round'),
          'reorder_jokers': ('hand', 'shop', 'blind', 'pack', 'round')}


def audit(job):
    assert job in ('C03', 'C04')
    folder = BASE / job
    record = json.loads((folder / 'record.json').read_text())
    registration = json.loads((folder / 'registration.json').read_text())
    assert record['one_use_spent'] and record['timeout_seconds'] == registration['timeout_seconds'] == 180
    assert record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert sha(folder / 'registration.json') == record['registration_sha256']
    assert sha(folder / 'trace.log') == record['trace_sha256']
    for name, expected in registration['files'].items():
        assert sha(folder / name) == expected, name
    rows, parsing = read_trace(folder / 'trace.log')
    provenance = rows['engine_probe_provenance'][0]
    assert provenance['policy_digest'] == digest(provenance['policy_files']) == registration['metadata']['policy_digest']
    assert all(registration['files']['policy/' + name] == value for name, value in provenance['policy_files'].items())
    assert provenance['normal_run'] == {'deck': 'b_red', 'stake': 8, 'qualification': False}
    assert provenance['seed'] == registration['metadata']['seed']
    assert provenance['rules_digest'] in registration['external_files'].values()
    assert provenance['runtime_digest'] in registration['external_files'].values()
    assert provenance['seed_selection']['evidence_digest'] == sha(folder / 'normal_seed_selection.json')
    assert provenance['normal_filtered_opening']['recipe_digest'] == sha(folder / 'normal_opening_recipe.json')
    assert not provenance['normal_filtered_opening']['native_search_executed_by_adapter']
    assert rows['engine_probe_profile'][0]['profile'] == 'all_unlocked_discovered_v1'
    retry = rows['engine_probe_retry_context'][0]
    assert retry['checkpoint_reloads_observed'] == 0 and retry['retry_context_spec']['mode'] == 'disabled_clean_attempt_v1'
    index = {kind: indexed(rows, kind) for kind in ('started', 'decision', 'action', 'resolved', 'profile')}
    completed = sorted(set(index['decision']) & set(index['action']) & set(index['resolved']) & set(index['profile']))
    assert completed == list(range(1, len(completed) + 1))
    assert sorted(index['started']) == list(range(1, max(index['started']) + 1))
    pending = sorted(set(index['started']) - set(completed))
    terminal = rows['engine_episode_terminal']
    if job == 'C03':
        assert record['status'] == 'complete' and record['exit_code'] == 0 and not pending
        assert len(terminal) == 1 and terminal[0]['outcome'] == 'loss' and terminal[0]['game_over']
        assert terminal[0]['normal_progress']['final_context']['chips'] == 592
        assert terminal[0]['normal_progress']['final_context']['target'] == 600
        assert not terminal[0]['normal_progress']['threshold_met']
        outcome = 'loss'
    else:
        assert record['status'] == 'timeout' and record['exit_code'] is None
        assert not terminal and not rows['engine_normal_final_round_entered']
        outcome = None
    assert not rows['engine_normal_progress_callback']
    verified = {row['step']: row for row in rows['engine_episode_score_verified']}
    actions, acquisition, sales, inventory, caps, shortcuts, gold = [], [], [], [], [], [], []
    counts = Counter(); profiles = []; repeats = defaultdict(list)
    for step, row in index['started'].items():
        repeats[row['state_fingerprint']].append(step)
    for step in completed:
        start, decision, action_row, resolved, profile = [index[kind][step] for kind in ('started', 'decision', 'action', 'resolved', 'profile')]
        s = start['snapshot']; action = action_row['action']; kind = action['kind']; result = decision['result']
        assert s == decision['snapshot'] and action == result['action']
        assert s['phase'] == action_row['phase'] == profile['phase'] and s['phase'] in PHASES[kind]
        assert start['state_fingerprint'] == action_row['state_fingerprint']
        assert not profile['advisor_skipped'] and not action_row['advisor_skipped']
        next_start = index['started'].get(step + 1)
        if next_start:
            assert next_start['state_fingerprint'] == resolved['state_fingerprint']
            assert next_start['snapshot']['dollars'] == s['dollars'] + resolved['dollars_delta']
        entry = {'step': step, 'phase': s['phase'], 'ante': s['ante'], 'round': s['round'], 'action': action,
                 'dollars_before': s['dollars'], 'dollars_delta': resolved['dollars_delta'],
                 'chips_delta': resolved['chips_delta'], 'source_state_after': resolved['state'],
                 'before_fingerprint': start['state_fingerprint'], 'after_fingerprint': resolved['state_fingerprint']}
        if kind in ('play', 'discard'):
            selected = action['indices']
            assert 1 <= len(selected) <= 5 and len(set(selected)) == len(selected)
            assert all(type(i) is int and 1 <= i <= len(s['hand']) for i in selected)
            assert all(not card.get('ability', {}).get('forced_selection') or i in selected for i, card in enumerate(s['hand'], 1))
            assert s['hands_left' if kind == 'play' else 'discards_left'] > 0
            entry['selected_cards'] = [slim(s['hand'][i - 1]) for i in selected]
        if kind == 'play':
            evidence = verified[step]
            assert evidence['scope'] == 'deterministic_score'
            assert evidence['predicted'] == evidence['actual'] == resolved['chips_delta'] == action_row['expected_score']
            assert not action_row['score_prediction']['uncertain']
            entry['score_verification'] = evidence
        if 'index' in action:
            area = s[action['area']]; assert 1 <= action['index'] <= len(area)
            card = area[action['index'] - 1]; assert card['key'] == action_row['card_key']
            entry['card'] = slim(card)
            if kind == 'sell':
                assert not card.get('ability', {}).get('eternal'); sales.append(entry.copy())
        if kind.startswith('reorder_'):
            area = s['hand' if kind == 'reorder_hand' else 'jokers']; order = action['order']
            assert sorted(order) == list(range(1, len(area) + 1))
            assert all(not (area[i - 1].get('pinned') or area[i - 1].get('ability', {}).get('pinned')) or i == position for position, i in enumerate(order, 1))
        if next_start:
            ns = next_start['snapshot']
            for area in ('jokers', 'consumeables'):
                old = {c['id']: c for c in s[area]}; new = {c['id']: c for c in ns[area]}
                added = [slim(c) for key, c in new.items() if key not in old]
                removed = [slim(c) for key, c in old.items() if key not in new]
                if added or removed:
                    delta = {'step': step, 'action': action, 'ante': s['ante'], 'round': s['round'],
                             'area': area, 'added': added, 'removed': removed,
                             'before_count': len(old), 'after_count': len(new)}
                    inventory.append(delta)
                    if area == 'jokers' and added:
                        acquisition.append(delta)
        limit = 140000 if s['phase'] == 'hand' else 50000 if s['phase'] in ('shop', 'pack') else None
        if limit is not None:
            caps.append({'step': step, 'phase': s['phase'], 'score_calls': profile['score_calls'],
                         'evaluations': profile.get('evaluations'), 'limit': limit,
                         'within_cap': profile['score_calls'] <= limit and profile.get('evaluations', 0) <= limit})
        for label in ('fast_clear', 'clear_shortcut'):
            if result.get(label):
                ceiling = 70 if label == 'fast_clear' else 140000
                shortcuts.append({'step': step, 'label': label, 'score_calls': profile['score_calls'],
                                  'limit': ceiling, 'within_cap': profile['score_calls'] <= ceiling,
                                  'diagnostics': result[label]})
        if result.get('gold_diagnostics'):
            gold.append({'step': step, 'action': action, 'diagnostics': result['gold_diagnostics']})
        profiles.append(profile); actions.append(entry); counts[kind] += 1
    assert counts['play'] == len(verified)
    last = index['started'][max(index['started'])]
    context = rows['engine_gold_objective_context']
    audit = {
        'schema': 1, 'job': job, 'status': 'audited_selected_synthetic_loss' if outcome else 'audited_selected_synthetic_timeout_censored',
        'disposition': 'loss' if outcome else 'timeout', 'terminal_outcome': outcome,
        'observed_wins': 0, 'observed_losses': int(outcome == 'loss'), 'censored_timeouts': int(outcome is None),
        'completed_runs': int(outcome is not None), 'complete_attempt_leases_spent': 1,
        'qualification': False, 'player_achievement_progress': False, 'jokerless_win': False,
        'scope': 'Selected synthetic normal Red Deck Gold development. Audit only; no replay, player-save access or new simulation. Previously inspected M4 data is dependent; S05 selection was not preregistered unseen validation.',
        'policy_digest': provenance['policy_digest'], 'provenance': provenance,
        'metadata': registration['metadata'], 'profile': provenance['profile_spec'], 'retry_context': retry,
        'trace_parsing': parsing, 'event_counts': {key: len(value) for key, value in rows.items() if value},
        'started_decisions': len(index['started']), 'completed_decisions': len(completed), 'unfinished_decision_steps': pending,
        'source_legal_resolved_actions': len(completed), 'action_counts': dict(counts),
        'legality_scope': 'Each counted chosen action has matched policy/start/action/resolved/profile receipts and source callback completion. Audit additionally checks phase, selected indices/forced cards, physical permutations/pinning, cash/fingerprint continuity and exact selected plays. No unselected-action or whole-adapter qualification.',
        'score_verification': {'exact': len(verified), 'supported_floors': 0,
                               'mismatches': len(rows['engine_episode_score_mismatch']),
                               'unverified': len(rows['engine_episode_score_unverified']), 'random_or_unknown_gaps': 0,
                               'scope': 'Completed selected plays only; no imputation for unfinished advice.'},
        'effect_verification': rows['engine_episode_effect_verified'],
        'budget': {'phase_decisions': caps, 'clear_shortcuts': shortcuts,
                   'violations': [c for c in caps + shortcuts if not c['within_cap']],
                   'maximum_completed_score_calls': max(p['score_calls'] for p in profiles),
                   'unfinished_decision_score_calls': None,
                   'component_note': 'Per-consumable work is not emitted for every module call; no absent local counters were imputed. Frozen allocation and ordinary fixtures remain separate evidence.'},
        'timing': {'outer_seconds': record['elapsed_seconds'], 'outer_cap_seconds': 180,
                   'completed_advisor_seconds': sum(p['advisor_seconds'] for p in profiles),
                   'completed_snapshot_seconds': sum(p['snapshot_seconds'] for p in profiles),
                   'completed_source_effect_seconds': sum(p['engine_seconds'] for p in rows['engine_episode_resolved']),
                   'completed_score_calls': sum(p['score_calls'] for p in profiles),
                   'adapter_timing_receipt': rows['engine_probe_timing'],
                   'unfinished_decision_seconds': None,
                   'note': 'Completed component totals exclude any unfinished decision. Outer timeout includes enforcement overhead; no unfinished time, action, result, terminal or population is imputed.'},
        'terminal_receipt': terminal, 'terminal_context_receipts': rows['engine_episode_terminal_context'],
        'last_observed_state': compact_snapshot(last['snapshot']), 'last_observed_state_step': last['step'],
        'last_observed_state_fingerprint': last['state_fingerprint'], 'last_completed_action': actions[-1],
        'cleared_blinds': counts['cash_out'], 'actual_joker_acquisitions': acquisition,
        'actual_sales': sales, 'observed_inventory_changes': inventory,
        'terminal_retention_note': 'C03 source terminal context records the actual loss row; C04 has only last-observed holdings, with terminal retention/progress unknown.',
        'gold_objective_context': context, 'gold_diagnostics': gold,
        'gold_progress_callbacks': [], 'gold_progress_note': 'No completed Gold progress callback was observed; missing-Joker acquisitions and partial survival do not award stickers.',
        'repeated_public_state_fingerprints': [steps for steps in repeats.values() if len(steps) > 1],
        'actions': actions, 'trace_sha256': sha(folder / 'trace.log'),
        'record_sha256': sha(folder / 'record.json'), 'registration_sha256': sha(folder / 'registration.json'),
        'auditor_sha256': sha(Path(__file__)), 'helper_sha256': sha(Path(__file__).with_name('audit_c02.py')),
        'frozen_files_rechecked': True,
        'external_provenance': 'Original runner verified source/runtime hashes unchanged. This audit did not open or execute external game binaries.'}
    with (folder / 'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2)
    print(json.dumps({'job': job, 'status': audit['status'], 'audit_sha256': sha(folder / 'audit.json'),
                      'completed_decisions': len(completed), 'unfinished': pending,
                      'score_verification': audit['score_verification'], 'budget_violations': audit['budget']['violations'],
                      'timing': audit['timing'], 'action_counts': dict(counts),
                      'last_observed_state': audit['last_observed_state']}, indent=2))


if __name__ == '__main__':
    audit(sys.argv[1])
