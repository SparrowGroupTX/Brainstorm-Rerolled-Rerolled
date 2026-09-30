from pathlib import Path
import sqlite3,json,sys
HERE=Path(__file__).resolve().parent
folder=HERE/(sys.argv[1] if len(sys.argv)>1 else 'captures/001')
summary=json.loads((folder/'summary.json').read_text())
db=sqlite3.connect(folder/'events.sqlite3')
rows={};observations={};advice={};settles={};callbacks={}
for seq,kind,segment,ordinal,sha,raw in db.execute('select seq,kind,segment,ordinal,raw_sha,data from events'):
 e=json.loads(raw);rows[seq]=(e,{'seq':seq,'kind':kind,'segment':segment,'ordinal':ordinal,'raw_sha':sha})
 if kind=='teacher_observation':observations[e['observation_id']]=seq
 if kind=='teacher_advice':advice[seq]=e.get('context',{}).get('advice',{})
 if kind=='state_after_actions':
  for n in e.get('details',{}).get('action_sequences',[]):settles[n]=seq
 if kind=='action_callback_result':callbacks[e['details']['action_sequence']]=seq
findings=[]
for seq,(e,anchor) in rows.items():
 if e['kind']!='action_requested':continue
 n=observations.get(e.get('observation_id'));a=e.get('details',{}).get('input',{}).get('action',{})
 if not n:continue
 s=rows[n][0]['context']['snapshot'];off=s.get(a.get('area',''),[]) or []
 c=off[a.get('index',0)-1] if a.get('index') and len(off)>=a['index'] else {}
 empty_offer=s.get('phase')=='shop' and not s.get('consumeables') and any(x.get('key')=='c_neptune' for x in s.get('shop_jokers',[]))
 tags=[]
 if empty_offer:tags.append('empty_neptune_offer')
 if a.get('kind') in ('buy','choose') and c.get('key')=='j_trading':tags.append('trading_acquisition')
 if a.get('kind')=='sell' and c.get('key')=='j_perkeo':tags.append('perkeo_sale')
 if a.get('kind')=='buy' and c.get('ability',{}).get('set')=='Joker' and s.get('ante',99)<=3:tags.append('early_joker_buy')
 if not tags:continue
 end=rows.get(settles.get(seq));endseq=observations.get(end[0].get('observation_id')) if end else None
 after=rows[endseq][0]['context']['snapshot'] if endseq else {}
 def cards(xs):return [{'id':x.get('id'),'key':x.get('key'),'cost':x.get('cost'),'sell_cost':x.get('sell_cost'),'ability':x.get('ability'),'edition':x.get('edition')} for x in xs or []]
 findings.append({'tags':tags,'action_anchor':anchor,'observation_anchor':rows[n][1],'advice_seq':e.get('advice_sequence'),'advice':advice.get(e.get('advice_sequence')),'action':a,'ante':s.get('ante'),'dollars':s.get('dollars'),'run_instance':e.get('context',{}).get('run_instance'),'profile':s.get('teacher_profile'),'stock':cards(s.get('consumeables')),'row':cards(s.get('jokers')),'offers':cards(s.get('shop_jokers')),'callback_anchor':rows[callbacks[seq]][1] if seq in callbacks else None,'callback':rows[callbacks[seq]][0]['details'] if seq in callbacks else None,'settlement_anchor':end[1] if end else None,'after_observation_anchor':rows[endseq][1] if endseq else None,'after':{'phase':after.get('phase'),'dollars':after.get('dollars'),'row':cards(after.get('jokers')),'stock':cards(after.get('consumeables'))}})
r={'scope':'Descriptive public links only; no policy/scorer execution or counterfactual outcome.','database_sha256':summary['database_sha256'],'findings':findings}
with (folder/'shop_trace.json').open('x') as f:json.dump(r,f,indent=2)
for f in findings:print(json.dumps({'tags':f['tags'],'seq':f['action_anchor']['seq'],'ante':f['ante'],'cash':f['dollars'],'action':f['action'],'title':(f['advice'] or {}).get('title'),'row':[c['key'] for c in f['row']],'after_cash':f['after']['dollars'],'after_row':[c['key'] for c in f['after']['row']]}))
