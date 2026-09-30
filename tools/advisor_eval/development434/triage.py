"""Compact passive witnesses; no policy/scorer imports."""
from pathlib import Path
import json,sqlite3
P=Path(__file__).resolve().parent
read=lambda p:json.loads(p.read_text(encoding='utf-8'))
db=sqlite3.connect((P/'captures/001/events.sqlite3').as_uri()+'?mode=ro',uri=True)
ds=read(P/'analysis/decisions.json')
def event(seq):return json.loads(db.execute('SELECT data FROM events WHERE seq=?',(seq,)).fetchone()[0])
def snap(d):return event(d['observation_sequence'])['context']['snapshot']
unused=[]
for x in read(P/'discard/unused.json'):
 d=next(d for d in ds if d['sequence']==x['request']);s=snap(d);a=d['advice']
 unused.append({'request':x['request'],'run':d['run'],'ante':s['ante'],'blind':s['blind']['name'],
  'left':x['remaining'],'reason':x['reason'],'cards':[(c.get('rank'),c.get('enhancement'),c.get('edition'))for c in x['selected_cards']],
  'jokers':[(c.get('key'),c.get('edition'),c.get('debuff'),c.get('ability',{}))for c in s['jokers']],
  'discard':a.get('discard_before_clear'),'growth':a.get('yorick_review'),'title':a.get('title')})
windows={}
for name,start,end in [('run5_blueprint',10343,10480),('run10_blueprint',27431,27540),('invisible',27646,27770)]:
 windows[name]=[{**d,'snapshot':snap(d)}for d in ds if start<=d['sequence']<=end]
short=[{'request':d['sequence'],'run':d['run'],'action':d['action'],'title':d['advice'].get('title'),
 'lines':d['advice'].get('lines'),'growth':d['advice'].get('yorick_review')}
 for d in ds if any(x['request']==d['sequence']and x['action'].get('kind')!='discard'for x in read(P/'discard/deferred.json'))]
above=[]
for d in ds:
 s=d.get('before')or{};target=25 if s.get('ante',0)>=7 else 35 if s.get('ante',0)>=4 else 50
 if(d.get('action')or{}).get('kind')=='leave_shop'and s.get('dollars',0)>target:
  above.append({'request':d['sequence'],'run':d['run'],'cash':s['dollars'],'ante':s['ante'],'target':target,'review':d['advice'].get('late_spend_review'),'lines':d['advice'].get('lines')})
for name,rows in [('unused_compact',unused),('offer_windows',windows),('deferred_non_discard',short),('cash_exits',above)]:
 with(P/(name+'.json')).open('x',encoding='utf-8')as f:json.dump(rows,f,indent=2);f.write('\n')
for r in unused:print(json.dumps({k:v for k,v in r.items()if k not in ('growth','discard','jokers')}|{'jokers':[[c[0],c[1]]for c in r['jokers']]}))
print('DEFERRED',json.dumps(short));print('CASH',json.dumps(above))
for k,rows in windows.items():
 print(k)
 for d in rows:print(json.dumps({'request':d['sequence'],'action':d['action'],'cash':d['before']['dollars'],'title':d['advice'].get('title'),'lines':d['advice'].get('lines'),'copy':d['advice'].get('copy_death_review')}))
