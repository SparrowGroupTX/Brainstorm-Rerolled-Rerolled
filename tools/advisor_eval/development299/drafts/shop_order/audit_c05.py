"""Audit completed C05 bytes only; never imports an adapter or executes source/Lua.

Derived from the C03/C04 read-only auditor. Output is create-exclusive. Long
diagnostic strings are represented by length/hash; the original trace is retained.
"""
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import json

from audit_c02 import sha, digest, read_trace, slim, compact_snapshot
from audit_c03_c04 import PHASES

ROOT = Path(__file__).resolve().parents[5]
FOLDER = ROOT / 'tools/advisor_eval/runs/gold299_20260914/C05'
EXPECTED = {
    'registration': '2dd39ee79b29ca46fa0ac627eaf606fe217cd0d4e7eddba5bd6e7b3af412dd19',
    'trace': '29a061ce19b1a0a9385bdf89215ac685bdbee625b2518eb4ee3fb18b37906ef1',
    'policy': 'db847312d51d12055ffcb5e9ee5c010f6ccb57565467ab6faa50707a787ca406',
}


def compact(value):
    if isinstance(value, str) and len(value) > 1024:
        return {'long_string_characters': len(value), 'utf8_sha256': hashlib.sha256(value.encode()).hexdigest()}
    if isinstance(value, dict):
        return {key: compact(item) for key, item in value.items()}
    if isinstance(value, list):
        return [compact(item) for item in value]
    return value


