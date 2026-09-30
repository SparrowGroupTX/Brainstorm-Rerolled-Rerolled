"""One bounded passive read of the newest contiguous public journal tail."""
from pathlib import Path
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import importlib.util
import io
import json
import re
import statistics
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
LOG=Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2').resolve()
CAPS={'files':6,'physical_bytes':32*1024*1024,'decoded_bytes':512*1024*1024,'events':6000,'parse_seconds':50}
PATTERN=re.compile(r'^(session-\d{8}T\d{6}Z-\d+)-(\d{6})\.brj$')
sha=lambda b:hashlib.sha256(b).hexdigest()
def write(name,value):
    with (HERE/name).open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2);stream.write('\n')
def compact(value):
    if isinstance(value,str) and len(value)>2000:return {'characters':len(value),'sha256':sha(value.encode())}
    if isinstance(value,dict):return {k:compact(v) for k,v in value.items()}
    if isinstance(value,list):return [compact(v) for v in value]
    return value
def stamp(at):
    return datetime.fromisoformat(at.replace('Z','+00:00')).timestamp() if isinstance(at,str) else None
def statistics_for(values):
    return {'count':len(values),'sum_seconds':sum(values),'median_seconds':statistics.median(values) if values else None,
            'max_seconds':max(values) if values else None}

inventory=[]
for path in LOG.iterdir():
    match=PATTERN.fullmatch(path.name)
    if match and path.is_file():
        meta=path.stat();inventory.append({'name':path.name,'session':match[1],'segment':int(match[2]),
                                         'bytes':meta.st_size,'mtime_ns':meta.st_mtime_ns})
assert inventory,'No matching opt-in public logs'
latest=max(inventory,key=lambda x:(x['session'],x['segment']))
group={r['segment']:r for r in inventory if r['session']==latest['session']}
selected=[];total=0
for segment in range(latest['segment'],0,-1):
    if segment not in group or len(selected)>=CAPS['files']:break
    row=group[segment]
    if total+row['bytes']>CAPS['physical_bytes']:break
    selected.append(row);total+=row['bytes']
selected.reverse();assert selected
write('inventory.json',{'at_utc':datetime.now(timezone.utc).isoformat(),'directory':str(LOG),
    'files':sorted(inventory,key=lambda x:x['name']),'selected':selected,
    'selection':'Newest session by sortable declared UTC filename; contiguous tail ending at largest segment, max6files/32MiB. Earlier predecessor is outside the chosen tail.'})
