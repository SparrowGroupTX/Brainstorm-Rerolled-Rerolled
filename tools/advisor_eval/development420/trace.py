"""Descriptive public links only; no policy/scorer invocation or captured fixture."""
from pathlib import Path
from collections import Counter
import json,sqlite3,sys
HERE=Path(__file__).resolve().parent;folder=HERE/'captures'/sys.argv[1]
summary=json.loads((folder/'summary.json').read_text())
db=sqlite3.connect('file:'+str(folder/'events.sqlite3')+'?mode=ro',uri=True)
rows={};observations={};advice={};settles={};callbacks={}
for seq,kind,segment,ordinal,sha,raw in db.execute('select seq,kind,segment,ordinal,raw_sha,data from events order by seq'):
 e=json.loads(raw);rows[seq]=(e,{'seq':seq,'kind':kind,'segment':segment,'ordinal':ordinal,'raw_sha':sha})
 if kind=='teacher_observation':observations[e['observation_id']]=seq
 if kind=='teacher_advice':advice[seq]=e.get('context',{}).get('advice',{})
 if kind=='state_after_actions':
  for n in e.get('details',{}).get('action_sequences',[]):settles[n]=seq
 if kind=='action_callback_result':callbacks[e['details']['action_sequence']]=seq
db.close()
def cards(xs):return [{k:x.get(k) for k in ('id','key','rank','suit','enhancement','seal','edition','cost','sell_cost','debuff','ability')} for x in xs or []]
findings=[]
for seq,(e,anchor) in rows.items():
 if e['kind']!='action_requested':continue
 n=observations.get(e.get('observation_id'));a=e.get('details',{}).get('input',{}).get('action',{})
 if not n:continue
 s=rows[n][0]['context']['snapshot'];stock=s.get('consumeables') or []
 offers=(s.get('shop_jokers') if s.get('phase')=='shop' else s.get('pack_cards')) or []
 tags=[]
 if any(x.get('key')=='c_empress' for x in stock) and any(x.get('key')=='c_death' for x in offers):tags.append('empress_with_death_offer')
 if s.get('phase')=='shop' and any(x.get('key')=='c_death' for x in stock) and any('standard' in x.get('key','') for x in s.get('shop_booster') or []):tags.append('death_standard_offer')
 if a.get('kind')=='use' and a.get('area')=='consumeables' and a.get('index') and a['index']<=len(stock) and stock[a['index']-1].get('key') in ('c_empress','c_death'):tags.append('owned_development_use')
 if not tags:continue
 end=rows.get(settles.get(seq));endseq=observations.get(end[0].get('observation_id')) if end else None
 after=rows[endseq][0]['context']['snapshot'] if endseq else {}
 public=[c for c in s.get('playing_cards') or [] if not c.get('unknown') and not c.get('identity_redacted')]
 findings.append({'tags':tags,'action_anchor':anchor,'observation_anchor':rows[n][1],
  'advice_seq':e.get('advice_sequence'),'advice':advice.get(e.get('advice_sequence')),'action':a,
  'ante':s.get('ante'),'phase':s.get('phase'),'dollars':s.get('dollars'),'consumable_limit':s.get('consumable_limit'),
  'run_instance':e.get('context',{}).get('run_instance'),'profile':s.get('teacher_profile'),
  'stock':cards(stock),'row':cards(s.get('jokers')),'offers':cards(offers),'boosters':cards(s.get('shop_booster')),
  'public_population_size':len(public),'enhancements':dict(Counter(c.get('enhancement','c_base') for c in public)),
  'enhanced_cards':cards([c for c in public if c.get('enhancement','c_base')!='c_base' or c.get('seal') or c.get('edition')]),
  'hand':cards(s.get('hand')),'callback_anchor':rows[callbacks[seq]][1] if seq in callbacks else None,
  'callback':rows[callbacks[seq]][0]['details'] if seq in callbacks else None,'settlement_anchor':end[1] if end else None,
  'after_observation_anchor':rows[endseq][1] if endseq else None,
  'after':{'phase':after.get('phase'),'dollars':after.get('dollars'),'stock':cards(after.get('consumeables'))}})
out={'scope':__doc__,'database_sha256':summary['database_sha256'],'findings':findings}
with (folder/'death_trace.json').open('x') as f:json.dump(out,f,indent=2);f.write('\n')
for x in findings:
 if 'owned_development_use' not in x['tags']:print(json.dumps({k:x[k] for k in ('tags','action_anchor','ante','phase','dollars','consumable_limit','action','enhancements')}))
print(json.dumps({'findings':len(findings),'tags':dict(Counter(t for x in findings for t in x['tags']))}))
