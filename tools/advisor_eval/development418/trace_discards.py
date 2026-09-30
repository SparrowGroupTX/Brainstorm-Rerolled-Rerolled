"""Join public requests/advice/settlements; never load policy or score a game."""
from pathlib import Path
import argparse,hashlib,json,sqlite3
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('capture');a=p.parse_args()
source=HERE/'captures'/a.capture
db=sqlite3.connect('file:'+str(source/'events.sqlite3')+'?mode=ro',uri=True)
events={row[0]:{'seq':row[0],'kind':row[1],'run':row[2],'obs':row[3],
 'advice_seq':row[4],'segment':row[5],'ordinal':row[6],'raw_sha':row[7],'event':json.loads(row[8])}
 for row in db.execute('SELECT seq,kind,run,obs,advice_seq,segment,ordinal,raw_sha,data FROM events ORDER BY seq')}
db.close()
observations={v['obs']:v for v in events.values() if v['kind']=='teacher_observation'}
settlements={};callbacks={}
for v in events.values():
 d=v['event'].get('details') or {}
 if v['kind']=='state_after_actions':
  for seq in d.get('action_sequences') or []:settlements.setdefault(seq,v)
 if v['kind']=='action_callback_result':callbacks[d.get('action_sequence')]=v
def snap(v):return ((v or {}).get('event',{}).get('context') or {}).get('snapshot') or {}
def anchor(v):return {k:v.get(k) for k in ('seq','segment','ordinal','raw_sha')}
flags=[]
for v in events.values():
 if v['kind']!='action_requested':continue
 action=((v['event'].get('details') or {}).get('input') or {}).get('action') or {}
 if action.get('kind')!='play':continue
 ob=observations.get(v['obs']);s=snap(ob)
 if s.get('discards_left',0)<=0:continue
 settled=settlements.get(v['seq']);after=observations.get((settled or {}).get('obs'));t=snap(after)
 if not t:continue
 ad=events.get(v['advice_seq']);advice=((ad or {}).get('event',{}).get('context') or {}).get('advice') or {}
 blind=s.get('blind') or {};target=blind.get('chips',0)
 physically_clear=bool(target>0 and t.get('chips',0)>=target and s.get('chips',0)<target)
 receipt=advice.get('discard_before_clear') or {}
 cards=s.get('hand') or []
 flags.append({'run':v['run'],'ante':s.get('ante'),'blind':blind.get('name'),'target':target,
  'discards':s['discards_left'],'hands':s.get('hands_left'),'physically_clear':physically_clear,
  'chips_before':s.get('chips'),'chips_after':t.get('chips'),
  'observation':anchor(ob),'advice':anchor(ad),'request':anchor(v),'settlement':anchor(settled),
  'callback':(callbacks.get(v['seq']) or {}).get('event',{}).get('details'),
  'action':action,'advice_action':advice.get('action'),'receipt':receipt,
  'selected_public_cards':[{k:cards[i-1].get(k) for k in ('id','rank','suit','enhancement','seal','edition','ability')} for i in action.get('indices',[]) if 1<=i<=len(cards)],
  'jokers':[{k:j.get(k) for k in ('id','key','ability','edition','debuff')} for j in s.get('jokers') or []]})
report={'capture':a.capture,'database_sha256':hashlib.sha256((source/'events.sqlite3').read_bytes()).hexdigest(),
 'scope':'Descriptive public evidence only. Suspect flags are not counterfactual wins or proof every discard was safe.',
 'settled_plays_with_discards':len(flags),'physically_clear_count':sum(x['physically_clear'] for x in flags),'flags':flags}
with (source/'discard_trace.json').open('x',encoding='utf-8') as f:json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({k:report[k] for k in ('capture','settled_plays_with_discards','physically_clear_count')}))
for x in flags:
 if x['physically_clear']:print(json.dumps({'request':x['request']['seq'],'run':x['run'],'ante':x['ante'],'blind':x['blind'],'discards':x['discards'],'reason':x['receipt'].get('reason'),'jokers':[j['key'] for j in x['jokers']]}))
