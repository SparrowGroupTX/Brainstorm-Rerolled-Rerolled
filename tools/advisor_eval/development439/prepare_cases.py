"""Select a fixed public round cohort before any candidate execution."""
from pathlib import Path
from collections import Counter,defaultdict
import hashlib,json,sqlite3
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
latest=json.loads((HERE/'LATEST.json').read_text())
source=(ROOT/latest['capture']/'events.sqlite3').resolve()
db=sqlite3.connect(source.as_uri()+'?mode=ro',uri=True);rounds={}
for seq,run,raw in db.execute("select seq,run,data from events where kind='teacher_observation' order by seq"):
 e=json.loads(raw);s=e['context']['snapshot']
 if s.get('phase')!='hand' or s.get('chips')!=0 or s.get('hands_played')!=0 or s.get('discards_used')!=0:continue
 if s.get('discards_left',0)<3 or len(s.get('hand',[]))<5 or len(s.get('hand',[]))!=s.get('hand_size'):continue
 if s.get('teacher_profile')!='perkeo_yorick_win_v1' or s.get('ordering_safe')is False or s.get('jokers_shuffling'):continue
 if s.get('drawpile_identity_redacted_for_concealment')or any(c.get('face_down')for c in s.get('hand',[])):continue
 if any(c.get(flag)for area in ('hand','deck','playing_cards')for c in s.get(area,[])for flag in ('unknown','identity_unknown','identity_redacted')):continue
 key=(run,s.get('round'),s.get('ante'),s.get('blind',{}).get('key'))
 if key not in rounds:rounds[key]={'sequence':seq,'run':run,'snapshot':s,'raw_event_sha256':hashlib.sha256(raw.encode()).hexdigest()}
db.close();assert len(rounds)>=20,'Fewer than20 eligible public rounds; do not evaluate'
groups=defaultdict(list)
for row in sorted(rounds.values(),key=lambda r:r['sequence']):groups[row['run']].append(row)
quotas={run:0 for run in sorted(groups)}
while sum(quotas.values())<20:
 for run in quotas:
  if sum(quotas.values())<20 and quotas[run]<len(groups[run]):quotas[run]+=1
selected=[]
for run,quota in quotas.items():
 size=len(groups[run]);indices=[(k*(size-1)//(quota-1))if quota>1 else(size-1)//2 for k in range(quota)]
 assert len(indices)==len(set(indices))==quota
 selected.extend(groups[run][i]for i in indices)
cases={};jobs={};summary=[]
for row in selected:
 s=row['snapshot'];key=f'run{row["run"]:02d}_round{s["round"]:02d}'
 assert key not in cases;cases[key]=row
 ids=[c['id']for c in s['deck']];assert len(ids)==len(set(ids))
 label=f'439:{key}:world0';seed=int(hashlib.sha256(label.encode()).hexdigest()[:8],16)%1000000000
 order=sorted(ids,key=lambda c:(hashlib.sha256((label+':'+c).encode()).hexdigest(),c))
 jobs[key]={'case':key,'mode':'continuation','policy_first':True,'world':0,'world_seed':seed,
  'world_order':order,'sorting':'rank','role':'candidate_2_217','action_cap':16}
 summary.append({'case':key,'sequence':row['sequence'],'run':row['run'],'round':s['round'],'ante':s['ante'],
  'blind':s['blind']['key'],'available_discards':s['discards_left'],'target_cards':4*s['discards_left'],
  'public_joker_belief':s.get('public_joker_belief')is not None})
assert len(cases)==len(jobs)==20
selection={'rule':'First ready visible untouched full hand per round; >=3 discards; complete public playing-card composition. Balance quotas by run in ascending round-robin order, capped by eligibility; within each run choose floor(k*(N-1)/(quota-1)) chronological positions (midpoint for quota1). No new policy/outcome selection.',
 'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'capture_session':latest['session'],'capture_cutoff_sequence':latest['last_sequence'],
 'eligible_rounds':len(rounds),'eligible_by_run':{r:len(g)for r,g in groups.items()},'quotas':quotas,'cases':summary,
 'eligible_index':[{'run':r['run'],'sequence':r['sequence'],'round':r['snapshot']['round'],'ante':r['snapshot']['ante'],
 'blind':r['snapshot']['blind']['key']}for r in rounds.values()]}
for name,value in [('cases.json',cases),('jobs.json',jobs),('CASE_SELECTION.json',selection)]:
 with(HERE/name).open('x',encoding='utf-8')as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps({'eligible':len(rounds),'quotas':quotas,'selected':summary}))
