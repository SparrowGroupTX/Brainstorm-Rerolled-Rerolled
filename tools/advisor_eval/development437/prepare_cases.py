"""Passive deterministic selection; no policy/scorer/game evaluation."""
from pathlib import Path
import hashlib,json,sqlite3
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent
source=(EVAL/'development434/captures/001/events.sqlite3').resolve()
db=sqlite3.connect(source.as_uri()+'?mode=ro',uri=True)
rounds={}
for seq,run,raw in db.execute("select seq,run,data from events where kind='teacher_observation' order by seq"):
 e=json.loads(raw);s=e['context']['snapshot']
 if s.get('phase')!='hand' or s.get('chips')!=0 or s.get('hands_played')!=0 or s.get('discards_used')!=0:continue
 if s.get('discards_left',0)<3 or len(s.get('hand',[]))<5:continue
 if s.get('teacher_profile')!='perkeo_yorick_win_v1':continue
 if s.get('drawpile_identity_redacted_for_concealment'):continue
 if any(c.get('face_down')for c in s.get('hand',[])):continue
 if any(c.get(flag)for area in ('hand','deck','playing_cards')for c in s.get(area,[])for flag in
        ('unknown','identity_unknown','identity_redacted')):continue
 key=(run,s.get('round'),s.get('ante'),s.get('blind',{}).get('key'))
 if key not in rounds:rounds[key]={'sequence':seq,'run':run,'snapshot':s,'raw_event_sha256':hashlib.sha256(raw.encode()).hexdigest()}
db.close()
selected={}
for key,row in rounds.items():
 run=row['run']
 if run not in selected or row['sequence']>selected[run]['sequence']:selected[run]=row
assert len(selected)==10,sorted(selected)
cases={};jobs={}
for run,row in sorted(selected.items()):
 key=f'run{run:02d}_round{row["snapshot"]["round"]}';cases[key]=row;s=row['snapshot']
 ids=[c['id']for c in s['deck']];assert len(ids)==len(set(ids))
 label=f'437:{key}:world0';seed=int(hashlib.sha256(label.encode()).hexdigest()[:8],16)
 order=sorted(ids,key=lambda c:(hashlib.sha256((label+':'+c).encode()).hexdigest(),c))
 jobs[key]={'case':key,'mode':'continuation','policy_first':True,'world':0,'world_seed':seed,
  'world_order':order,'sorting':'rank','role':'policy','action_cap':16}
for name,value in [('cases.json',cases),('jobs.json',jobs)]:
 with(HERE/name).open('x',encoding='utf-8')as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
summary=[{'case':key,'seq':r['sequence'],'ante':r['snapshot']['ante'],'blind':r['snapshot']['blind']['key'],
 'available_discards':r['snapshot']['discards_left'],'target_cards':4*r['snapshot']['discards_left']}for key,r in cases.items()]
with(HERE/'CASE_SELECTION.json').open('x',encoding='utf-8')as f:json.dump({'rule':'One per captured run: first ready visible untouched hand of the last eligible observed round; chips/hands_played/discards_used zero, >=3 discards and >=5 held cards; no concealed playing cards or redacted draw composition. Joker belief states stay registered and may be unsupported. No selection by new policy outcomes.',
 'source':str(source),'cases':summary},f,indent=2);f.write('\n')
print(json.dumps(summary))
