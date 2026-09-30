"""Read existing frozen public logs only; no captured policy/source execution."""
from pathlib import Path
import collections, hashlib, io, json, sys
ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).resolve().parent
LOG=HERE.parent/'log_analysis'
sys.path.insert(0,str(ROOT/'tools/advisor_eval'))
from read_player_log import records
def sha(data):return hashlib.sha256(data).hexdigest()
summary=json.loads((LOG/'summary.json').read_bytes())
assert sha((LOG/'summary.json').read_bytes())=='2011bb96d1d5e89153156db4b5cb7fc4932699153aba1828985946a45a6730cf'
wanted={111,116,322,370,418,1116,1158,1315,1367,1408,2773,2865,2909,3488,3493,3498,3503}
inputs=[];rounds={};selected=[];versions=collections.Counter();count=0
for source_group in (summary['inputs'],summary['newer_session']['inputs']):
 for item in source_group:
  path=Path(item['frozen_path'])
  assert path.parent in (LOG/'frozen_prefix',LOG/'newer_frozen_prefix')
  data=path.read_bytes();assert len(data)==item['bytes'] and sha(data)==item['sha256']
  inputs.append({'path':str(path),'bytes':len(data),'sha256':sha(data)})
  for ordinal,(raw,meta) in enumerate(records(io.BytesIO(data)),1):
   event=json.loads(raw);count+=1
   context=event.get('context',{});snapshot=context.get('snapshot',{})
   version=context.get('version');versions[version or 'absent']+=1
   if event.get('kind')!='action_requested' or snapshot.get('phase')!='hand' or snapshot.get('ante',99)>3:continue
   ys=[j for j in snapshot.get('jokers',[]) if j.get('key')=='j_yorick']
   if not ys:continue
   action=event.get('details',{}).get('input',{}).get('action',{})
   key=(path.name.split('-00')[0],context.get('seed'),snapshot.get('ante'),snapshot.get('round'))
   if key not in rounds:
    rounds[key]={'session_prefix':path.name.rsplit('-',1)[0],'seed':context.get('seed'),'version':version,
     'ante':snapshot.get('ante'),'round':snapshot.get('round'),'blind':snapshot.get('blind',{}).get('name'),
     'first_sequence':event.get('sequence'),'discard_requests':0,'requested_discard_cards':0,'play_requests':0,
     'growth_discard_requests':0,'first_yorick':[{'id':j.get('id'),'x_mult':j.get('ability',{}).get('x_mult'),
       'yorick_discards':j.get('ability',{}).get('yorick_discards')} for j in ys]}
   r=rounds[key];advice=context.get('advice',{})
   if action.get('kind')=='discard':
    r['discard_requests']+=1;r['requested_discard_cards']+=len(action.get('indices',[]))
    if 'grow Yorick' in advice.get('title','') or 'Yorick threshold' in advice.get('title',''):r['growth_discard_requests']+=1
   if action.get('kind')=='play':r['play_requests']+=1
   r['last_sequence']=event.get('sequence');r['discards_left_at_last_hand_request']=snapshot.get('discards_left')
   r['last_yorick']=[{'id':j.get('id'),'x_mult':j.get('ability',{}).get('x_mult'),
     'yorick_discards':j.get('ability',{}).get('yorick_discards')} for j in ys]
   if path.parent!=LOG/'frozen_prefix' or event.get('sequence') not in wanted:continue
   dest=HERE/('original_event_'+str(event['sequence'])+'.json')
   with dest.open('xb') as handle:handle.write(raw)
   indices=action.get('indices',[])
   selected.append({'anchor':{'segment':path.name,'ordinal':ordinal,'sequence':event['sequence'],
      'decoded_event_sha256':sha(raw),'stored_frame_sha256':meta.get('frame_sha256')},
    'original_event_path':str(dest),'at':event.get('at'),'version':version,'seed':context.get('seed'),
    'state':{k:snapshot.get(k) for k in ('phase','ante','round','hands_left','discards_left','discards_used','chips','dollars','hand_size','hand_limit','blind')},
    'action':action,'advice':advice,'deck_count':len(snapshot.get('deck',[])),
    'jokers':[{k:j.get(k) for k in ('id','key','ability','edition','debuff','blueprint_compat','pinned')} for j in snapshot.get('jokers',[])],
    'selected_cards':[{**{k:snapshot['hand'][i-1].get(k) for k in ('id','rank','suit','enhancement','ability','edition','seal','debuff')},'index':i}
      for i in indices] if action.get('area')=='hand' else [],
    'inventory_count':len(snapshot.get('consumeables',[]))})
source_paths=['Brainstorm/Advisor/'+f for f in ('growth.lua','decision.lua','multi_discard.lua','phase_copy.lua','search.lua')]
report={'scope':'Read-only static audit of already frozen passive public logs. No policy evaluation, captured replay, original-source execution, search, complete attempt, live game or save/profile read.',
 'decoded_events':count,'versioned_event_counts':dict(versions),'inputs':inputs,
 'source_hashes':{p:sha((ROOT/p).read_bytes()) for p in source_paths},'early_round_request_counts':list(rounds.values()),
 'selected_public_events':selected,'limits':['Action-request counts do not by themselves establish execution or optimal alternatives.',
 'Advice score titles are recorded estimates; no counterfactual scoring was performed.',
 'These dependent user-started runs are development observations, not a representative win-rate cohort.']}
out=HERE/'report.json'
with out.open('x',encoding='utf-8') as handle:json.dump(report,handle,indent=2);handle.write('\n')
print(json.dumps({'path':str(out),'sha256':sha(out.read_bytes()),'decoded_events':count,'selected_events':len(selected),
 'early_rounds':len(rounds),'versions':dict(versions),
 'rh45ad21':[r for r in rounds.values() if r['seed']=='RH45AD21']}))
