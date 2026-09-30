"""Bounded read of six explicit opt-in public log segments; no game or save access."""
from pathlib import Path
from collections import Counter
import hashlib
import importlib.util
import io
import json
import time

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
LOG=Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2')
NAMES=[f'session-20260915T051708Z-1-{n:06d}.brj' for n in range(1,7)]
CAPS={'physical_bytes':32*1024*1024,'decoded_bytes':512*1024*1024,'events':6000,'seconds':50}
spec=importlib.util.spec_from_file_location('public_log_decoder',ROOT/'tools/advisor_eval/read_player_log.py')
decoder=importlib.util.module_from_spec(spec);spec.loader.exec_module(decoder)

def sha(data):return hashlib.sha256(data).hexdigest()
def compact(v,depth=0):
    if isinstance(v,str):return v if len(v)<=4000 else {'characters':len(v),'sha256':sha(v.encode())}
    if isinstance(v,(dict,list)) and depth>=6:return {'entries':len(v)}
    if isinstance(v,dict):return {k:compact(x,depth+1) for k,x in v.items()}
    if isinstance(v,list):return [compact(x,depth+1) for x in v]
    return v
def cards(values):
    return [{k:c[k] for k in ('id','key','name','cost','sell_cost','edition','enhancement','seal') if k in c}|
            {'ability':{k:v for k,v in c.get('ability',{}).items() if k in ('x_mult','yorick_discards','eternal','rental','perishable','extra')}}
            for c in values] if isinstance(values,list) else []
def state(s):
    result={k:s.get(k) for k in ('phase','ante','round','chips','dollars','hands_left','discards_left','hands_played','discards_used','deck_key','stake','last_hand_played','handname')}
    result['blind']={k:v for k,v in (s.get('blind') or {}).items() if k in ('key','name','chips','boss','disabled')}
    result['jokers']=cards(s.get('jokers'));result['consumeables']=cards(s.get('consumeables'))
    result['shop_jokers']=cards(s.get('shop_jokers'));result['shop_vouchers']=cards(s.get('shop_vouchers'));result['shop_booster']=cards(s.get('shop_booster'))
    result['population_count']=len(s.get('playing_cards') or []);result['draw_count']=len(s.get('deck') or [])
    result['hand_count']=len(s.get('hand') or []);result['pack_type']=s.get('pack_type')
    return result

start=time.monotonic();events=[];inputs=[];errors=[];decoded=0;physical=0;detail_keys=Counter();snapshot_keys=set();last_sequence=None;last_frame=None
for name in NAMES:
    path=(LOG/name).resolve();assert path.parent==LOG.resolve() and path.suffix=='.brj'
    before=path.stat();physical+=before.st_size
    assert physical<=CAPS['physical_bytes'],'Physical log bound exceeded'
    with path.open('rb') as stream:data=stream.read(before.st_size)
    assert len(data)==before.st_size
    receipt={'path':str(path),'bytes_read':len(data),'sha256':sha(data),'mtime_ns_before':before.st_mtime_ns,'decoded_events':0}
    inputs.append(receipt)
    try:
        for raw,meta in decoder.records(io.BytesIO(data)):
            decoded+=len(raw)
            if decoded>CAPS['decoded_bytes'] or len(events)>=CAPS['events'] or time.monotonic()-start>CAPS['seconds']:
                errors.append({'file':name,'kind':'analysis_bound_reached','complete_event_prefix_only':True});break
            event=json.loads(raw);seq=event['sequence'];context=event.get('context') or {};details=event.get('details') or {};snapshot=context.get('snapshot') or {}
            if last_sequence is not None and seq!=last_sequence+1:errors.append({'file':name,'sequence':seq,'kind':'cross_segment_sequence_gap','previous_sequence':last_sequence})
            if last_frame is not None and meta.get('previous_frame_sha256')!=last_frame:errors.append({'file':name,'sequence':seq,'kind':'cross_segment_frame_chain_gap'})
            last_sequence=seq;last_frame=meta.get('frame_sha256');snapshot_keys.update(snapshot)
            detail_keys.update(details.keys())
            projected={'file':name,'sequence':seq,'at':event.get('at'),'kind':event.get('kind'),
                       'version':context.get('version'),'seed':context.get('seed'),'stake':context.get('stake'),
                       'won_field':context.get('won_field'),'game_over':context.get('game_over'),'state':state(snapshot) if snapshot else None,
                       'advice':compact(context.get('advice')),
                       'details':compact({k:v for k,v in details.items() if k in ('event','time','session','run_number','run_action','run_actions','outcome','run_seconds','reason','detail','action','input','action_sequence','callback_returned','source','evidence','latest_action_sequence','completion','search_seconds','actions','runs_started','outcomes','advice')})}
            events.append(projected);receipt['decoded_events']+=1
    except (decoder.ArchiveError,ValueError,UnicodeError) as error:
        errors.append({'file':name,'kind':'decode_error','reason':str(error),'complete_event_prefix_only':True})
    after=path.stat();receipt.update(bytes_after=after.st_size,mtime_ns_after=after.st_mtime_ns,unchanged_metadata=before.st_size==after.st_size and before.st_mtime_ns==after.st_mtime_ns)
    if errors and errors[-1].get('kind') in ('analysis_bound_reached','decode_error'):break
value={'scope':'Read-only existing opt-in public journal observations only. No save/profile/game executable/runtime read, replay, scoring, policy/source execution, simulation or action control.',
       'decoder_path':'tools/advisor_eval/read_player_log.py','decoder_sha256':sha((ROOT/'tools/advisor_eval/read_player_log.py').read_bytes()),
       'caps':CAPS,'actual':{'physical_bytes':physical,'decoded_bytes':decoded,'events':len(events),'seconds':time.monotonic()-start},
       'inputs':inputs,'errors':errors,'event_kinds':dict(Counter(e['kind'] for e in events)),
       'loaded_versions':dict(Counter(e['version'] for e in events if e['version'])),
       'detail_keys':dict(detail_keys),'snapshot_keys':sorted(snapshot_keys),'events':events}
out=HERE/'public_log_observations.json'
with out.open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2);stream.write('\n')
print(json.dumps({'output_sha256':sha(out.read_bytes()),'actual':value['actual'],'errors':errors,'versions':value['loaded_versions'],
                  'event_kinds':value['event_kinds'],'auto_events':dict(Counter(e['details'].get('event') for e in events if e['kind']=='auto_run')),
                  'first_at':events[0]['at'] if events else None,'last_at':events[-1]['at'] if events else None,'detail_keys':list(detail_keys)},indent=2))
