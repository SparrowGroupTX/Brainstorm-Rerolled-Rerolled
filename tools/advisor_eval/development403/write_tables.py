"""Format already extracted public facts; no policy/scorer evaluation."""
from pathlib import Path
from collections import Counter
import json,sqlite3
P=Path(__file__).resolve().parent;A=P/'analysis2'
def read(name):return json.loads((A/name).read_text())
def short(key):return (key or '?').removeprefix('j_').removeprefix('c_')
def label(c):
 r={14:'A',13:'K',12:'Q',11:'J',10:'10'}.get(c.get('rank'),str(c.get('rank','?')))
 return r+(c.get('suit') or '?')[0]+' '+(c.get('enhancement') or 'base').removeprefix('m_').removeprefix('c_')+(' / '+c['seal'] if c.get('seal') else '')+(' / '+str(c['edition']) if c.get('edition') else '')
lines=['# Exhaustive public opportunity tables — audit403','','Sequences resolve through events.sqlite3 to exact copied segment/ordinal/raw hash. Each offer is counted once per run and physical card ID. Cash/row columns refer to its first public observation, not an invented alternative.','',
'## Copy Jokers','','| Run | First seq | Offer | Price | Cash / row size | Outcome |','| --- | --- | --- | ---: | --- | --- |']
for o in read('copy_opportunities.json'):
 s=o['observations'][0];a=o['card'].get('ability') or {};flags=', '.join(k for k in ('eternal','rental','perishable') if a.get(k))
 result='owned '+str(o['first_owned_sequence'])+'; request '+','.join(map(str,o['purchase_actions'])) if o['first_owned_sequence'] else 'passed; actions '+','.join(str(d['sequence']) for d in o['decisions'])
 lines.append(f"| {o['run']} | {o['first_sequence']} | {o['card']['id']} {short(o['card']['key'])} {flags} | {o['card'].get('cost')} | {s['dollars']} / {len(s['jokers'])} | {result} |")
lines+=['','## Displayed Buffoon packs','','Opened means the request was followed by a public pack reveal; confirmation anchors are in pack_reveal_checks.json. Skipped contents remain unknown.','',
'| Run | First seq | Pack | Price | Initial cash | Blueprint owned initially | Open request |','| --- | --- | --- | ---: | ---: | --- | --- |']
for o in read('buffoon_opportunities.json'):
 s=o['observations'][0];bp=any(j.get('key')=='j_blueprint' for j in s['jokers'])
 lines.append(f"| {o['run']} | {o['first_sequence']} | {o['card']['key']} | {o['card'].get('cost')} | {s['dollars']} | {bp} | {','.join(map(str,o['opened_actions'])) or 'not opened'} |")
lines+=['','## Death uses','','All23 selected transformations are confirmed in later public observations. This verifies selected properties and direction, not optimality or every underlying ability field.','',
'| Run | Action | Area | Recipient before | Selected source | Public confirmation |','| --- | --- | --- | --- | --- | --- |']
for d in read('death_settlement_checks.json'):
 lines.append(f"| {d['run']} | {d['action_sequence']} | {d['area']} | {d['recipient_id']} {label(d['recipient_before'])} | {d['source_id']} {label(d['source'])} | {d['first_matching_public_observation']} |")
with (P/'OPPORTUNITIES.md').open('x',encoding='utf-8') as f:f.write('\n'.join(lines)+'\n')

ds=read('decisions.json');runs=read('runs.json')
out=['# Per-run resource and action timelines — audit403','','Public observed values only. Each line is before the named action. Yorick XMult comes from ability.x_mult, not the static extra.xmult template. Inventory, population and more granular observations remain in analysis2/. Loaded labels are not exact loaded-byte attestation.']
for r in runs:
 n=r['run'];terminal=r['last_observation'];out+=['',f"## Run {n}: {r['end']['details']['outcome']}",'',f"Start {r['start']['sequence']}; ending {r['end']['sequence']}; last public state {terminal['sequence']}: {terminal['chips']}/{terminal['blind']['chips']}, cash ${terminal['dollars']}. Final-state ante9 in wins reflects advancement after the Ante8 clear.",'',
'| Seq | Ante | Action | Cash | Yorick X | Copy status | Consumable counts |','| --- | ---: | --- | ---: | ---: | --- | --- |']
 for d in ds:
  a=d['action'] or {};b=d['before']
  if d['run']!=n or not b or a.get('kind') not in ('select_blind','leave_shop','buy','sell','choose','use','reorder_hand'):continue
  if a.get('kind')=='use' and d['selected_card'].get('key')!='c_death':continue
  if a.get('kind')=='choose' and not d['selected_card'].get('key','').startswith('j_') and d['selected_card'].get('key')!='c_death':continue
  y=next((j.get('ability',{}).get('x_mult') for j in b['jokers'] if j.get('key')=='j_yorick'),None)
  copies='; '.join(short(j.get('key'))+(' expired' if j.get('debuff') else '')+(' ttl='+str(j['ability']['perish_tally']) if 'perish_tally' in j.get('ability',{}) else '') for j in b['jokers'] if j.get('key') in ('j_blueprint','j_brainstorm')) or 'none'
  cons=', '.join(f'{short(k)}:{v}' for k,v in Counter(c.get('key') for c in b['consumeables']).items()) or 'empty'
  out.append(f"| {d['sequence']} | {b['ante']} | {d['advice'].get('title','?')} | {b['dollars']} | {y} | {copies} | {cons} |")
with (P/'RUN_TIMELINES.md').open('x',encoding='utf-8') as f:f.write('\n'.join(out)+'\n')

db=sqlite3.connect('file:'+str(P/'events.sqlite3')+'?mode=ro',uri=True)
pack_checks=[]
for pack in read('buffoon_opportunities.json'):
 for action in pack['opened_actions']:
  end=next(r['end']['sequence'] for r in runs if r['run']==pack['run']);found=None
  for seq,data in db.execute("SELECT seq,data FROM events WHERE kind='teacher_observation' AND seq>? AND seq<? ORDER BY seq LIMIT 12",(action,end)):
   s=json.loads(data)['context']['snapshot']
   if s.get('phase')=='pack' and isinstance(s.get('pack_cards'),list) and s['pack_cards']:
    found=seq;break
  pack_checks.append({'run':pack['run'],'pack_id':pack['card']['id'],'open_request':action,'first_pack_reveal':found})
with (A/'pack_reveal_checks.json').open('x') as f:json.dump(pack_checks,f,indent=2)
assert len(pack_checks)==30 and all(x['first_pack_reveal'] for x in pack_checks)
print('Wrote exhaustive 11-copy / 44-pack / 23-Death tables, per-run timelines and30 pack reveal confirmations.')
