"""Anchor recorded decisions and terminal totals; no policy/scorer execution."""
from pathlib import Path
import json,sqlite3
H=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text())
def save(name,v):
 with(H/name).open('x')as f:json.dump(v,f,indent=2);f.write('\n')
db=sqlite3.connect('file:'+str(H/'captures/001/events.sqlite3')+'?mode=ro',uri=True)
decisions=read(H/'analysis/decisions.json');runs=read(H/'analysis/runs.json')
selected={11131,11141,12141,12152,12164,26232}
trace=[]
for d in decisions:
 if d['sequence'] not in selected:continue
 seqs={d['sequence'],d['observation_sequence'],d['advice_sequence'],d['callback']['sequence'],d['settlement']['sequence']}
 settle=d['settlement']['observation_id']
 rows=db.execute('SELECT seq,kind,segment,ordinal,raw_sha,data FROM events WHERE seq IN ('+','.join('?'for _ in seqs)+') OR (kind=? AND obs=?) ORDER BY seq',(*seqs,'teacher_observation',settle))
 events=[{'sequence':s,'kind':k,'segment':sg,'ordinal':o,'body_sha256':hs,'event':json.loads(raw)}for s,k,sg,o,hs,raw in rows]
 trace.append({'request':d['sequence'],'run':d['run'],'pipeline_observed':events,'descriptive_decision':d,
  'captured_execution':False,'historical_alternative_score':None})
save('TRACE.json',trace)
losses=[]
for r in runs:
 if r['end']['details']['outcome']!='loss':continue
 after=r['last_actions'][-1]['after'];last=r['last_observation']
 assert after['chips']==last['chips']and after['hands_left']==last['hands_left']==0
 losses.append({'run':r['run'],'terminal_sequence':last['sequence'],'final_request':r['last_actions'][-1]['sequence'],
  'ante':last['ante'],'blind':last['blind']['key'],'settled_chips':last['chips'],'target':last['blind']['chips'],
  'shortfall':last['blind']['chips']-last['chips'],'unused_discards':last['discards_left'],
  'last_hand_before_final_action_chips':r['last_hand']['chips'],
  'warning':'Last hand-phase chips precede the final action; terminal joined observation is authoritative.'})
save('TERMINAL_TOTALS.json',losses)
review=read(H/'review/report.json');manifest=read(H/'captures/001/manifest.json')
summary={'public_bytes':sum(x['bytes']for x in manifest['segments']),'segments':len(manifest['segments']),
 'review_coverage':review['coverage'],'structural_subsets':review['subset_candidates_enumerated'],
 'copy_and_pack_counts':{k:v for k,v in read(H/'analysis/summary.json').items()if k in('copy_offers','copy_first_owned','buffoon_offers','buffoon_opened','death_uses','death_areas')},
 'terminal_losses':losses,'captured_policy_executions':0}
save('FINDINGS.json',summary)
print(json.dumps(summary))
