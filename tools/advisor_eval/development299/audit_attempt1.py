"""Read-only, one-use audit of the completed C01 source trace; no simulation."""
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import json

FOLDER = Path(__file__).resolve().parents[1] / 'runs/gold299_20260914/C01'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def cards(snapshot, area):
    value = snapshot.get(area, [])
    return value if isinstance(value, list) else []


def slim(card):
    return {k: card[k] for k in ('key', 'id', 'cost', 'sell_cost', 'edition', 'enhancement', 'rank', 'suit') if k in card} | {
        k: card.get('ability', {}).get(k) for k in ('eternal', 'perishable', 'rental') if k in card.get('ability', {})}


def main():
    record = json.loads((FOLDER / 'record.json').read_text())
    registration = json.loads((FOLDER / 'registration.json').read_text())
    assert record['status'] == 'complete' and record['exit_code'] == 0
    assert record['frozen_files_unchanged'] and record['external_files_unchanged'] and record['one_use_spent']
    assert record['elapsed_seconds'] < registration['timeout_seconds'] == 180
    assert sha(FOLDER / 'registration.json') == record['registration_sha256']
    assert sha(FOLDER / 'trace.log') == record['trace_sha256']
    for name, expected in registration['files'].items():
        assert sha(FOLDER / name) == expected, name
    rows = defaultdict(list)
    with (FOLDER / 'trace.log').open() as stream:
        for line in stream:
            if line.startswith('{'):
                row = json.loads(line)
                rows[row['type']].append(row)
    forbidden = ['engine_episode_score_mismatch', 'engine_episode_score_unverified', 'engine_episode_failure_context',
                 'engine_episode_stopped', 'engine_episode_replay_verified', 'engine_normal_synthetic_progress_enabled']
    assert not any(rows[k] for k in forbidden)
    provenance = rows['engine_probe_provenance'][0]
    assert provenance['policy_digest'] == digest(provenance['policy_files'])
    assert all(registration['files']['policy/' + name] == value for name, value in provenance['policy_files'].items())
    assert set(provenance['policy_files']) == {name[7:] for name in registration['files'] if name.startswith('policy/')}
    metadata = registration['metadata']
    assert provenance['rules_digest'] in registration['external_files'].values()
    assert provenance['runtime_digest'] in registration['external_files'].values()
    assert metadata['seed'] == provenance['seed'] == 'M4BVSY11'
    assert metadata['gold_objective_context'].startswith('disabled')
    assert provenance['normal_run'] == {'deck': 'b_red', 'stake': 8, 'qualification': False}
    assert provenance['seed_selection']['evidence_digest'] == sha(FOLDER / 'normal_seed_selection.json')
    assert provenance['normal_filtered_opening']['recipe_digest'] == sha(FOLDER / 'normal_opening_recipe.json')
    assert provenance['normal_filtered_opening']['native_search_executed_by_adapter'] is False
    retry = rows['engine_probe_retry_context'][0]
    assert retry['checkpoint_reloads_observed'] == 0 and retry['retry_context_spec']['mode'] == 'disabled_clean_attempt_v1'
    assert rows['engine_probe_profile'][0]['profile'] == 'all_unlocked_discovered_v1'
    per_step = {}
    for kind in ('started', 'decision', 'action', 'resolved', 'profile'):
        name = 'engine_episode_decision_started' if kind == 'started' else 'engine_episode_' + kind
        assert [r['step'] for r in rows[name]] == list(range(1, 226)), name
        per_step[kind] = {r['step']: r for r in rows[name]}
    phases = {'play': ['hand'], 'discard': ['hand'], 'buy': ['shop'], 'open': ['shop'], 'buy_and_use': ['shop'],
              'choose': ['pack'], 'cash_out': ['round'], 'leave_shop': ['shop'], 'reroll': ['shop'],
              'skip_pack': ['pack'], 'select_blind': ['blind'], 'skip_blind': ['blind'],
              'reorder_hand': ['hand', 'pack'], 'use': ['hand', 'shop', 'blind', 'pack', 'round'],
              'sell': ['hand', 'shop', 'blind', 'pack', 'round'], 'reorder_jokers': ['hand', 'shop', 'blind', 'pack', 'round']}
    ledger, offers, acquisitions, sales, cap_observations = [], [], [], [], []
    continuity = []
    counts = Counter()
    discard_rounds = defaultdict(lambda: {'discard_actions': 0, 'cards_discarded': 0, 'five_card_discards': 0, 'steps': []})
    score_rows = {r['step']: r for r in rows['engine_episode_score_verified']}
    for step in range(1, 226):
        start, decision, action_row, resolved, profile = (per_step[k][step] for k in ('started', 'decision', 'action', 'resolved', 'profile'))
        snapshot, action = start['snapshot'], action_row['action']
        assert snapshot == decision['snapshot']
        assert action == decision['result']['action']
        assert start['state_fingerprint'] == action_row['state_fingerprint']
        assert snapshot['phase'] == action_row['phase'] == profile['phase']
        assert not action_row['advisor_skipped'] and not profile['advisor_skipped']
        kind = action['kind']; counts[kind] += 1
        assert snapshot['phase'] in phases[kind]
        entry = {'step': step, 'ante': snapshot['ante'], 'round': snapshot['round'], 'phase': snapshot['phase'],
                 'action': action, 'dollars_before': snapshot['dollars'], 'dollars_delta': resolved['dollars_delta'],
                 'chips_delta': resolved['chips_delta'], 'source_state_after': resolved['state'],
                 'before_fingerprint': start['state_fingerprint'], 'after_fingerprint': resolved['state_fingerprint']}
        if step < 225:
            next_start = per_step['started'][step + 1]
            if resolved['state_fingerprint'] != next_start['state_fingerprint']:
                continuity.append(step)
            assert snapshot['dollars'] + resolved['dollars_delta'] == next_start['snapshot']['dollars']
        if kind in ('play', 'discard'):
            selected = action['indices']; hand = cards(snapshot, 'hand')
            assert 1 <= len(selected) <= 5 and len(set(selected)) == len(selected)
            assert all(isinstance(i, int) and 1 <= i <= len(hand) for i in selected)
            assert all(not c.get('ability', {}).get('forced_selection') or i in selected for i, c in enumerate(hand, 1))
            assert snapshot['hands_left' if kind == 'play' else 'discards_left'] > 0
            entry['selected_cards'] = [slim(hand[i - 1]) for i in selected]
        if kind == 'play':
            verified = score_rows[step]
            assert verified['scope'] == 'deterministic_score' and verified['predicted'] == verified['actual'] == resolved['chips_delta']
            assert action_row['expected_score'] == verified['predicted']
            assert action_row['score_prediction']['uncertain'] is False
            entry['score_verification'] = verified
            entry['prediction_source'] = action_row['prediction_source']
        if kind == 'discard':
            value = discard_rounds[str(snapshot['round'])]
            value['ante'] = snapshot['ante']; value['discard_actions'] += 1
            value['cards_discarded'] += len(action['indices']); value['five_card_discards'] += len(action['indices']) == 5
            value['steps'].append(step)
        if action.get('index') is not None:
            area = cards(snapshot, action['area']); assert 1 <= action['index'] <= len(area)
            card = area[action['index'] - 1]; assert card['key'] == action_row['card_key']
            entry['card'] = slim(card)
            if kind == 'sell':
                assert not card.get('ability', {}).get('eternal'); sales.append(entry.copy())
            if kind in ('buy', 'choose') and card.get('ability', {}).get('set') == 'Joker':
                acquisitions.append(entry.copy())
        if kind.startswith('reorder_'):
            area = cards(snapshot, 'hand' if kind == 'reorder_hand' else 'jokers')
            assert sorted(action['order']) == list(range(1, len(area) + 1))
            assert all(not area[index - 1].get('pinned') or index == position for position, index in enumerate(action['order'], 1))
        for area in ('shop_jokers', 'pack_cards'):
            for index, card in enumerate(cards(snapshot, area), 1):
                if card['key'] in ('j_brainstorm', 'j_burnt'):
                    offers.append({'step': step, 'ante': snapshot['ante'], 'round': snapshot['round'], 'area': area,
                                   'index': index, 'card': slim(card), 'cash': snapshot['dollars'], 'action': action,
                                   'held_jokers': [slim(c) for c in cards(snapshot, 'jokers')],
                                   'joker_limit': snapshot['joker_limit']})
        threshold = 140000 if snapshot['phase'] == 'hand' else 50000 if snapshot['phase'] in ('shop', 'pack') else None
        if threshold is not None and profile['score_calls'] > threshold:
            cap_observations.append({'step': step, 'phase': snapshot['phase'], 'score_calls': profile['score_calls'],
                                     'reported_evaluations': profile.get('evaluations'), 'reference_budget': threshold,
                                     'status': 'exceeds_nominal_whole_decision_budget; specialist accounting requires repair/audit'})
        ledger.append(entry)
    assert counts['play'] == len(score_rows) == 28
    assert not continuity, continuity
    assert len(rows['engine_episode_terminal']) == 1
    terminal = rows['engine_episode_terminal'][0]; evidence = terminal['normal_progress']
    assert terminal['outcome'] == 'win' and not terminal['game_over'] and terminal['decisions'] == 225
    assert evidence['final_boss'] and evidence['threshold_met'] and not evidence['source_saved']
    assert evidence['deck_progress'] and evidence['joker_progress'] and not evidence['game_over']
    final = evidence['final_context']
    assert final['ante'] == final['win_ante'] == 8 and final['round'] == 23
    assert final['chips'] == 705600 and final['target'] == 400000 and final['stake'] == 8
    assert final['deck'] == 'b_red' and not final['seeded'] and not final.get('challenge')
    assert per_step['started'][225]['snapshot']['blind']['key'] == 'bl_final_bell'
    assert per_step['resolved'][225]['chips_delta'] == final['chips']
    expected_keys = {'j_yorick', 'j_brainstorm', 'j_droll', 'j_scary_face', 'j_flower_pot'}
    assert set(final['jokers']) == expected_keys
    callback_joker, callback_deck = evidence['callbacks']
    assert callback_joker['name'] == 'set_joker_win' and callback_deck['name'] == 'set_deck_win'
    assert set(callback_joker['before']['jokers']) == set(callback_joker['after']['jokers']) == expected_keys
    assert all(callback_joker['before']['jokers'][k] == 0 and callback_joker['after']['jokers'][k] == 1 for k in expected_keys)
    assert callback_deck['before']['deck_wins'] == 0 and callback_deck['after']['deck_wins'] == 1
    setup = rows['engine_opening_setup_complete'][0]
    assert setup['decisions'] == 3 and set(setup['actual_pair']) == {'j_yorick', 'j_perkeo'}
    profiles = rows['engine_episode_profile']
    audit = {'schema': 1, 'job': 'C01', 'status': 'audited_selected_synthetic_original_source_win',
             'complete_attempts': 1, 'observed_wins': 1, 'qualification': False, 'player_achievement_progress': False,
             'jokerless_win': False, 'numerical_win_odds': 'unknown; one selected development seed, no representative cohort',
             'scope': 'Autonomous frozen installed300 decision policy on disclosed normal filtered Red Deck Gold Stake. Original source mechanics under the bounded adapter; overall adapter is not declared qualified.',
             'profile': provenance['profile_spec'], 'seed_selection': provenance['seed_selection'],
             'missing_gold_objective_context': metadata['gold_objective_context'],
             'retry_context': retry, 'policy_digest': provenance['policy_digest'], 'provenance': provenance,
             'terminal': terminal, 'action_counts': dict(counts), 'source_legal_resolved_actions': 225,
             'legality_scope': 'Each source action passed original callback/selection checks and settled. Independent trace audit checks contiguous steps, policy action identity, phases, complete selections/orders, forced cards, fingerprints, cash continuity and deterministic played scores. Does not certify every unselected candidate or all adapter mechanics.',
             'score_verification': {'exact': 28, 'supported_floors': 0, 'random_or_unknown_gaps': 0, 'mismatches': 0,
                                    'prediction_sources': dict(Counter(r.get('prediction_source') for r in rows['engine_episode_action'] if r['action']['kind'] == 'play'))},
             'timing': {'outer_seconds': record['elapsed_seconds'], 'adapter': rows['engine_probe_timing'][0],
                        'advisor_seconds': sum(r['advisor_seconds'] for r in profiles),
                        'snapshot_seconds': sum(r['snapshot_seconds'] for r in profiles),
                        'source_effect_seconds': sum(r['engine_seconds'] for r in rows['engine_episode_resolved']),
                        'score_calls': sum(r['score_calls'] for r in profiles)},
             'opening_setup': {k: v for k, v in setup.items() if k != 'snapshot'},
             'observed_conditional_target_offers': offers, 'actual_joker_acquisitions': acquisitions, 'actual_sales': sales,
             'burnt_result': 'Offered at Ante3 round6, $8 with cash$18 then$14, nonperishable, full five-Joker row; advisor opened Arcana then left without replacement. Never acquired. Static target encounter was observed, acquisition was not.',
             'perkeo_result': 'Acquired opening; first held copy target was Empress at step50. Reordered with Brainstorm before shops. Sold at step139 Ante6 to replace with Flower Pot; Perkeo was absent from terminal held row and receives no final Gold increment.',
             'discard_rounds': dict(discard_rounds), 'budget_observations': cap_observations,
             'actions': ledger, 'trace_sha256': sha(FOLDER / 'trace.log'),
             'registration_sha256': sha(FOLDER / 'registration.json'), 'record_sha256': sha(FOLDER / 'record.json'),
             'auditor_sha256': sha(Path(__file__))}
    with (FOLDER / 'audit.json').open('x', encoding='utf-8') as stream:
        json.dump(audit, stream, indent=2)
    print(json.dumps({k: audit[k] for k in ('status', 'action_counts', 'score_verification', 'timing', 'budget_observations')}, indent=2))


if __name__ == '__main__':
    main()
