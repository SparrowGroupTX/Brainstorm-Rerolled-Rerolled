"""Passive review of the already frozen public journal; never evaluate a policy."""
from collections import Counter
from pathlib import Path
import hashlib
import io
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import records, parsed

LOGS = HERE.parent / 'logs1'
events = json.loads((LOGS / 'events.json').read_text(encoding='utf-8'))
observations = json.loads((LOGS / 'observations.json').read_text(encoding='utf-8'))
count = Counter()
shop_ids = []
for oid, observed in observations.items():
    state = observed['state']
    for joker in state.get('jokers') or []:
        ability = joker.get('ability') or {}
        if ability.get('rental') and ability.get('perishable') and ability.get('perish_tally', 999) <= 0:
            count[observed['seed'], state['phase'], joker['key']] += 1
            if state['phase'] == 'shop':
                shop_ids.append(oid)

selected = next(e for e in events if e['sequence'] == 6277)
anchor = selected['anchor']
source = LOGS / 'frozen' / anchor['segment']
snapshot = None
for ordinal, (raw, _) in enumerate(records(io.BytesIO(source.read_bytes())), 1):
    if ordinal == anchor['ordinal']:
        assert hashlib.sha256(raw).hexdigest() == anchor['raw_sha256']
        event = parsed(raw)
        assert event['sequence'] == 6277
        snapshot = event['context']['snapshot']
        break
assert snapshot is not None
goal = snapshot['collection_progress']
assert 'completionist_goal' not in snapshot
assert snapshot['teacher_profile'] == 'perkeo_yorick_win_v1'
assert goal['by_key']['j_trio']['status'] == 'complete'

leaves = []
for event in events:
    if event['seed'] != 'RH45AD21' or event['kind'] != 'auto_run':
        continue
    details = event['details']
    state = (observations.get(event['observation_id']) or {}).get('state') or {}
    if details.get('event') == 'action_attempt' and (details.get('action') or {}).get('kind') == 'leave_shop':
        dead = next((j for j in state.get('jokers') or [] if j['key'] == 'j_trio'
                     and (j.get('ability') or {}).get('perish_tally', 999) <= 0), None)
        if dead:
            leaves.append({'sequence': event['sequence'], 'at': event['at'], 'observation_id': event['observation_id'],
                           'ante': state['ante'], 'round': state['round'], 'dollars': state['dollars'],
                           'next_blind': state['next_blind'], 'anchor': event['anchor']})

terminal = next(e for e in events if e['sequence'] == 6968)
assert terminal['seed'] == 'RH45AD21'
fields = ('phase', 'ante', 'round', 'teacher_profile', 'dollars', 'bankrupt_at', 'rental_rate',
          'next_blind', 'blind_choices', 'modifiers', 'ordering_safe', 'jokers_shuffling',
          'consumeable_buffer', 'consumable_limit', 'joker_limit', 'last_tarot_planet')
evidence = {
    'schema': 1,
    'scope': 'Passive frozen public-log and source review; no policy evaluation, new game, save or profile access.',
    'observation_anchor': selected['anchor'],
    'sequence': selected['sequence'], 'at': selected['at'], 'seed': selected['seed'],
    'state': {key: snapshot.get(key) for key in fields},
    'completionist_goal_absent': True,
    'collection_progress': {key: value for key, value in goal.items() if key not in ('by_key',)},
    'trio_gold_status': goal['by_key']['j_trio'],
    'jokers': snapshot['jokers'],
    'consumables': [{key: card.get(key) for key in ('id', 'key', 'ability', 'edition', 'debuff')}
                    for card in snapshot['consumeables']],
    'expired_rental_counts': [{'seed': k[0], 'phase': k[1], 'key': k[2], 'observations': n}
                              for k, n in sorted(count.items())],
    'expired_rental_shop_observation_ids': shop_ids,
    'leave_shop_attempts': leaves,
    'terminal': terminal,
    'terminal_state': {key: observations[terminal['observation_id']]['state'].get(key)
                       for key in ('phase', 'ante', 'round', 'chips', 'dollars', 'hands_left', 'blind')},
    'limits': 'Retention is directly observed. Its contribution to the loss and the outcome of selling earlier are unmeasured. Manufactured tests do not replay this state.',
    'input_hashes': {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in (LOGS / 'manifest.json', LOGS / 'events.json', LOGS / 'observations.json', source)},
}
(HERE / 'evidence.json').write_text(json.dumps(evidence, indent=2, allow_nan=False) + '\n', encoding='utf-8')
print(json.dumps({'expired_rental_shop_observations': len(shop_ids),
                  'leave_shop_sequences': [e['sequence'] for e in leaves],
                  'source_sequence': selected['sequence'], 'terminal_sequence': terminal['sequence']}))
