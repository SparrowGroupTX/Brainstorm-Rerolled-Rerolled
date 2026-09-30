"""Read only frozen public journal evidence. No game/policy execution."""
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
DATA = HERE / 'logs1'
events = json.loads((DATA / 'events.json').read_text())
observations = json.loads((DATA / 'observations.json').read_text())
by_sequence = {event['sequence']: event for event in events}


def state(event):
    return event.get('state') or observations.get(event.get('observation_id'), {}).get('state', {})


def record(event):
    snapshot = state(event)
    recommendation = by_sequence.get(event.get('advice_sequence'), {})
    return {
        'sequence': event['sequence'], 'at': event['at'], 'anchor': event['anchor'],
        'advice_sequence': event.get('advice_sequence'),
        'advice_anchor': recommendation.get('anchor'),
        'advice': recommendation.get('advice'),
        'ante': snapshot.get('ante'), 'round': snapshot.get('round'),
        'blind': snapshot.get('blind'), 'chips_before': snapshot.get('chips'),
        'hands_played': snapshot.get('hands_played'),
        'discards_left': snapshot.get('discards_left'),
        'discards_used': snapshot.get('discards_used'),
        'action': (event['details'].get('input') or {}).get('action'),
        'joker_row': [{'key': joker.get('key'), 'debuff': joker.get('debuff'),
                       'x_mult': (joker.get('ability') or {}).get('x_mult'),
                       'yorick_discards': (joker.get('ability') or {}).get('yorick_discards')}
                      for joker in snapshot.get('jokers', [])],
        'consumable_keys': [card.get('key') for card in snapshot.get('consumeables', [])],
    }


rounds = defaultdict(lambda: {'plays': [], 'discards': [], 'empress': [], 'cash_out': []})
uses = []
for event in events:
    if event['kind'] != 'action_requested':
        continue
    snapshot = state(event)
    action = (event['details'].get('input') or {}).get('action') or {}
    kind = action.get('kind')
    entry = rounds[snapshot.get('round')]
    if kind in ('play', 'discard', 'cash_out'):
        entry[{'play': 'plays', 'discard': 'discards', 'cash_out': 'cash_out'}[kind]].append(record(event))
    elif kind == 'use':
        cards = snapshot.get(action.get('area'), [])
        index = action.get('index', 0)
        if 0 < index <= len(cards) and cards[index - 1].get('key') == 'c_empress':
            row = record(event)
            entry['empress'].append(row)
            uses.append(row)

cleared = []
for round_number, entry in rounds.items():
    if not entry['cash_out'] or not entry['plays']:
        continue
    final_play, cash_out = entry['plays'][-1], entry['cash_out'][0]
    cleared.append({
        'round': round_number, 'ante': final_play['ante'], 'blind': final_play['blind'],
        'discard_sizes': [len(row['action'].get('indices', [])) for row in entry['discards']],
        'play_sequences': [row['sequence'] for row in entry['plays']],
        'last_play_sequence': final_play['sequence'],
        'unused_discards_at_last_play': final_play['discards_left'],
        'cash_out_sequence': cash_out['sequence'], 'cash_out_chips': cash_out['chips_before'],
        'empress_sequences': [row['sequence'] for row in entry['empress']],
    })

summary = {
    'scope': 'Bounded passive prefix of the current user-started product session. No policies, scorers, source workers, simulations, searches, saves or game control.',
    'session': 'session-20260916T191059Z-1',
    'loaded_version': 'Brainstorm v2.158.0-alpha',
    'seed': 'M4BVSY11', 'last_at': events[-1]['at'], 'last_sequence': events[-1]['sequence'],
    'terminal_count_in_prefix': sum(event['kind'] == 'auto_run' and event['details'].get('event') == 'run_finished' for event in events),
    'cleared_rounds': len(cleared),
    'clears_with_unused_discards': sum(bool(row['unused_discards_at_last_play']) for row in cleared),
    'unused_discards_at_clears': sum(row['unused_discards_at_last_play'] or 0 for row in cleared),
    'empress_uses': len(uses),
    'empress_uses_before_first_play': sum(row['hands_played'] == 0 for row in uses),
    'empress_uses_before_first_discard': sum(row['hands_played'] == 0 and row['discards_used'] == 0 for row in uses),
    'empress_advice_titles': dict(Counter(row['advice']['title'] for row in uses)),
    'clears': cleared,
    'anchors': [record(by_sequence[number]) for number in [619, 629, 639, 713, 723, 763, 847, 857, 867, 1255, 1265, 1275, 1933, 1964, 1974, 1984, 2079, 2089, 2495]],
    'limits': [
        'Previously studied seed; dependent development data, not an unseen or representative cohort.',
        'Unused discards alone do not establish a safe or valuable alternative.',
        'No growth rejection reason is present in these action/advice records; source analysis is needed for mechanism.',
        'Most Empress uses before the first play were after at least one discard, not necessarily on the initial deal.',
        'A supported minimum clear proves local scoring safety, not optimal resource allocation or a counterfactual win.',
        'The first copied card row initially still points Brainstorm at Perkeo; later cited rows point it at Yorick. Do not assume a copy target from possession alone.',
    ],
    'input_hashes': {name: hashlib.sha256((DATA / name).read_bytes()).hexdigest()
                     for name in ['manifest.json', 'events.json', 'observations.json']},
}
(HERE / 'report.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in summary.items() if key not in ('anchors', 'clears')}))