spec=importlib.util.spec_from_file_location('decoder324',ROOT/'tools/advisor_eval/read_player_log.py')
decoder=importlib.util.module_from_spec(spec);spec.loader.exec_module(decoder)
start=time.monotonic();events=[];inputs=[];errors=[];decoded=0;physical=0;last_sequence=None;last_frame=None
context_keys=Counter();detail_keys=Counter();complete=True
for chosen in selected:
    path=(LOG/chosen['name']).resolve();assert path.parent==LOG and path.suffix=='.brj'
    before=path.stat();size=before.st_size
    if physical+size>CAPS['physical_bytes']:
        errors.append({'kind':'physical_bound_before_read','file':path.name,'bytes_requested':size});complete=False;break
    with path.open('rb') as stream:data=stream.read(size)
    physical+=len(data)
    receipt={'path':str(path),'bytes_read':len(data),'sha256':sha(data),'initial_stat_bytes':size,
             'mtime_ns_before':before.st_mtime_ns,'events':0,'decoded_bytes':0,'complete_file_prefix':True}
    inputs.append(receipt)
    stream=io.BytesIO(data);iterator=decoder.records(stream)
    while True:
        # Reserve the decoder's maximum reconstructed event before decoding it.
        # This avoids crossing the aggregate limit even on a largest-size frame.
        if len(events)>=CAPS['events'] or decoded+decoder.MAX_EVENT>CAPS['decoded_bytes'] or time.monotonic()-start>=CAPS['parse_seconds']:
            errors.append({'kind':'parse_bound_reached','file':path.name,'complete_event_prefix_only':True})
            complete=False;receipt['complete_file_prefix']=False;break
        offset=stream.tell()
        try:raw,meta=next(iterator)
        except StopIteration:break
        except (decoder.ArchiveError,ValueError,UnicodeError) as error:
            errors.append({'kind':'decode_error','file':path.name,'offset':offset,'reason':str(error),'complete_event_prefix_only':True})
            complete=False;receipt['complete_file_prefix']=False;break
        decoded+=len(raw);event=decoder.parsed(raw);seq=event['sequence']
        if last_sequence is not None and seq!=last_sequence+1:
            errors.append({'kind':'cross_segment_sequence_gap','file':path.name,'sequence':seq,'previous':last_sequence});complete=False;break
        if last_frame is not None and meta['previous_frame_sha256']!=last_frame:
            errors.append({'kind':'cross_segment_frame_chain_gap','file':path.name,'sequence':seq});complete=False;break
        if meta['session']!=chosen['session'] or meta['segment']!=chosen['segment']:
            errors.append({'kind':'filename_frame_identity_mismatch','file':path.name,'sequence':seq});complete=False;break
        last_sequence=seq;last_frame=meta['frame_sha256']
        context=event.get('context') or {};details=event.get('details') or {};snapshot=context.get('snapshot') or {}
        context_keys.update(context.keys());detail_keys.update(details.keys())
        state={k:snapshot.get(k) for k in ('phase','ante','round','chips','dollars','hands_left','discards_left')}
        state['blind']={k:v for k,v in (snapshot.get('blind') or {}).items() if k in ('key','name','chips','boss')}
        row={'file':path.name,'sequence':seq,'at':event.get('at'),'kind':event.get('kind'),
             'version':context.get('version'),'seed':context.get('seed'),'won_field':context.get('won_field'),
             'game_over':context.get('game_over'),'state':state if snapshot else None,
             'advice':compact(context.get('advice')),'details':compact(details),
             'original_event_bytes':len(raw),'wire_frame_bytes':stream.tell()-offset,
             'snapshot_json_bytes':len(json.dumps(snapshot,separators=(',',':')).encode()) if snapshot else 0,
             'frame_sha256':meta['frame_sha256'],'previous_frame_sha256':meta['previous_frame_sha256']}
        events.append(row);receipt['events']+=1;receipt['decoded_bytes']+=len(raw)
    after=path.stat();receipt.update(bytes_after=after.st_size,mtime_ns_after=after.st_mtime_ns,
        metadata_unchanged_during_read=before.st_size==after.st_size and before.st_mtime_ns==after.st_mtime_ns)
    if not complete:break
parse_seconds=time.monotonic()-start
assert physical<=CAPS['physical_bytes'] and decoded<=CAPS['decoded_bytes'] and len(events)<=CAPS['events']
projection={'scope':'Only bounded opt-in public journal files. No saves/profiles/game/executable/native/source reads or execution, replay, rescoring, search, simulation or gameplay.',
    'caps':CAPS,'actual':{'files':len(inputs),'physical_bytes':physical,'decoded_bytes':decoded,'events':len(events),'parse_seconds':parse_seconds},
    'decoder':{'path':'tools/advisor_eval/read_player_log.py','sha256':sha((ROOT/'tools/advisor_eval/read_player_log.py').read_bytes())},
    'inventory_sha256':sha((HERE/'inventory.json').read_bytes()),'inputs':inputs,'errors':errors,
    'complete_selected_tail':complete,'earlier_session_prefix_inspected':False,'external_predecessor_verified':False,
    'within_tail_sequence_and_frame_chain_verified':complete,
    'context_keys':dict(context_keys),'detail_keys':dict(detail_keys),'events':events}
