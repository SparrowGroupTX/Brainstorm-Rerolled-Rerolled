"""Descriptive public evidence only. Never load runtime/scoring on captures."""
from pathlib import Path
import hashlib,json,sqlite3
HERE=Path(__file__).resolve().parent
capture=HERE/'captures/004'
db=sqlite3.connect((capture/'events.sqlite3').resolve().as_uri()+'?mode=ro',uri=True)
def event(seq):return json.loads(db.execute('SELECT data FROM events WHERE seq=?',(seq,)).fetchone()[0])
def compact(seq):
 e=event(seq);c=e.get('context',{});s=c.get('snapshot');a=c.get('advice');r={'sequence':seq,'kind':e['kind'],'observation_id':e.get('observation_id')}
 if s:
  r['snapshot']={k:s.get(k) for k in ('phase','ante','round','dollars','discards_left','discards_used','hands_played','chips','blind','consumable_limit','joker_limit')}
  r['snapshot']['hands']={k:{x:h.get(x) for x in ('played','level','chips','mult')} for k,h in s.get('hands',{}).items() if h.get('played',0)>0 or h.get('level',1)>1}
  for area in ('jokers','consumeables','shop_jokers','shop_booster','pack_cards'):
   r['snapshot'][area]=[{k:card[k] for k in ('id','key','cost','sell_cost','edition','ability') if k in card} for card in s.get(area,[])]
 if a:r['advice']={k:a.get(k) for k in ('status','action','title','lines','discard_before_clear','yorick_review','reroll_review','timing','phase_copy_review')}
 if e['kind'] in ('action_requested','action_callback_result','state_after_actions'):r['details']=e.get('details')
 return r
sequences=set()
for lo,hi in ((4820,4880),(5247,5308),(5682,5746),(6372,6411),(6679,6715),(8549,8570),(8878,8942)):
 for seq,k,raw in db.execute('SELECT seq,kind,data FROM events WHERE seq BETWEEN ? AND ?',(lo,hi)):
  e=json.loads(raw)
  if k in ('teacher_observation','action_requested','action_callback_result','state_after_actions') or k=='teacher_advice' and e.get('context',{}).get('advice',{}).get('status')=='current':sequences.add(seq)
venus=[]
for seq,raw in db.execute("SELECT seq,data FROM events WHERE seq>9474 AND kind='teacher_observation' ORDER BY seq"):
 s=json.loads(raw)['context']['snapshot'];keys=[c.get('key') for c in s.get('consumeables',[])]
 if s['phase']=='shop' and 'c_venus' in keys and 'c_judgement' in keys:
  venus.append(seq);sequences.add(seq)
  for n,raw in db.execute("SELECT seq,data FROM events WHERE seq>? AND kind='teacher_advice' ORDER BY seq LIMIT 3",(seq,)):
   e=json.loads(raw)
   if e.get('context',{}).get('advice',{}).get('status')=='current':sequences.add(n);break
  if len(venus)>=4:break
for advice,action,callback,physical,settled,left in ((5735,5738,5739,5744,5746,2),(6400,6403,6404,6409,6411,2),(6705,6708,6709,6713,6715,1)):
 a=event(advice)['context']['advice'];s=event(physical)['context']['snapshot']
 assert a['discard_before_clear']['remaining_discards']==left
 assert event(callback)['details']['action_sequence']==action and action in event(settled)['details']['action_sequences']
 assert s['phase']=='round' and s['discards_left']==left and s['chips']>=s['blind']['chips']
assert event(8555)['details']['input']['action']=={'area':'shop_jokers','index':2,'kind':'buy'}
assert [c['key'] for c in event(8549)['context']['snapshot']['shop_jokers']]==['c_mercury','c_lovers']
record={'revision':423,'session':'session-20260927T163146Z-1','loaded_version':'2.205.0-alpha',
 'scope':'passive public observation/action/settlement analysis only; no captured-state evaluation',
 'database_sha256':hashlib.sha256((capture/'events.sqlite3').read_bytes()).hexdigest(),
 'confirmed_one_hand_clear_sequences':[5735,6400,6705],
 'confirmed_discard_rejection':'Automatic hand sorting can change scoring-card order.',
 'arcana_actually_opened':[4834,5251],'shop_exit_with_saturn':[4871,5299],
 'lovers_over_mercury_request':8555,'mars_visible_at_exit':8932,'venus_judgement_observations':venus,
 'runtime_replay':False,'source_execution':False,'game_control':False,'events':[compact(seq) for seq in sorted(sequences)]}
with (HERE/'TRACE.json').open('x',encoding='utf-8') as f:json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({k:record[k] for k in ('confirmed_one_hand_clear_sequences','arcana_actually_opened','shop_exit_with_saturn','venus_judgement_observations')}))
