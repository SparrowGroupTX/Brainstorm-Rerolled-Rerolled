"""Passive public event linkage only. Never imports policy, scorer or saves."""
from collections import Counter
from pathlib import Path
import hashlib
import io
import json
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2]))
from tools.advisor_eval.read_player_log import records, parsed

manifest = json.loads((HERE / 'capture/verification.json').read_text())
observations, advices, requests, callbacks, settlements = {}, {}, [], {}, []
offers, packs, owned = {}, {}, {}
run = 0
seq = 0
for item in manifest['segments']:
    data = (HERE / 'logs1' / item['name']).read_bytes()
    assert hashlib.sha256(data).hexdigest() == item['sha256']
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
        e = parsed(raw)
        assert e['sequence'] == seq + 1
        seq += 1
        ctx, d = e.get('context') or {}, e.get('details') or {}
        anchor = dict(sequence=seq, segment=item['name'], ordinal=ordinal,
                      raw_sha256=hashlib.sha256(raw).hexdigest())
        if e['kind'] == 'auto_run' and d.get('event') == 'run_started':
            run = d['run_number']
        if e['kind'] == 'teacher_observation':
            s = ctx.get('snapshot') or {}
            observation = dict(anchor=anchor, run_number=run, snapshot=s)
            observations[e.get('observation_id')] = observation
            for c in s.get('jokers') or []:
                owned.setdefault((run, c.get('id')), anchor)
            for area in ('shop_jokers', 'pack_cards'):
                for i, c in enumerate(s.get(area) or [], 1):
                    if c.get('key') in ('j_blueprint', 'j_brainstorm'):
                        key = (run, c.get('id'))
                        if key not in offers:
                            offers[key] = dict(run_number=run, card=c, area=area, index=i,
                                               first=anchor, observations=[])
                        offers[key]['observations'].append(e.get('observation_id'))
            for i, c in enumerate(s.get('shop_booster') or [], 1):
                if 'buffoon' in (c.get('key') or ''):
                    key = (run, c.get('id'))
                    packs.setdefault(key, dict(run_number=run, card=c, first=anchor, observations=[]))
                    packs[key]['observations'].append(e.get('observation_id'))
        elif e['kind'] == 'teacher_advice':
            advices[seq] = dict(anchor=anchor, advice=ctx.get('advice'))
        elif e['kind'] == 'action_requested' and d.get('source') == 'auto_run':
            requests.append(dict(anchor=anchor, run_number=run, observation_id=e.get('observation_id'),
                                 advice_sequence=e.get('advice_sequence'), action=(d.get('input') or {}).get('action')))
        elif e['kind'] == 'action_callback_result':
            callbacks[d.get('action_sequence')] = dict(anchor=anchor, details=d)
        elif e['kind'] == 'state_after_actions':
            settlements.append(dict(anchor=anchor, details=d, observation_id=e.get('observation_id')))

assert seq == manifest['events']
death = []
for a in requests:
    o = observations.get(a['observation_id'])
    a['observation'] = o
    a['advice'] = advices.get(a['advice_sequence'])
    a['callback'] = callbacks.get(a['anchor']['sequence'])
    action = a['action'] or {}
    if not o:
        continue
    s = o['snapshot']
    index, area = action.get('index'), action.get('area')
    cards = s.get(area) or [] if area else []
    card = cards[index-1] if isinstance(index, int) and 1 <= index <= len(cards) else {}
    if action.get('kind') == 'open' and 'buffoon' in (card.get('key') or ''):
        p = packs.get((a['run_number'], card.get('id')))
        if p is not None:
            p['opened_action'] = a['anchor']
    if action.get('kind') in ('use', 'choose') and card.get('key') == 'c_death':
        death.append(a)

for key, offer in offers.items():
    offer['first_owned'] = owned.get(key)
    obs = set(offer['observations'])
    offer['actions'] = [a for a in requests if a['observation_id'] in obs]

out = HERE / 'analysis'
out.mkdir(exist_ok=False)
values = {
    'copy_opportunities.json': list(offers.values()),
    'buffoon_opportunities.json': list(packs.values()),
    'death_actions.json': death,
    'settlements.json': settlements,
    'summary.json': dict(events=seq, copy_offers=len(offers),
        acquired=sum(bool(x.get('first_owned')) for x in offers.values()),
        not_acquired=sum(not x.get('first_owned') for x in offers.values()),
        buffoon_offers=len(packs), buffoon_opened=sum(bool(x.get('opened_action')) for x in packs.values()),
        death_uses=len(death), death_areas=dict(Counter((a['action'] or {}).get('area') for a in death)),
        note='Passive linkage. Callback alone does not prove settlement; physical card changes and later observations remain authoritative.'),
}
for name, value in values.items():
    with (out / name).open('x', encoding='utf-8') as f:
        json.dump(value, f, indent=2, allow_nan=False)
        f.write('\n')
print(json.dumps(values['summary.json']))