def main():
    output = FOLDER / 'audit.json'
    if output.exists():
        raise FileExistsError('Existing audit is immutable: ' + str(output))
    record = json.loads((FOLDER / 'record.json').read_text())
    registration = json.loads((FOLDER / 'registration.json').read_text())
    rows, parsing = read_trace(FOLDER / 'trace.log')
    issues = []

    def check(condition, reason, step=None):
        if not condition:
            issues.append({'reason': reason, 'step': step})
        return bool(condition)

    def sole(kind):
        values = rows[kind]
        check(len(values) == 1, 'Expected one ' + kind)
        return values[0] if values else {}

    check(record.get('one_use_spent') is True, 'One-use receipt missing')
    check(record.get('timeout_seconds') == registration.get('timeout_seconds') == 180, 'Outer cap differs')
    check(record.get('frozen_files_unchanged') and record.get('external_files_unchanged'), 'Runner unchanged-byte receipt failed')
    for name in ('registration', 'trace'):
        path = FOLDER / (name + ('.json' if name == 'registration' else '.log'))
        check(sha(path) == record.get(name + '_sha256') == EXPECTED[name], name + ' digest mismatch')
    frozen_mismatches = []
    for name, expected in registration['files'].items():
        path = FOLDER / name
        if not path.is_file() or sha(path) != expected:
            frozen_mismatches.append(name)
    check(not frozen_mismatches, 'Registered frozen bytes differ')
    provenance = sole('engine_probe_provenance')
    check(provenance.get('policy_digest') == digest(provenance.get('policy_files')) == registration['metadata']['policy_digest'] == EXPECTED['policy'], 'Policy provenance mismatch')
    check(all(registration['files'].get('policy/' + name) == value for name, value in provenance.get('policy_files', {}).items()), 'Policy manifest differs')
    check(provenance.get('normal_run') == {'deck': 'b_red', 'stake': 8, 'qualification': False}, 'Normal-run scope mismatch')
    check(provenance.get('seed') == registration['metadata']['seed'] == 'S7PXV521', 'Seed differs')
    check(all(provenance.get(k) in registration['external_files'].values() for k in ('rules_digest', 'runtime_digest')), 'External provenance mismatch')
    for key in ('profile_spec', 'gold_objective_spec', 'retry_context_spec'):
        check(digest(provenance.get(key)) == provenance.get(key + '_digest'), key + ' digest mismatch')
    adapter_names = ('engine_probe.py', 'engine_probe.lua', 'engine_run.lua', 'engine_contract.lua', 'opening_support.py', 'benchmark.py', 'normal_recipe.py', 'normal_terminal.lua', 'gold_objective_spec.py', 'gold_objective_context.lua', 'policy_wiring.lua')
    check(digest({name: registration['files'][name] for name in adapter_names}) == provenance.get('adapter_digest'), 'Adapter digest differs')
    check(provenance.get('seed_selection', {}).get('evidence_digest') == sha(FOLDER / 'normal_seed_selection.json'), 'Selection digest differs')
    check(provenance.get('normal_filtered_opening', {}).get('recipe_digest') == sha(FOLDER / 'normal_opening_recipe.json'), 'Recipe digest differs')
    check(provenance.get('normal_filtered_opening', {}).get('native_search_executed_by_adapter') is False, 'Unexpected native search')
    profile = sole('engine_probe_profile')
    check(profile.get('profile') == 'all_unlocked_discovered_v1', 'Profile differs')
    retry = sole('engine_probe_retry_context')
    check(retry.get('checkpoint_reloads_observed') == 0 and retry.get('retry_context_spec', {}).get('mode') == 'disabled_clean_attempt_v1', 'Retry context differs')
    scope = sole('normal_attempt_scope')
    check(scope.get('max_actions') == 500 and scope.get('outer_seconds') == 180 and scope.get('selected_dependent_development') is True, 'Attempt/action cap differs')
    gold_context = sole('engine_gold_objective_context')
    check(gold_context.get('initial_empty_history_verified') and gold_context.get('initialized_before_decision') and gold_context.get('game_or_profile_mutated') is False, 'Natural Gold capture receipt failed')
    check(gold_context.get('initial_goal', {}).get('counts') == {'complete': 0, 'missing': 150, 'total': 150, 'unknown': 0}, 'Initial Gold counts differ')
    check(gold_context.get('initial_goal', {}).get('eligibility', {}).get('eligible') is True, 'Gold eligibility differs')
    wiring = sole('engine_policy_wiring')
    check(wiring.get('initialized_before_decision') is True and wiring.get('wiring', {}).get('gold_objective_enabled') is True, 'Policy wiring receipt differs')

    index = {}
    for kind in ('started', 'decision', 'action', 'resolved', 'profile'):
        name = 'engine_episode_decision_started' if kind == 'started' else 'engine_episode_' + kind
        index[kind] = {row['step']: row for row in rows[name]}
        check(len(index[kind]) == len(rows[name]), 'Duplicate ' + kind + ' step')
    completed = sorted(set.intersection(*(set(index[k]) for k in index)))
    check(completed == list(range(1, len(completed) + 1)), 'Resolved action receipts are not contiguous')
    check(sorted(index['started']) == list(range(1, len(index['started']) + 1)), 'Started steps are not contiguous')
    pending = sorted(set(index['started']) - set(completed))
    check(len(index['action']) <= 500, 'Action lease cap exceeded')
    terminal = rows['engine_episode_terminal']
    contexts = rows['engine_episode_terminal_context']
    independent_terminal = None
    if len(terminal) == 1:
        t = terminal[0]; evidence = t.get('normal_progress', {})
        final = evidence.get('final_context', {})
        threshold = isinstance(final.get('chips'), (int, float)) and isinstance(final.get('target'), (int, float)) and final['target'] > 0 and final['chips'] >= final['target']
        check(threshold == evidence.get('threshold_met'), 'Terminal threshold inconsistent')
        check(t.get('game_over') == evidence.get('game_over'), 'Terminal GAME_OVER inconsistent')
        if t.get('game_over') is True:
            independent_terminal = 'loss'
        elif (evidence.get('final_boss') and evidence.get('source_won') and evidence.get('deck_progress') and evidence.get('joker_progress') and (threshold or evidence.get('source_saved'))):
            independent_terminal = 'win'
        check(t.get('outcome') == independent_terminal, 'Terminal classification inconsistent')
        check(t.get('decisions') == len(completed), 'Terminal action count differs')
        check(len(contexts) == 1 and contexts[0].get('step') == t.get('decisions') and contexts[0].get('outcome') == independent_terminal, 'Terminal context receipt differs')
        if contexts:
            check(contexts[0]['snapshot'].get('chips') == final.get('chips'), 'Terminal snapshot chips differ')
    else:
        check(len(terminal) == 0, 'Multiple terminal rows')
    blocked = rows['engine_probe_blocked']
    if record.get('status') == 'timeout':
        disposition = 'timeout'
    elif blocked:
        disposition = 'unsupported' if all(r.get('unsupported') is True or r.get('status') == 'unsupported' for r in blocked) else 'error'
    elif record.get('status') != 'complete' or record.get('exit_code') != 0:
        disposition = 'error'
    elif independent_terminal:
        disposition = independent_terminal
    elif rows['engine_episode_stopped']:
        disposition = 'censored'
    else:
        disposition = 'unsupported'

    verified = {r['step']: r for r in rows['engine_episode_score_verified']}
    check(len(verified) == len(rows['engine_episode_score_verified']), 'Duplicate score verification')
    counts = Counter(); score_counts = Counter(); actions = []; inventory = []; packs = []; caps = []; shortcuts = []; gold = []
    legal_steps = []; repeats = defaultdict(list)
    for step, started in index['started'].items():
        repeats[started['state_fingerprint']].append(step)
    for step in completed:
        issue_start = len(issues)
        start, decision, action_row, resolved, prof = [index[k][step] for k in ('started', 'decision', 'action', 'resolved', 'profile')]
        s = start['snapshot']; action = action_row['action']; kind = action['kind']; result = decision['result']
        check(s == decision['snapshot'] and action == result['action'], 'Decision/action snapshot mismatch', step)
        check(s['phase'] == action_row['phase'] == prof['phase'] and s['phase'] in PHASES.get(kind, ()), 'Action phase illegal', step)
        check(start['state_fingerprint'] == action_row['state_fingerprint'], 'Start/action fingerprint differs', step)
        check(not prof['advisor_skipped'] and not action_row['advisor_skipped'], 'Advisor bypassed', step)
        after = index['started'].get(step + 1)
        ns = after['snapshot'] if after else contexts[0]['snapshot'] if contexts and contexts[0]['step'] == step else None
        if after:
            check(after['state_fingerprint'] == resolved['state_fingerprint'], 'Resolved/start continuity differs', step)
        if ns:
            check(ns['dollars'] == s['dollars'] + resolved['dollars_delta'], 'Cash continuity differs', step)
        entry = {'step': step, 'phase': s['phase'], 'ante': s['ante'], 'round': s['round'], 'action': action,
                 'dollars_before': s['dollars'], 'dollars_delta': resolved['dollars_delta'], 'chips_delta': resolved['chips_delta'],
                 'source_state_after': resolved['state'], 'before_fingerprint': start['state_fingerprint'], 'after_fingerprint': resolved['state_fingerprint']}
        if kind in ('play', 'discard'):
            selected = action['indices']
            valid = 1 <= len(selected) <= 5 and len(set(selected)) == len(selected) and all(type(i) is int and 1 <= i <= len(s['hand']) for i in selected)
            check(valid, 'Invalid physical selection', step)
            check(all(not c.get('ability', {}).get('forced_selection') or i in selected for i, c in enumerate(s['hand'], 1)), 'Forced selection omitted', step)
            check(s['hands_left' if kind == 'play' else 'discards_left'] > 0, 'No action resource', step)
            if valid:
                entry['selected_cards'] = [slim(s['hand'][i - 1]) for i in selected]
        if kind == 'play':
            v = verified.get(step)
            entry['score_verification'] = v
            if v and v.get('scope') == 'deterministic_score':
                exact = v['predicted'] == v['actual'] == resolved['chips_delta'] == action_row['expected_score'] and not action_row['score_prediction']['uncertain']
                check(exact, 'Exact score mismatch', step); score_counts['exact'] += int(exact)
            elif v and v.get('scope') == 'supported_random_floor':
                valid = v['actual'] == resolved['chips_delta'] and v['actual'] >= v['predicted']
                check(valid, 'Supported floor mismatch', step); score_counts['supported_floors'] += int(valid)
            else:
                score_counts['random_or_unknown_gaps'] += 1
        if 'index' in action:
            area = s.get(action['area'], []); valid = 1 <= action['index'] <= len(area)
            check(valid, 'Card index out of bounds', step)
            if valid:
                card = area[action['index'] - 1]; entry['card'] = slim(card)
                check(card['key'] == action_row['card_key'], 'Selected card identity differs', step)
                if kind == 'sell':
                    check(not card.get('ability', {}).get('eternal'), 'Eternal Joker sold', step)
        if kind.startswith('reorder_'):
            area = s['hand' if kind == 'reorder_hand' else 'jokers']; order = action['order']
            valid = sorted(order) == list(range(1, len(area) + 1))
            check(valid, 'Invalid physical order', step)
            if valid:
                check(all(not (area[i - 1].get('pinned') or area[i - 1].get('ability', {}).get('pinned')) or i == pos for pos, i in enumerate(order, 1)), 'Pinned card moved', step)
        if ns:
            for area in ('jokers', 'consumeables'):
                old = {c['id']: c for c in s[area]}; new = {c['id']: c for c in ns[area]}
                added = [slim(c) for key, c in new.items() if key not in old]; removed = [slim(c) for key, c in old.items() if key not in new]
                if added or removed:
                    inventory.append({'step': step, 'action': action, 'ante': s['ante'], 'area': area, 'added': added, 'removed': removed, 'before_count': len(old), 'after_count': len(new)})
        if s['phase'] == 'pack':
            diag = action_row.get('pack_diagnostics', {})
            packs.append({'step': step, 'actual_action': action, 'offered_cards': [slim(c) for c in action_row.get('offered_cards', [])],
                          'selected_card': entry.get('card'), 'pack_diagnostics': compact(diag),
                          'source_completed': True, 'survival_priority': diag.get('survival_priority'),
                          'interpretation': 'Actual selected action and source receipt. Forecast and family rejection are local policy evidence, not an alternative outcome.'})
        cap = 50000 if s['phase'] in ('shop', 'pack') else 140000
        caps.append({'step': step, 'phase': s['phase'], 'score_calls': prof['score_calls'], 'evaluations': prof.get('evaluations'), 'limit': cap,
                     'within_cap': prof['score_calls'] <= cap and prof.get('evaluations', 0) <= cap})
        for label, limit in (('fast_clear', 70), ('clear_shortcut', 140000)):
            if result.get(label):
                shortcuts.append({'step': step, 'label': label, 'score_calls': prof['score_calls'], 'limit': limit, 'within_cap': prof['score_calls'] <= limit, 'diagnostics': compact(result[label])})
        if result.get('gold_diagnostics'):
            gold.append({'step': step, 'action': action, 'diagnostics': compact(result['gold_diagnostics'])})
        if len(issues) == issue_start:
            legal_steps.append(step)
        counts[kind] += 1; actions.append(entry)

    check(not rows['engine_episode_illegal_action'], 'Source illegal action receipt')
    check(not rows['engine_episode_score_mismatch'], 'Source score mismatch receipt')
    budget_violations = [x for x in caps + shortcuts if not x['within_cap']]
    check(not budget_violations, 'Score cap exceeded')
    last = index['started'].get(max(index['started'])) if index['started'] else None
    terminal_snapshot = contexts[0]['snapshot'] if len(contexts) == 1 else None
    profs = [index['profile'][step] for step in completed]
    audit = {
        'schema': 2, 'job': 'C05', 'status': 'audited_selected_synthetic_' + disposition if not issues else 'audit_issues_preserved',
        'disposition': disposition, 'runner_status': record.get('status'), 'runner_exit_code': record.get('exit_code'),
        'terminal_outcome': independent_terminal, 'outcome_counts': {k: int(disposition == k) for k in ('win', 'loss', 'error', 'unsupported', 'timeout', 'censored')},
        'observed_wins': int(disposition == 'win'), 'observed_losses': int(disposition == 'loss'),
        'completed_runs': int(disposition in ('win', 'loss')), 'complete_attempt_leases_spent': 1,
        'qualification': False, 'player_achievement_progress': False, 'jokerless_win': False,
        'scope': 'Selected dependent synthetic normal Red Gold S7PXV521, exact frozen312. C03 used this seed with Gold context disabled; policy and explicit Gold context both changed. No isolated causal effect, unseen validation, player win odds or human-superiority claim.',
        'policy_digest': provenance.get('policy_digest'), 'provenance': provenance, 'metadata': registration['metadata'],
        'retry_context': retry, 'policy_wiring': wiring, 'gold_objective_context': gold_context,
        'trace_parsing': parsing, 'event_counts': {k: len(v) for k, v in rows.items() if v}, 'audit_issues': issues,
        'started_decisions': len(index['started']), 'completed_decisions': len(completed), 'unfinished_decision_steps': pending,
        'partial_step_receipts': {kind: sorted(set(values) - set(completed)) for kind, values in index.items()},
        'source_legal_resolved_actions': len(legal_steps), 'source_legal_steps': legal_steps, 'action_counts': dict(counts),
        'legality_scope': 'Counted chosen actions match policy/start/action/resolved/profile receipts and original callback completion; additional phase, selection/forced-card, order/pinning, cash/fingerprint and selected-score checks. Unselected actions and whole adapter remain unqualified.',
        'score_verification': {**{k: score_counts[k] for k in ('exact', 'supported_floors', 'random_or_unknown_gaps')}, 'mismatches': len(rows['engine_episode_score_mismatch']), 'unverified': len(rows['engine_episode_score_unverified'])},
        'score_receipts': rows['engine_episode_score_verified'], 'score_unverified_receipts': rows['engine_episode_score_unverified'],
        'effect_verification': rows['engine_episode_effect_verified'], 'blocked_receipts': blocked,
        'stopped_receipts': rows['engine_episode_stopped'], 'terminal_receipt': terminal,
        'terminal_state': compact_snapshot(terminal_snapshot) if terminal_snapshot else None,
        'terminal_goal': terminal_snapshot.get('completionist_goal') if terminal_snapshot else None,
        'last_observed_state': compact_snapshot(last['snapshot']) if last else None, 'last_observed_state_step': last['step'] if last else None,
        'last_completed_action': actions[-1] if actions else None, 'cleared_blinds': counts['cash_out'],
        'actual_joker_acquisitions': [r for r in inventory if r['area'] == 'jokers' and r['added']],
        'actual_sales': [a for a in actions if a['action']['kind'] == 'sell'], 'observed_inventory_changes': inventory,
        'pack_choices_and_receipts': packs, 'gold_diagnostics': gold, 'gold_progress_callbacks': rows['engine_normal_progress_callback'],
        'gold_progress_note': 'Original progress callbacks and terminal captured counts determine actual synthetic progress. Acquisition, partial survival and forecasts are not sticker awards; terminal retention is unknown when no terminal snapshot exists.',
        'budget': {'phase_decisions': caps, 'clear_shortcuts': shortcuts, 'violations': budget_violations,
                   'maximum_completed_score_calls': max((p['score_calls'] for p in profs), default=0), 'unfinished_decision_score_calls': None,
                   'local_component_scope': 'No absent per-consumable/module-call counter is imputed. Consumable25000 and prehand family50000 local allocation guards remain separate frozen-code/fixture evidence.'},
        'timing': {'outer_seconds': record['elapsed_seconds'], 'outer_cap_seconds': 180,
                   'completed_advisor_seconds': sum(p['advisor_seconds'] for p in profs), 'completed_snapshot_seconds': sum(p['snapshot_seconds'] for p in profs),
                   'completed_source_effect_seconds': sum(index['resolved'][s]['engine_seconds'] for s in completed),
                   'completed_score_calls': sum(p['score_calls'] for p in profs), 'adapter_timing_receipt': rows['engine_probe_timing'],
                   'unfinished_decision_seconds': None, 'note': 'Recorded component times and action counts only. No absent/unfinished action, timing, progress, terminal or alternative route outcome is imputed.'},
        'repeated_public_state_fingerprints': [steps for steps in repeats.values() if len(steps) > 1], 'actions': actions,
        'frozen_files_rechecked': len(registration['files']), 'frozen_file_mismatches': frozen_mismatches,
        'trace_sha256': sha(FOLDER / 'trace.log'), 'record_sha256': sha(FOLDER / 'record.json'), 'registration_sha256': sha(FOLDER / 'registration.json'),
        'auditor_sha256': sha(Path(__file__)), 'helper_sha256': {name: sha(Path(__file__).with_name(name)) for name in ('audit_c02.py', 'audit_c03_c04.py')},
        'external_provenance': 'Runner source/runtime hash receipts checked against registration; this auditor neither opened nor executed external game binaries.',
        'diagnostic_projection': 'Strings longer than1024 characters retain character length and UTF8 SHA256; original trace is unchanged.',
    }
    with output.open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2)
    print(json.dumps({'audit_sha256': sha(output), **{k: audit[k] for k in ('status', 'disposition', 'audit_issues', 'completed_decisions', 'unfinished_decision_steps', 'source_legal_resolved_actions', 'score_verification', 'action_counts', 'timing')}, 'budget_violations': budget_violations}, indent=2))


if __name__ == '__main__':
    main()
