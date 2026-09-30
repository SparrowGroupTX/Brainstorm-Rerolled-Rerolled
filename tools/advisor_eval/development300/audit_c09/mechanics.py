"""Read-only C09 provenance and actual-transition projections; no policy imports."""
from pathlib import Path
import hashlib
import json
import math


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


from graph_binding import verify_graph_receipt

def card_summary(card):
    return {key: card.get(key) for key in ('id', 'key', 'enhancement', 'seal', 'edition', 'rank', 'suit')} | {
        'ability': card.get('ability', {})}


def yoricks(snapshot):
    return {str(card.get('id')): {'id': card.get('id'), 'debuff': card.get('debuff', False),
                                'ability': card.get('ability', {})}
            for card in snapshot.get('jokers', []) if card.get('key') == 'j_yorick'}


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def actual_mechanics(index, completed, contexts):
    issues = []
    discards, growth, perkeo, packs = [], [], [], []
    for step in completed:
        snapshot = index['started'][step]['snapshot']
        result = index['decision'][step]['result']
        action_row = index['action'][step]
        action = action_row['action']
        next_started = index['started'].get(step + 1)
        after = next_started['snapshot'] if next_started else (
            contexts[0]['snapshot'] if len(contexts) == 1 and contexts[0].get('step') == step else None)
        if action['kind'] == 'discard':
            count = len(action.get('indices', []))
            row = {'step': step, 'ante': snapshot.get('ante'), 'round': snapshot.get('round'),
                   'physical_cards_discarded': count, 'indices': action.get('indices'),
                   'selected_cards': [card_summary(snapshot['hand'][i - 1]) for i in action.get('indices', [])
                                      if type(i) is int and 1 <= i <= len(snapshot.get('hand', []))],
                   'yorick_before': yoricks(snapshot), 'yorick_after': yoricks(after) if after else None,
                   'after_observed': after is not None, 'checks': []}
            if after:
                for key, old in row['yorick_before'].items():
                    if old['debuff']:
                        continue
                    ability = old['ability']; extra = ability.get('extra', {})
                    actual = row['yorick_after'].get(key)
                    supported = isinstance(extra, dict) and all(finite_number(v) for v in (
                        ability.get('yorick_discards'), ability.get('x_mult'), extra.get('discards'), extra.get('xmult')))
                    if not supported or actual is None:
                        row['checks'].append({'id': old['id'], 'checked': False,
                                              'reason': 'Required actual identity or live growth fields unavailable'})
                        continue
                    countdown, xmult = ability['yorick_discards'], ability['x_mult']
                    increments = 0
                    for _ in range(count):
                        if countdown <= 1:
                            countdown = extra['discards']; xmult += extra['xmult']; increments += 1
                        else:
                            countdown -= 1
                    matches = (actual['ability'].get('yorick_discards') == countdown
                               and actual['ability'].get('x_mult') == xmult)
                    row['checks'].append({'id': old['id'], 'checked': True, 'matched': matches,
                                          'actual_card_count': count, 'threshold_increments': increments,
                                          'expected_countdown': countdown, 'expected_x_mult': xmult})
                    if not matches:
                        issues.append({'step': step, 'reason': 'Actual physical Yorick discard transition differs'})
            discards.append(row)
        if result.get('growth'):
            projection = result['growth']
            matches = projection.get('action') == action
            if not matches:
                issues.append({'step': step, 'reason': 'Growth recommendation differs from executed action'})
            growth.append({'step': step, 'action': action, 'same_selected_action': matches,
                           'growth': projection, 'yorick_before': yoricks(snapshot),
                           'yorick_after': yoricks(after) if after else None,
                           'scope': 'Observed executed action plus its local forecast; no alternative continuation executed.'})
        if action['kind'] == 'leave_shop' and any(c.get('key') == 'j_perkeo' for c in snapshot.get('jokers', [])):
            old = {str(c.get('id')): c for c in snapshot.get('consumeables', [])}
            new = {str(c.get('id')): c for c in after.get('consumeables', [])} if after else None
            additions = [card_summary(c) for key, c in new.items() if key not in old] if new is not None else None
            removals = [card_summary(c) for key, c in old.items() if key not in new] if new is not None else None
            perkeo.append({'step': step, 'ante': snapshot.get('ante'), 'row_before': [card_summary(c) for c in snapshot.get('jokers', [])],
                           'inventory_before': [card_summary(c) for c in old.values()],
                           'inventory_after': [card_summary(c) for c in new.values()] if new is not None else None,
                           'actual_added': additions, 'actual_removed': removals, 'after_observed': after is not None,
                           'negative_added': sum(c.get('edition', {}).get('negative') is True for c in (additions or []) if isinstance(c.get('edition'), dict)),
                           'scope': 'Actual before/after inventory changes; no copy, retention or award is inferred when the next state is absent.'})
        if snapshot.get('phase') == 'pack':
            diag = action_row.get('pack_diagnostics') or {}
            packs.append({'step': step, 'action': action, 'pack_type': snapshot.get('pack_type'),
                          'pack_choices': snapshot.get('pack_choices'),
                          'selected_key': action_row.get('card_key'),
                          'survival_priority': diag.get('survival_priority'),
                          'actual_jokers_after': [card_summary(c) for c in after.get('jokers', [])] if after else None,
                          'scope': 'Actual choice and retained row; any pack discard-history comparison is a frozen-policy receipt, not a source-executed future discard.'})
    return {'actual_discards': discards, 'actual_growth_actions': growth, 'actual_perkeo_shop_exits': perkeo,
            'actual_pack_outcomes': packs,
            'counts': {'discard_actions': len(discards), 'physical_discarded_cards': sum(r['physical_cards_discarded'] for r in discards),
                       'growth_actions': len(growth), 'observed_perkeo_exits': len(perkeo), 'pack_actions': len(packs)},
            'future_actions_or_absent_outcomes_imputed': False}, issues