write('observations.json',projection)
byseq={e['sequence']:e for e in events}
callbacks={e['details'].get('action_sequence'):e for e in events if e['kind']=='action_callback_result'}
settled={e['details'].get('latest_action_sequence'):e for e in events if e['kind']=='state_after_actions'}
observed={e['details'].get('action_token'):e for e in events if e['kind']=='auto_run' and e['details'].get('event')=='action_observed'}
actions=[]
for e in events:
    d=e['details']
    if e['kind']!='auto_run' or d.get('event')!='action_attempt':continue
    req=byseq.get(e['sequence']+1)
    match=bool(req and req['kind']=='action_requested' and req['details'].get('input',{}).get('action')==d.get('action'))
    cb=callbacks.get(req['sequence']) if match else None
    end=settled.get(req['sequence']) if match else None
    obs=observed.get(d.get('action_token'))
    if obs and (obs['sequence']<=e['sequence'] or obs['details'].get('time',-1)<d.get('time',0)):obs=None
    row={'sequence':e['sequence'],'at':e['at'],'seed':e['seed'],'run_id':d.get('run_id'),'run_action':d.get('run_action'),
         'state':e['state'],'action':d.get('action'),'advice_title':(d.get('advice') or {}).get('title'),
         'request_exact_match':match,'accepted_callback':cb['details'].get('callback_returned') if cb else None,
         'callback_sequence':cb['sequence'] if cb else None,'settled_sequence':end['sequence'] if end else None,
         'observed_sequence':obs['sequence'] if obs else None,
         'action_to_settled_whole_second_stamp_difference':stamp(end['at'])-stamp(e['at']) if end else None,
         'action_to_callback_whole_second_stamp_difference':stamp(cb['at'])-stamp(e['at']) if cb else None,
         'action_to_fresh_advice_monotonic_seconds':obs['details']['time']-d['time'] if obs else None,
         'attempt_event_bytes':e['original_event_bytes'],'attempt_wire_bytes':e['wire_frame_bytes']}
    actions.append(row)
gaps=[]
for a,b in zip(events,events[1:]):
    delta=stamp(b['at'])-stamp(a['at'])
    gaps.append({'seconds_by_whole_second_stamps':delta,'before_sequence':a['sequence'],'after_sequence':b['sequence'],
        'before_kind':a['kind'],'before_event':a['details'].get('event'),'after_kind':b['kind'],'after_event':b['details'].get('event'),
        'before_at':a['at'],'after_at':b['at'],'seed_before':a['seed'],'seed_after':b['seed'],'before_state':a['state'],'after_state':b['state']})
terminals=[{'sequence':e['sequence'],'at':e['at'],'version':e['version'],'seed':e['seed'],'state':e['state'],
    'game_over':e['game_over'],'won_field':e['won_field'],'details':e['details']} for e in events
    if e['kind']=='auto_run' and e['details'].get('event') in ('run_finished','session_stopped','collection_complete')]
groups=defaultdict(list)
for row in actions:
    if row['action_to_fresh_advice_monotonic_seconds'] is not None:groups[row['action'].get('kind')].append(row['action_to_fresh_advice_monotonic_seconds'])
byrun=[]
for key in dict.fromkeys(row['run_id'] for row in actions):
    selected_actions=[row for row in actions if row['run_id']==key]
    values=[row['action_to_fresh_advice_monotonic_seconds'] for row in selected_actions if row['action_to_fresh_advice_monotonic_seconds'] is not None]
    byrun.append({'run_id':key,'seeds':sorted(set(row['seed'] for row in selected_actions if row['seed'])),'actions':len(selected_actions),
        'first_run_action':selected_actions[0]['run_action'],'last_run_action':selected_actions[-1]['run_action'],
        'timing':statistics_for(values),'first_at':selected_actions[0]['at'],'last_at':selected_actions[-1]['at']})
