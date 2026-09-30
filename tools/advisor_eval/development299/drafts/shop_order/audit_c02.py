"""Read-only audit of preserved C02 timeout; no source/runtime execution."""
from pathlib import Path
from collections import Counter, defaultdict
import hashlib
import json

ROOT = Path(__file__).resolve().parents[5]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
FOLDER = BASE / 'C02'


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def read_trace(path):
    rows = defaultdict(list); malformed = []; offset = 0; non_json = 0
    with path.open('rb') as stream:
        for line_number, line in enumerate(stream, 1):
            start = offset; offset += len(line)
            if not line.startswith(b'{'):
                non_json += bool(line.strip()); continue
            try:
                row = json.loads(line)
            except (json.JSONDecodeError, UnicodeDecodeError) as error:
                malformed.append({'line': line_number, 'byte_offset': start, 'bytes': len(line),
                                  'complete_line': line.endswith(b'\n'), 'reason': str(error),
                                  'raw_sha256': hashlib.sha256(line).hexdigest()})
                break  # Never recover an action/outcome from an incomplete row.
            rows[row['type']].append(row)
    return rows, {'malformed_rows': malformed, 'non_json_lines': non_json,
                  'bytes_read': offset, 'file_bytes': path.stat().st_size,
                  'stopped_at_first_incomplete_json': bool(malformed)}


def indexed(rows, kind):
    name = 'engine_episode_decision_started' if kind == 'started' else 'engine_episode_' + kind
    result = {row['step']: row for row in rows[name]}
    assert len(result) == len(rows[name]), 'Duplicate step receipt: ' + kind
    return result


def slim(card):
    result = {key: card[key] for key in ('key', 'id', 'cost', 'sell_cost', 'edition', 'rank', 'suit', 'enhancement') if key in card}
    result.update({key: value for key, value in card.get('ability', {}).items() if key in ('eternal', 'perishable', 'rental')})
    return result


def compact_snapshot(snapshot):
    result = {key: snapshot.get(key) for key in ('ante', 'round', 'phase', 'dollars', 'chips',
                                               'hands_left', 'discards_left', 'hands_played', 'discards_used',
                                               'deck_key', 'stake', 'joker_limit', 'consumable_limit', 'blind')}
    for area in ('jokers', 'consumeables', 'hand'):
        result[area] = [slim(card) for card in snapshot.get(area, [])]
    result['playing_population'] = len(snapshot.get('playing_cards', []))
    result['remaining_draw_count'] = len(snapshot.get('deck', []))
    return result


