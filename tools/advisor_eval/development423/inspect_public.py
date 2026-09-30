"""Descriptive preserved-journal analysis only; no policy or scorer import."""
from pathlib import Path
import json, sqlite3, argparse
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--capture',default='002');p.add_argument('--start',type=int,default=4257);p.add_argument('--end',type=int,default=100000);p.add_argument('--details',action='store_true');p.add_argument('--shop',action='store_true');a=p.parse_args()
db=sqlite3.connect((HERE/'captures'/a.capture/'events.sqlite3').resolve().as_uri()+'?mode=ro',uri=True)
last=None;last_seq=None
for seq,kind,raw in db.execute('SELECT seq,kind,data FROM events WHERE seq BETWEEN ? AND ? ORDER BY seq',(a.start,a.end)):
 e=json.loads(raw);ctx=e.get('context') or {};d=e.get('details') or {}
 if kind=='teacher_observation':last=ctx['snapshot'];last_seq=seq
 if not last:continue
 if kind=='teacher_advice':
  adv=ctx.get('advice') or {};act=adv.get('action') or {}
  if adv.get('status')!='current':continue
  if a.shop:
   if last.get('phase')!='shop' or not any(c.get('key')=='c_saturn' for c in last.get('consumeables',[])):continue
  elif last.get('phase')!='hand' or act.get('kind') not in ('play','use','reorder_hand'):continue
  r={'seq':seq,'obs':last_seq,'round':last.get('round'),'ante':last.get('ante'),'blind':last.get('blind',{}).get('key'),'cash':last.get('dollars'),'discards':last.get('discards_left'),'used':last.get('discards_used'),'hands_played':last.get('hands_played'),'chips':last.get('chips'),'target':last.get('blind',{}).get('chips'),'action':act,'title':adv.get('title')}
  for k in ('discard_before_clear','growth_diagnostics','death_fishing_review','consumable_diagnostics','timing'):
   if k in adv:r[k]=adv[k]
  if a.details:
   r['advice']=adv;r['snapshot']=last
  print(json.dumps(r,separators=(',',':')))
 if a.details and kind in ('action_requested','action_callback_result','state_after_actions','auto_run'):
  print(json.dumps({'seq':seq,'kind':kind,'details':d},separators=(',',':')))