first=events[0] if events else None;last=events[-1] if events else None
report={k:v for k,v in projection.items() if k not in ('events','context_keys','detail_keys')}
report.update({'observations_sha256':sha((HERE/'observations.json').read_bytes()),
    'loaded_versions':dict(Counter(e['version'] for e in events if e['version'])),
    'first':{k:first[k] for k in ('sequence','at','kind','seed','state')} if first else None,
    'last':{k:last[k] for k in ('sequence','at','kind','seed','state')} if last else None,
    'event_kinds':dict(Counter(e['kind'] for e in events)),
    'auto_event_kinds':dict(Counter(e['details'].get('event') for e in events if e['kind']=='auto_run')),
    'wall_clock_stamp_resolution':{'whole_second_iso_values':sum(bool(re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ',e['at'] or '')) for e in events),
        'same_second_adjacent_events':sum(g['seconds_by_whole_second_stamps']==0 for g in gaps),
        'negative_adjacent_differences':sum(g['seconds_by_whole_second_stamps']<0 for g in gaps),
        'limitation':'Whole-second timestamp differences are quantized and do not establish subsecond callback/write latency.'},
    'action_count':len(actions),'request_matches':sum(a['request_exact_match'] for a in actions),
    'accepted_callbacks':sum(a['accepted_callback'] is True for a in actions),
    'timing':statistics_for([a['action_to_fresh_advice_monotonic_seconds'] for a in actions if a['action_to_fresh_advice_monotonic_seconds'] is not None]),
    'timing_by_action':{k:statistics_for(v) for k,v in groups.items()},'run_windows':byrun,
    'largest_action_intervals':sorted([a for a in actions if a['action_to_fresh_advice_monotonic_seconds'] is not None],key=lambda x:x['action_to_fresh_advice_monotonic_seconds'],reverse=True)[:20],
    'largest_adjacent_event_gaps':sorted(gaps,key=lambda x:x['seconds_by_whole_second_stamps'],reverse=True)[:20],
    'largest_events':[{'sequence':e['sequence'],'kind':e['kind'],'event':e['details'].get('event'),'at':e['at'],
        'original_event_bytes':e['original_event_bytes'],'wire_frame_bytes':e['wire_frame_bytes'],'snapshot_json_bytes':e['snapshot_json_bytes']}
        for e in sorted(events,key=lambda x:x['original_event_bytes'],reverse=True)[:12]],
    'terminal_or_stop_receipts':terminals,
    'detail_field_names':sorted(detail_keys),'context_field_names':sorted(context_keys),
    'limitations':['No per-decision compute time, score-call/cap counts, frame CPU, disk write/compression latency or selected animation-speed receipt exists in these records.',
        'Action-to-advice monotonic intervals include execution, animation, engine settling, advisor work and journal work; they cannot isolate a freeze cause.',
        'State-after-actions is a first settled public observation, not proof every queued effect has completed; callbacks alone do not prove completion.',
        'The selected tail omits earlier session segments and may begin or end inside a run. Missing terminal/start receipts are not imputed.',
        'Loaded version declarations do not attest loaded module hashes or establish measured release efficacy.',
        'These passive user product observations are separate from all closed synthetic experiment budgets and historical win/loss counts.'],
    'prior_window_comparison':{'prior_report':'tools/advisor_eval/development322/public_run_report_final.json',
        'prior_sha256':sha((ROOT/'tools/advisor_eval/development322/public_run_report_final.json').read_bytes()),
        'prior_session':'session-20260915T051708Z-1','prior_last_at':'2026-09-15T05:33:18Z',
        'current_session':latest['session'],'new_session':latest['session']!='session-20260915T051708Z-1'},
    'actions':actions})
write('report.json',report)
print(json.dumps({'report_sha256':sha((HERE/'report.json').read_bytes()),'actual':projection['actual'],
    'errors':errors,'versions':report['loaded_versions'],'first':report['first'],'last':report['last'],
    'timing':report['timing'],'run_windows':byrun,'largest_action_intervals':report['largest_action_intervals'][:3],
    'terminal_or_stop_receipts':terminals},indent=2))
