"""Descriptive public joins only; no policy/scorer or original-game execution."""
from pathlib import Path
from collections import Counter
import hashlib,json,sqlite3
HERE=Path(__file__).resolve().parent
verification=json.loads((HERE/'capture/verification.json').read_text())
assert not verification['failures']
assert hashlib.sha256((HERE/'events.sqlite3').read_bytes()).hexdigest()==verification['database_sha256']
db=sqlite3.connect((HERE/'events.sqlite3').as_uri()+'?mode=ro',uri=True)
rows=[{'seq':r[0],'run':r[1],'segment':r[2],'ordinal':r[3],'sha256':r[4],'event':json.loads(r[5])}
 for r in db.execute('SELECT seq,run,segment,ordinal,raw_sha,data FROM events ORDER BY seq')];db.close()
byseq={r['seq']:r for r in rows};observations={r['event']['observation_id']:r for r in rows if r['event']['kind']=='teacher_observation'}
callbacks={r['event'].get('details',{}).get('action_sequence'):r for r in rows if r['event']['kind']=='action_callback_result'}
obsrows=list(observations.values());exits=[];reorders=[]
def snapshot(row):return row['event'].get('context',{}).get('snapshot',{})
def active(j):
 a=j.get('ability') or {};return not (j.get('debuff') or a.get('perma_debuff') or a.get('perishable') and a.get('perish_tally',5)<=0)
def effects(row):
 def target(i,seen):
  if i<0 or i>=len(row) or i in seen or not active(row[i]):return None
  j=row[i]
  if j.get('unknown') or j.get('identity_redacted') or j.get('face_down'):return None
  if j.get('key') in ('j_blueprint','j_brainstorm'):
   nxt=i+1 if j['key']=='j_blueprint' else 0
   if nxt>=len(row) or row[nxt].get('blueprint_compat') is False:return None
   return target(nxt,seen|{i})
  return j.get('key')
 return sum(target(i,set())=='j_perkeo' for i in range(len(row)))
for r in rows:
 e=r['event']
 if e['kind']!='action_requested':continue
 action=e.get('details',{}).get('input',{}).get('action',{})
 if action.get('kind') not in ('leave_shop','reorder_jokers'):continue
 observed=observations.get(e.get('observation_id'));s=snapshot(observed) if observed else {}
 if s.get('phase')!='shop':continue
 advised=byseq.get(e.get('advice_sequence'));ad=advised['event'].get('context',{}).get('advice',{}) if advised else {}
 row=s.get('jokers',[]);pool=s.get('consumeables',[])
 record={'request':r['seq'],'at':e.get('at'),'run':r['run'],'ante':s.get('ante'),'action':action,
  'observation':observed['seq'],'advice':advised['seq'] if advised else None,
  'callback':callbacks.get(r['seq'],{}).get('seq'),'callback_details':callbacks.get(r['seq'],{}).get('event',{}).get('details'),
  'row':[{k:j.get(k) for k in ('id','key','debuff','pinned','blueprint_compat')} for j in row],
  'perkeo_effects':effects(row),'active_copy_jokers':sum(j.get('key') in ('j_blueprint','j_brainstorm') and active(j) for j in row),
  'inventory_size':len(pool),'inventory_keys':dict(Counter(c.get('key') for c in pool)),
  'inventory_distinct_types':len(set((c.get('key'),bool(c.get('debuff'))) for c in pool)),
  'title':ad.get('title'),'lines':ad.get('lines'), 'phase_copy_receipt':ad.get('phase_copy_review')}
 next_obs=next((o for o in obsrows if o['seq']>r['seq'] and o['event'].get('context',{}).get('run_instance')==e.get('context',{}).get('run_instance') and
  (action['kind']=='reorder_jokers' or snapshot(o).get('phase')!='shop')),None)
 if next_obs:
  after=snapshot(next_obs);held=after.get('consumeables',[]);ids={c.get('id') for c in pool};after_ids={c.get('id') for c in held}
  record['next_observation']=next_obs['seq'];record['next_phase']=after.get('phase')
  record['next_row']=[(j.get('id'),j.get('key')) for j in after.get('jokers',[])]
  record['held_ids_retained']=ids<=after_ids
  record['added_consumables']=[{k:c.get(k) for k in ('id','key','edition')} for c in held if c.get('id') not in ids]
 (exits if action['kind']=='leave_shop' else reorders).append(record)
interesting=[x for x in exits if x['active_copy_jokers'] and x['inventory_size'] and x['perkeo_effects']<x['active_copy_jokers']+1]
summary={'session':verification['session'],'events':verification['events'],'versions':verification['versions'],
 'recorded_outcomes':verification['outcomes'],'unended_run_ids':verification['unended_run_ids'],
 'shop_exits':len(exits),'shop_reorders':len(reorders),'exits_by_run':dict(Counter(x['run'] for x in exits)),
 'perkeo_with_copy_and_stock_exits':sum(bool(x['active_copy_jokers'] and x['inventory_size']) for x in exits),
 'not_maximum_simple_copy_count_exits':len(interesting),
 'inventory_types_above_eight_exits':sum(x['inventory_distinct_types']>8 for x in exits),
 'more_than_four_possible_effect_exits':sum(x['active_copy_jokers']+1>4 for x in exits),
 'scope':'Descriptive closed public journal joins. No policy/scorer replay, hidden information or counterfactual win claim. Normal exit not established; last started run remains censored.'}
anchors={x[k] for x in interesting+reorders for k in ('request','observation','advice','callback','next_observation') if x.get(k)}
report={'summary':summary,'exits':exits,'reorders':reorders,'review_candidates':interesting,'anchors':[byseq[seq] for seq in sorted(anchors)]}
with (HERE/'closed_perkeo_audit.json').open('x',encoding='utf-8') as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps(summary))
for x in reorders+interesting:print(json.dumps({k:x.get(k) for k in ('request','run','ante','perkeo_effects','inventory_keys','next_observation','held_ids_retained','added_consumables')}))
