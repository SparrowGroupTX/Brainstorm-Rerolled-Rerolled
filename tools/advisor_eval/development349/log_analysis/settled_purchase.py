"""Extract the first actual Droll-held observation from already frozen bytes."""
import hashlib
import io
import json
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/advisor_eval'))
from read_player_log import records
def sha(data):return hashlib.sha256(data).hexdigest()
original=HERE/'report.json'
assert sha(original.read_bytes())=='0df19b1309c28aec2bd2172358782ea1add009bb5c97b533908729f784ca9694'
report=json.loads(original.read_bytes());out=[]
for item in report['inputs']:
 data=Path(item['frozen_path']).read_bytes();assert len(data)==item['bytes'] and sha(data)==item['sha256']
 for ordinal,(raw,meta) in enumerate(records(io.BytesIO(data)),1):
  e=json.loads(raw)
  if e.get('sequence') not in (88,90,95):continue
  c=e.get('context',{});s=c.get('snapshot',{});g=s.get('completionist_goal',{})
  dest=HERE/('original_event_'+str(e['sequence'])+'.json')
  with dest.open('xb') as handle:handle.write(raw)
  out.append({'anchor':{'segment':Path(item['frozen_path']).name,'ordinal':ordinal,'sequence':e['sequence'],
     'stored_frame_sha256':meta.get('frame_sha256'),'decoded_event_sha256':sha(raw)},
   'original_event_path':str(dest),'at':e.get('at'),'kind':e.get('kind'),'version':c.get('version'),'seed':c.get('seed'),
   'state':{k:s.get(k) for k in ('ante','round','phase','state','dollars')},
   'jokers':[{'id':j.get('id'),'key':j.get('key'),'name':j.get('name'),'eternal':j.get('ability',{}).get('eternal',False),
     'gold_record':g.get('by_key',{}).get(j.get('key'))} for j in s.get('jokers',[])],
   'action':e.get('details',{}).get('input',{}).get('action'),
   'event':e.get('details',{}).get('event'),'advice_title':(c.get('advice') or {}).get('title')})
dest=HERE/'settled_purchase.json'
with dest.open('x',encoding='utf-8') as handle:
 json.dump({'schema':1,'scope':'Read-only extraction from already frozen passive bytes; no evaluator calls.',
   'parent_report':{'path':str(original),'sha256':sha(original.read_bytes())},
   'observations':out,
   'conclusion':'Purchase effects are directly observed at88: same Droll physical card held and cash5->1. Record87 predates the queued effects. This establishes actual acquisition, not strategic optimality or later outcome.'},handle,indent=2);handle.write('\n')
print(json.dumps({'path':str(dest),'sha256':sha(dest.read_bytes()),'sequences':[e['anchor']['sequence'] for e in out]}))
