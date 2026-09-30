"""Descriptive public pack-choice joins only; never run captured policy inputs."""
from pathlib import Path
import json,sqlite3
HERE=Path(__file__).resolve().parent
folder=HERE/'captures'/'003'
db=sqlite3.connect('file:'+str(folder/'events.sqlite3')+'?mode=ro',uri=True)
rows={seq:json.loads(raw) for seq,raw in db.execute('select seq,data from events order by seq')}
obs={e['observation_id']:n for n,e in rows.items() if e['kind']=='teacher_observation'}
settles={a:n for n,e in rows.items() if e['kind']=='state_after_actions' for a in e.get('details',{}).get('action_sequences',[])}
callbacks={e['details']['action_sequence']:n for n,e in rows.items() if e['kind']=='action_callback_result'}
out=[]
for n,e in rows.items():
 if e['kind']!='action_requested' or e.get('observation_id') not in obs:continue
 on=obs[e['observation_id']];s=rows[on]['context']['snapshot']
 if s.get('phase')!='pack' or not any(c.get('key')=='j_burnt' for c in s.get('pack_cards') or []):continue
 an=e.get('advice_sequence');sn=settles.get(n);cb=callbacks.get(n)
 after_obs=obs.get(rows[sn].get('observation_id')) if sn else None
 record={'request':n,'observation':on,'advice_sequence':an,'callback':cb,'settlement':sn,'after_observation':after_obs,
  'snapshot':s,'action':e['details']['input']['action'],'advice':rows.get(an,{}).get('context',{}).get('advice'),
  'after':rows[after_obs]['context']['snapshot'] if after_obs else None}
 out.append(record)
 print(json.dumps({k:record[k] for k in ('request','observation','advice_sequence','callback','settlement','action')}))
 print(json.dumps({'ante':s.get('ante'),'jokers':s.get('jokers'),'offers':s.get('pack_cards'),'advice':record['advice']}))
with (folder/'burnt_trace.json').open('x') as f:json.dump({'scope':__doc__,'findings':out},f,indent=2)
