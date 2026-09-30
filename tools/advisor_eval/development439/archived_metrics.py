"""Passive settlement-based source-round metrics. No policy/scorer calls."""
from pathlib import Path
from collections import Counter
import json,sqlite3,hashlib
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
selection=read(HERE/'CASE_SELECTION.json');source=Path(selection['source'])
assert hashlib.sha256(source.read_bytes()).hexdigest()==selection['source_sha256']
db=sqlite3.connect(source.as_uri()+'?mode=ro',uri=True)
events={seq:{'run':run,'kind':kind,'event':json.loads(raw)} for seq,run,kind,raw in db.execute('select seq,run,kind,data from events order by seq')};db.close()
links={};callbacks={}
for seq,row in events.items():
 e=row['event'];d=e.get('details') or {}
 if row['kind']=='state_after_actions':
  for action in d.get('action_sequences') or []:links.setdefault(action,[]).append(seq)
 if row['kind']=='action_callback_result':callbacks.setdefault(d['action_sequence'],[]).append(seq)
def snapshot(seq):return events[seq]['event'].get('context',{}).get('snapshot') or {}
rows=[]
for key,c in read(HERE/'cases.json').items():
 start=c['snapshot'];target=start['blind']['chips'];run=c['run'];round_no=start['round'];seq0=c['sequence']
 terminal=None
 for seq,row in events.items():
  if seq<seq0 or row['run']!=run or row['kind']!='teacher_observation':continue
  s=snapshot(seq);ctx=row['event']['context']
  if s.get('round')!=round_no:continue
  if (s.get('phase')=='round' and s.get('chips',0)>=target) or ctx.get('game_over') is True:
   terminal=seq;break
 settled=[];gaps=[]
 if terminal:
  for seq,row in events.items():
   if seq<seq0 or seq>terminal or row['run']!=run or row['kind']!='action_requested':continue
   e=row['event'];a=((e.get('details') or {}).get('input') or {}).get('action') or {}
   if a.get('kind') not in ('discard','play') or a.get('area')!='hand':continue
   before=snapshot(e['observation_sequence'])
   if before.get('round')!=round_no:continue
   ok=None
   for link in links.get(seq,[]):
    obs=events[link]['event']['observation_sequence'];after=snapshot(obs)
    if obs>terminal or after.get('round')!=round_no:continue
    field='discards_used' if a['kind']=='discard' else 'hands_played'
    if after.get(field)!=before.get(field,0)+1:continue
    cb=[x for x in callbacks.get(seq,[]) if events[x]['event']['details'].get('callback_returned') is True]
    if not cb:continue
    ok={'request':seq,'callback':cb[0],'settled_observation':obs,'link':link,'kind':a['kind'],'cards':len(a['indices'])};break
   if ok:settled.append(ok)
   else:gaps.append(seq)
 end=snapshot(terminal) if terminal else {};dc=[r for r in settled if r['kind']=='discard'];plays=[r for r in settled if r['kind']=='play']
 counts=bool(terminal and not gaps and len(dc)==end.get('discards_used') and len(plays)==end.get('hands_played'))
 rows.append({'case':key,'terminal':terminal,'complete_settlement_accounting':counts,'gaps':gaps,
  'outcome':('observed_clear' if end.get('chips',0)>=target else 'observed_loss') if terminal else 'censored',
  'cards_discarded':sum(r['cards'] for r in dc) if counts else None,'discards_used':len(dc) if counts else None,
  'initial_available_discards':start['discards_left'],'terminal_discards_used':end.get('discards_used'),
  'terminal_hands_played':end.get('hands_played'),'settled_actions':settled})
complete=[r for r in rows if r['complete_settlement_accounting']];n=len(complete);cards=sum(r['cards_discarded']for r in complete);dc=sum(r['discards_used']for r in complete)
report={'source_sha256':selection['source_sha256'],'registered':20,'complete_settlement_rounds':n,'outcomes':dict(Counter(r['outcome'] for r in rows)),
 'discards_used':dc,'cards_discarded':cards,'discards_per_round':dc/n if n else None,'cards_per_round':cards/n if n else None,'cards_per_discard':cards/dc if dc else None,
 'scope':'Observed loaded2.216 source rounds only. Hypothetical2.217 worlds differ; this is descriptive, not paired causal improvement evidence.','rows':rows}
with(HERE/'ARCHIVED_METRICS.json').open('x',encoding='utf-8')as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({k:v for k,v in report.items()if k!='rows'}))