def main():
    record = json.loads((FOLDER / 'record.json').read_text())
    registration = json.loads((FOLDER / 'registration.json').read_text())
    assert record['status'] == 'timeout' and record['exit_code'] is None and record['one_use_spent']
    assert record['timeout_seconds'] == registration['timeout_seconds'] == 180
    assert record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert sha(FOLDER / 'registration.json') == record['registration_sha256']
    assert sha(FOLDER / 'trace.log') == record['trace_sha256']
    for name, expected in registration['files'].items():
        assert sha(FOLDER / name) == expected, 'Changed registered input: ' + name
    rows, parsing = read_trace(FOLDER / 'trace.log')
    baseline, baseline_parsing = read_trace(BASE / 'C01/trace.log')
    old_registration = json.loads((BASE / 'C01/registration.json').read_text())
    old_audit = json.loads((BASE / 'C01/audit.json').read_text())
    assert sha(BASE / 'C01/trace.log') == old_audit['trace_sha256']
    provenance = rows['engine_probe_provenance'][0]
    assert provenance['policy_digest'] == digest(provenance['policy_files']) == registration['metadata']['policy_digest']
    assert all(registration['files']['policy/' + name] == value for name, value in provenance['policy_files'].items())
    assert provenance['normal_run'] == {'deck': 'b_red', 'stake': 8, 'qualification': False}
    assert provenance['seed'] == registration['metadata']['seed'] == 'M4BVSY11'
    assert provenance['rules_digest'] in registration['external_files'].values()
    assert provenance['runtime_digest'] in registration['external_files'].values()
    assert provenance['seed_selection']['evidence_digest'] == sha(FOLDER / 'normal_seed_selection.json')
    assert provenance['normal_filtered_opening']['recipe_digest'] == sha(FOLDER / 'normal_opening_recipe.json')
    assert not provenance['normal_filtered_opening']['native_search_executed_by_adapter']
    assert rows['engine_probe_profile'][0]['profile'] == 'all_unlocked_discovered_v1'
    retry = rows['engine_probe_retry_context'][0]
    assert retry['checkpoint_reloads_observed'] == 0 and retry['retry_context_spec']['mode'] == 'disabled_clean_attempt_v1'
    assert not rows['engine_normal_synthetic_progress_enabled']

    kinds = ('started', 'decision', 'action', 'resolved', 'profile')
    index = {kind: indexed(rows, kind) for kind in kinds}
    old_index = {kind: indexed(baseline, kind) for kind in kinds}
    completed = sorted(set(index['decision']) & set(index['action']) & set(index['resolved']) & set(index['profile']))
    assert completed == list(range(1, len(completed) + 1))
    assert sorted(index['started']) == list(range(1, max(index['started']) + 1))
    pending = sorted(set(index['started']) - set(completed))
    assert not any(rows[key] for key in ('engine_episode_terminal', 'engine_normal_progress_callback', 'engine_normal_final_round_entered'))
    phases = {'play': ('hand',), 'discard': ('hand',), 'buy': ('shop',), 'open': ('shop',),
              'buy_and_use': ('shop',), 'choose': ('pack',), 'cash_out': ('round',), 'leave_shop': ('shop',),
              'reroll': ('shop',), 'skip_pack': ('pack',), 'select_blind': ('blind',), 'skip_blind': ('blind',),
              'reorder_hand': ('hand', 'pack'), 'use': ('hand', 'shop', 'blind', 'pack', 'round'),
              'sell': ('hand', 'shop', 'blind', 'pack', 'round'),
              'reorder_jokers': ('hand', 'shop', 'blind', 'pack', 'round')}
    verified = {row['step']: row for row in rows['engine_episode_score_verified']}
    actions, counts, caps, acquisitions, sales, continuity = [], Counter(), [], [], [], []
    profiles = []; fast_clear = []; component_caps = []
    for step in completed:
        start, decision, action_row, resolved, profile = (index[kind][step] for kind in kinds)
        snapshot = start['snapshot']; action = action_row['action']; kind = action['kind']
        assert snapshot == decision['snapshot'] and action == decision['result']['action']
        assert snapshot['phase'] == action_row['phase'] == profile['phase'] and snapshot['phase'] in phases[kind]
        assert start['state_fingerprint'] == action_row['state_fingerprint']
        assert not profile['advisor_skipped'] and not action_row['advisor_skipped']
        following = index['started'].get(step + 1)
        if following:
            if following['state_fingerprint'] != resolved['state_fingerprint']:
                continuity.append(step)
            assert following['snapshot']['dollars'] == snapshot['dollars'] + resolved['dollars_delta']
        entry = {'step': step, 'ante': snapshot['ante'], 'round': snapshot['round'], 'phase': snapshot['phase'],
                 'action': action, 'dollars_before': snapshot['dollars'], 'dollars_delta': resolved['dollars_delta'],
                 'chips_delta': resolved['chips_delta'], 'source_state_after': resolved['state'],
                 'before_fingerprint': start['state_fingerprint'], 'after_fingerprint': resolved['state_fingerprint']}
        if kind in ('play', 'discard'):
            chosen = action['indices']; hand = snapshot['hand']
            assert 1 <= len(chosen) <= 5 and len(set(chosen)) == len(chosen)
            assert all(type(i) is int and 1 <= i <= len(hand) for i in chosen)
            assert all(not card.get('ability', {}).get('forced_selection') or i in chosen for i, card in enumerate(hand, 1))
            assert snapshot['hands_left' if kind == 'play' else 'discards_left'] > 0
            entry['selected_cards'] = [slim(hand[i - 1]) for i in chosen]
        if kind == 'play':
            evidence = verified[step]
            assert evidence['scope'] == 'deterministic_score'
            assert evidence['predicted'] == evidence['actual'] == resolved['chips_delta'] == action_row['expected_score']
            assert action_row['score_prediction']['uncertain'] is False
            entry['score_verification'] = evidence
        if 'index' in action:
            area = snapshot[action['area']]; assert 1 <= action['index'] <= len(area)
            card = area[action['index'] - 1]; assert card['key'] == action_row['card_key']
            entry['card'] = slim(card)
            if kind == 'sell':
                assert not card.get('ability', {}).get('eternal'); sales.append(entry.copy())
            if kind in ('buy', 'choose') and card.get('ability', {}).get('set') == 'Joker':
                acquisitions.append(entry.copy())
        if kind.startswith('reorder_'):
            area = snapshot['hand' if kind == 'reorder_hand' else 'jokers']; order = action['order']
            assert sorted(order) == list(range(1, len(area) + 1))
            assert all(not (area[i - 1].get('pinned') or area[i - 1].get('ability', {}).get('pinned')) or i == position
                       for position, i in enumerate(order, 1))
        limit = 140000 if snapshot['phase'] == 'hand' else 50000 if snapshot['phase'] in ('shop', 'pack') else None
        if limit is not None:
            caps.append({'step': step, 'phase': snapshot['phase'], 'score_calls': profile['score_calls'],
                         'reported_evaluations': profile.get('evaluations'), 'cap': limit,
                         'within_cap': profile['score_calls'] <= limit and profile.get('evaluations', 0) <= limit})
        result = decision['result']
        if result.get('fast_clear'):
            fast_clear.append({'step': step, 'score_calls': profile['score_calls'], 'within_cap': profile['score_calls'] <= 70,
                               'cap': 70, 'fast_clear': result['fast_clear']})
        for name, limit in (('consumable_diagnostics', 25000), ('phase_copy_diagnostics', 30)):
            diagnostic = result.get(name) or {}
            value = diagnostic.get('evaluations', diagnostic.get('score_calls'))
            if isinstance(value, (int, float)):
                component_caps.append({'step': step, 'component': name, 'score_calls': value,
                                       'cap': limit, 'within_cap': value <= limit})
        profiles.append(profile); actions.append(entry); counts[kind] += 1
    assert not continuity
    assert counts['play'] == len(verified)
    cap_violations = [row for row in caps + fast_clear + component_caps if not row['within_cap']]
    state_groups = defaultdict(list)
    for step, row in index['started'].items():
        state_groups[row['state_fingerprint']].append(step)
    repeated = [steps for steps in state_groups.values() if len(steps) > 1]

    aligned = []
    old_by_fingerprint = {row['state_fingerprint']: step for step, row in old_index['started'].items()}
    for step in completed:
        old_step = old_by_fingerprint.get(index['started'][step]['state_fingerprint'])
        if old_step is not None:
            before, after = old_index['profile'][old_step], index['profile'][step]
            aligned.append({'c01_step': old_step, 'c02_step': step, 'same_action': old_index['action'][old_step]['action'] == index['action'][step]['action'],
                            'before_score_calls': before['score_calls'], 'after_score_calls': after['score_calls'],
                            'before_advisor_seconds': before['advisor_seconds'], 'after_advisor_seconds': after['advisor_seconds']})
    action_differences = [step for step in completed if step in old_index['action'] and
                          old_index['action'][step]['action'] != index['action'][step]['action']]
    divergence = []
    for step in (92, 93, 94, 121, 122):
        sides = {}
        for name, selected in (('C01', old_index), ('C02', index)):
            s = selected['started'][step]['snapshot']; r = selected['decision'][step]['result']
            sides[name] = {'action': selected['action'][step]['action'], 'input_fingerprint': selected['started'][step]['state_fingerprint'],
                           'joker_keys': [card['key'] for card in s['jokers']],
                           'score_calls': selected['profile'][step]['score_calls'],
                           'ordering_diagnostics': r.get('ordering_diagnostics'),
                           'consumable_diagnostics': {k: v for k, v in (r.get('consumable_diagnostics') or {}).items()
                                                    if not isinstance(v, (list, dict))}}
        divergence.append({'step': step, **sides})
    adapter_names = [name for name in registration['files'] if name in old_registration['files'] and
                     not name.startswith('policy/') and name not in ('installed_policy_record.json', 'baseline_attempt_audit.json')]
    adapter_changed = [name for name in adapter_names if registration['files'][name] != old_registration['files'][name]]
    assert not adapter_changed
    last_started = index['started'][max(index['started'])]
    last_completed = actions[-1]
    audit = {'schema': 1, 'job': 'C02', 'status': 'audited_selected_synthetic_timeout_censored',
             'complete_attempt_leases_spent': 1, 'completed_runs': 0, 'observed_wins': 0, 'observed_losses': 0,
             'censored_timeouts': 1, 'terminal_outcome': None, 'terminal_result': 'unknown; timeout while decision198 was in progress',
             'qualification': False, 'player_achievement_progress': False, 'jokerless_win': False,
             'scope': 'Fresh dependent selected original-source Red Deck Gold attempt on frozen301 and same C01 adapter. Partial trace audit only; no replay or new simulation.',
             'profile': provenance['profile_spec'], 'seed_selection': provenance['seed_selection'],
             'retry_context': retry, 'policy_digest': provenance['policy_digest'], 'provenance': provenance,
             'metadata': registration['metadata'], 'trace_parsing': parsing,
             'event_counts': {key: len(value) for key, value in rows.items() if value},
             'completed_decisions': len(completed), 'started_decisions': len(index['started']), 'unfinished_decision_steps': pending,
             'source_legal_resolved_actions': len(completed), 'action_counts': dict(counts),
             'legality_scope': 'Every counted action has matching policy/start/action/resolved/profile receipts and passed original dispatcher callbacks. Independent audit checks phases, selections, forced cards, exact physical permutations, cash/fingerprint continuity and played scores. No unselected-candidate or full-adapter qualification.',
             'score_verification': {'exact': len(verified), 'supported_floors': 0,
                                    'mismatches': len(rows['engine_episode_score_mismatch']),
                                    'unverified': len(rows['engine_episode_score_unverified']),
                                    'random_or_unknown_gaps': 0,
                                    'scope': 'Completed selected plays only; unfinished decision198 has no selected action.'},
             'budget': {'completed_phase_decisions': caps, 'fast_clear_decisions': fast_clear,
                        'reported_component_checks': component_caps, 'violations': cap_violations,
                        'fast_clear_note': 'Steps102/103 carry fast_clear after finding a clear at exhaustive indices168/113, yielding173/117 total calls. These exceed a literal70-total fast-clear cap, although both fit the ordinary allowance. C01 has the same observations; classification versus total-budget semantics requires an explicit repair/audit.',
                        'maximum_completed_score_calls': max(p['score_calls'] for p in profiles),
                        'incomplete_decision_score_calls': None,
                        'consumable_limit_note': 'Individual consumable score totals are not emitted for every call; the frozen policy allocation and synthetic validation are separate evidence. No absent component count was imputed.'},
             'timing': {'outer_seconds': record['elapsed_seconds'], 'outer_cap_seconds': 180,
                        'completed_advisor_seconds': sum(p['advisor_seconds'] for p in profiles),
                        'completed_snapshot_seconds': sum(p['snapshot_seconds'] for p in profiles),
                        'completed_source_effect_seconds': sum(r['engine_seconds'] for r in rows['engine_episode_resolved']),
                        'completed_score_calls': sum(p['score_calls'] for p in profiles),
                        'unfinished_decision_seconds': None, 'adapter_total_receipt_present': bool(rows['engine_probe_timing']),
                        'note': 'Completed component totals exclude unfinished decision198. Outer timeout is preserved, including scheduler enforcement overhead; no cost or result is imputed.'},
             'last_completed_action': last_completed,
             'last_observed_state': compact_snapshot(last_started['snapshot']),
             'last_observed_state_fingerprint': last_started['state_fingerprint'],
             'last_observed_state_step': last_started['step'],
             'cleared_blinds': counts['cash_out'],
             'actual_joker_acquisitions': acquisitions, 'actual_sales': sales,
             'perkeo_result': 'Opening Perkeo remained held in the last observed Ante7 Big state; no terminal retention or Gold increment is established.',
             'burnt_result': 'The same Ante3 visible offer was not acquired; owned Eternal fillers left only Yorick/Perkeo sellable. No terminal outcome is known.',
             'repeated_public_state_fingerprints': repeated,
             'comparison_with_C01': {'same_adapter_files_checked': adapter_names, 'changed_adapter_files': adapter_changed,
                                    'same_external_source_runtime_hashes': registration['external_files'] == old_registration['external_files'],
                                    'baseline_policy_digest': old_audit['policy_digest'],
                                    'first_action_divergence': action_differences[0],
                                    'divergence_evidence': divergence,
                                    'interpretation': 'Steps92/93 commute Empress use and reorder and reconverge at exact state94. At121 the capped family selects an intermediate order;122 adds another legal reorder. Different physical filler positions persist and later shop choices diverge, including retaining Perkeo at C02step140. No action loop or repeated fingerprint was observed. Lower per-decision score calls did not demonstrate a faster terminal run.',
                                    'matched_input_decisions': aligned,
                                    'matched_input_score_calls_before': sum(r['before_score_calls'] for r in aligned),
                                    'matched_input_score_calls_after': sum(r['after_score_calls'] for r in aligned),
                                    'matched_input_advisor_seconds_before': sum(r['before_advisor_seconds'] for r in aligned),
                                    'matched_input_advisor_seconds_after': sum(r['after_advisor_seconds'] for r in aligned),
                                    'timing_limit': 'One dependent selected route with changing actions and runtime variation; these are observations, not calibrated throughput or win odds.'},
             'actions': actions, 'trace_sha256': sha(FOLDER / 'trace.log'),
             'registration_sha256': sha(FOLDER / 'registration.json'), 'record_sha256': sha(FOLDER / 'record.json'),
             'auditor_sha256': sha(Path(__file__)),
             'frozen_files_rechecked': True, 'external_hash_evidence': 'Original runner verified source/runtime hashes unchanged; this read-only audit did not reread or execute external game binaries.'}
    with (FOLDER / 'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2)
    print(json.dumps({key: audit[key] for key in ('status', 'completed_decisions', 'started_decisions', 'action_counts',
                                                'score_verification', 'timing', 'cleared_blinds', 'last_observed_state_step')}, indent=2))


if __name__ == '__main__':
    main()
