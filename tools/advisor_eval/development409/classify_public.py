"""Describe copied public outcomes and Yorick sales without policy execution."""
from pathlib import Path
import json
import sqlite3

HERE = Path(__file__).resolve().parent
db = sqlite3.connect('file:' + str(HERE / 'events.sqlite3') + '?mode=ro', uri=True)
events = [json.loads(row[0]) for row in db.execute('SELECT data FROM events ORDER BY seq')]
db.close()
observations = {e['observation_id']: e for e in events if e['kind'] == 'teacher_observation'}
advice = {e['sequence']: e for e in events if e['kind'] == 'teacher_advice'}
callbacks = {(e.get('details') or {}).get('action_sequence'): e
             for e in events if e['kind'] == 'action_callback_result'}
settlements = {}
for event in events:
    if event['kind'] == 'state_after_actions':
        for seq in (event.get('details') or {}).get('action_sequences') or []:
            settlements[seq] = event

sales = []
for event in events:
    if event['kind'] != 'action_requested':
        continue
    action = ((event.get('details') or {}).get('input') or {}).get('action') or {}
    if action.get('kind') != 'sell' or action.get('area') != 'jokers':
        continue
    before = observations.get(event.get('observation_id'))
    snapshot = ((before or {}).get('context') or {}).get('snapshot') or {}
    cards = snapshot.get('jokers') or []
    index = action.get('index')
    if not isinstance(index, int) or not 1 <= index <= len(cards):
        continue
    selected = cards[index - 1]
    if selected.get('key') != 'j_yorick':
        continue
    settled = settlements.get(event['sequence'])
    after = observations.get((settled or {}).get('observation_id'))
    after_snapshot = ((after or {}).get('context') or {}).get('snapshot') or {}
    later_requests = [e for e in events if e['kind'] == 'action_requested'
                      and e['sequence'] > event['sequence']][:5]
    sales.append({'request_sequence': event['sequence'], 'selected_card': selected,
        'before_observation': before, 'advice': advice.get(event.get('advice_sequence')),
        'request': event, 'callback': callbacks.get(event['sequence']),
        'settlement': settled, 'after_observation': after,
        'physical_id_absent_after': bool(after) and selected.get('id') is not None
            and all(c.get('id') != selected['id'] for c in after_snapshot.get('jokers') or []),
        'next_requests': later_requests})

verification = json.loads((HERE / 'capture/verification.json').read_text())
result = {'session': verification['session'], 'segments': len(verification['segments']),
    'events': verification['events'], 'versions': verification['versions'],
    'teacher_profiles': verification['profiles'], 'started_runs': len(verification['starts']),
    'recorded_endings': verification['outcomes'], 'unended_run_ids': verification['unended_run_ids'],
    'classification': 'One observed start without terminal result; censored at user exit.',
    'ten_run_completion_established': False, 'loaded_byte_equivalence_established': False,
    'previous_uncaptured_session_recovered': False, 'policy_execution_performed': False,
    'yorick_sales': sales}
with (HERE / 'public_classification.json').open('x', encoding='utf-8') as out:
    json.dump(result, out, indent=2)
    out.write('\n')
print(json.dumps({k: result[k] for k in ('session', 'events', 'versions', 'started_runs',
    'recorded_endings', 'unended_run_ids')}))
for sale in sales:
    ctx = ((sale['before_observation'] or {}).get('context') or {}).get('snapshot') or {}
    a = ((sale['advice'] or {}).get('context') or {}).get('advice') or {}
    print(json.dumps({'yorick_sale_sequence': sale['request_sequence'],
        'card': sale['selected_card'], 'phase': ctx.get('phase'), 'ante': ctx.get('ante'),
        'cash': ctx.get('dollars'), 'physical_id_absent_after': sale['physical_id_absent_after'],
        'advice_fields': list(a), 'action': (sale['request']['details'].get('input') or {}).get('action')}))
