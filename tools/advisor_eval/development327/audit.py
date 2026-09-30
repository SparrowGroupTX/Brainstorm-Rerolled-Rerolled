"""Bounded analysis of already-captured public observations; compact output only."""
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import io
import json
import statistics
import sys
import time
import zlib

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import read_player_log as reader
from analyze_player_timing import validate_window

CAPS = {'files': 8, 'physical_bytes': 64*1024*1024, 'decoded_bytes': 512*1024*1024,
        'events': 12000, 'seconds': 55, 'examples': 12}


def write(name, value):
    with (HERE / name).open('x', encoding='utf-8') as f:
        json.dump(value, f, indent=2, allow_nan=False)
        f.write('\n')


def digest(raw):return hashlib.sha256(raw).hexdigest()
def size(v):return len(json.dumps(v, ensure_ascii=False, separators=(',', ':')).encode())
def brief(v):
    if isinstance(v, str) and len(v) > 500:return {'characters':len(v), 'sha256_utf8':digest(v.encode())}
    if isinstance(v, dict):return {k:brief(x) for k,x in v.items()}
    if isinstance(v, list):return [brief(x) for x in v[:32]] + ([{'omitted':len(v)-32}] if len(v)>32 else [])
    return v
def stats(values):
    ordered=sorted(values)
    return {'count':len(values), 'sum':sum(values), 'median':statistics.median(values) if values else None,
            'p95_order_statistic':ordered[min(len(ordered)-1, int(.95*len(ordered)))] if values else None,
            'max':max(values) if values else None}


capture=json.loads((HERE/'capture.json').read_text())
write('analysis_plan.json', {'scope':'Offline analysis of exact captured log bytes only; no game/source experiment or rescoring.',
                            'caps':CAPS, 'capture_sha256':digest((HERE/'capture.json').read_bytes())})
started=time.monotonic();events=[];errors=[];kind_counts=Counter();auto_counts=Counter();versions=Counter()
field_bytes=Counter();metric_totals={};windows=[];decision_status=Counter();decisions=[];slow=[]
totals={'physical_bytes':0,'decoded_bytes':0,'wire_frame_bytes':0,'snapshot_events':0,
        'snapshot_full_frames':0,'snapshot_reference_frames':0,'snapshot_exact_bytes':0,
        'snapshot_full_payload_bytes':0,'direct_frames':0}
changed=[];last_seq=None;last_frame=None;loaded=set();field_repeats=defaultdict(lambda:Counter())
for item in capture['files']:
    if len(loaded)>=CAPS['files'] or totals['physical_bytes']+item['bytes']>CAPS['physical_bytes']:break
    path=Path(item['captured_path']);data=path.read_bytes();assert digest(data)==item['sha256']
    loaded.add(path.name);totals['physical_bytes']+=len(data)
    stream=io.BytesIO(data);iterator=reader.records(stream);previous_snapshot=None
    while stream.tell()<len(data):
        if len(events)>=CAPS['events'] or totals['decoded_bytes']+reader.MAX_EVENT>CAPS['decoded_bytes'] or time.monotonic()-started>=CAPS['seconds']:
            errors.append({'kind':'analysis_cap','file':path.name,'offset':stream.tell()});break
        offset=stream.tell()
        try:raw,meta=next(iterator)
        except (reader.ArchiveError, StopIteration) as error:
            errors.append({'kind':'decode_or_partial_tail','file':path.name,'offset':offset,'reason':str(error)});break
        if last_seq is not None and (meta['sequence']!=last_seq+1 or meta['previous_frame_sha256']!=last_frame):
            errors.append({'kind':'cross_segment_chain_gap','file':path.name,'sequence':meta['sequence']});break
        last_seq,last_frame=meta['sequence'],meta['frame_sha256']
        end=stream.tell();event=reader.parsed(raw);kind=event.get('kind');context=event.get('context') or {};details=event.get('details') or {}
        snapshot=context.get('snapshot') or {};advice=context.get('advice') or {}
        kind_counts[kind]+=1
        if kind=='auto_run':auto_counts[details.get('event')]+=1
        if context.get('version'):versions[context['version']]+=1
        totals['decoded_bytes']+=len(raw);totals['wire_frame_bytes']+=end-offset
        # The decoder has already validated every length, hash and zlib bound.
        header,wire=data[offset:end].split(b'\n',1);fields=header.split(b'\t')
        bodyraw=wire[:-1] if fields[1]==b'raw' else zlib.decompress(wire[:-1])
        body=reader.parsed(bodyraw)
        if 'event_json' in body:totals['direct_frames']+=1
        else:
            totals['snapshot_events']+=1
            if 'snapshot_json' in body:
                current=reader.text(body['snapshot_json']);totals['snapshot_full_frames']+=1
                totals['snapshot_full_payload_bytes']+=len(current)
                if previous_snapshot is not None:
                    prefix=0;maximum=min(len(current),len(previous_snapshot))
                    while prefix<maximum and current[prefix]==previous_snapshot[prefix]:prefix+=1
                    suffix=0
                    while suffix<maximum-prefix and current[-1-suffix]==previous_snapshot[-1-suffix]:suffix+=1
                    changed.append({'current_bytes':len(current),'retained_bytes':prefix+suffix,
                                    'retained_fraction':(prefix+suffix)/len(current) if current else 0,
                                    'middle_bytes':len(current)-prefix-suffix})
                previous_snapshot=current
            else:totals['snapshot_reference_frames']+=1
            totals['snapshot_exact_bytes']+=len(previous_snapshot or b'')
        for prefix, obj in (('context',context),('details',details)):
            if isinstance(obj,dict):
                for key,value in obj.items():
                    field=prefix+'.'+key;field_bytes[field]+=size(value)
                    if isinstance(value,str) and len(value)>1000:
                        field_repeats[field][digest(value.encode())]+=1
        state={key:snapshot.get(key) for key in ('phase','ante','round','chips','dollars','hands_left','discards_left')}
        state['blind']={k:(snapshot.get('blind') or {}).get(k) for k in ('name','key','chips','boss')}
        row={'file':path.name,'offset':offset,'end':end,'sequence':event['sequence'],'kind':kind,'at':event.get('at'),
             'monotonic_seconds':event.get('monotonic_seconds'),'event_sha256':digest(raw),'event_bytes':len(raw),'wire_bytes':end-offset,
             'seed':context.get('seed'),'game_over':context.get('game_over'),'won_field':context.get('won_field'),
             'state':state if snapshot else None,'advice':brief(advice),'details':brief(details)}
        # Rich timing metrics live in a separate bounded aggregate, not repeated in projections.
        if kind=='performance_window':
            row['details']={'window_id':details.get('window_id')}
            try:
                w,frames,ds=validate_window(event);windows.append({'sequence':event['sequence'],
                  'start':w['start_seconds'],'end':w['end_seconds'],'dropped_slow':w['slow_frames_dropped'],
                  'dropped_decisions':w['decisions_dropped'],'flags':w.get('flags')})
                for name,m in w['metrics'].items():
                    total=metric_totals.setdefault(name,{'count':0,'total_seconds':0,'max_seconds':0})
                    total['count']+=m['count'];total['total_seconds']+=m['total_seconds'];total['max_seconds']=max(total['max_seconds'],m['max_seconds'])
                for d in ds:decisions.append({**d,'sequence':event['sequence']});decision_status[d['status']]+=1
                slow.extend({**f,'sequence':event['sequence']} for f in frames)
            except Exception as error:errors.append({'kind':'invalid_timing_window','sequence':event['sequence'],'reason':str(error)})
        events.append(row)
    if errors and errors[-1]['kind']!='invalid_timing_window':break

byseq={e['sequence']:e for e in events}
observed={e['details'].get('action_token'):e for e in events if e['kind']=='auto_run' and e['details'].get('event')=='action_observed'}
actions=[]
for e in events:
    if e['kind']!='auto_run' or e['details'].get('event')!='action_attempt':continue
    follow=observed.get(e['details'].get('action_token'));elapsed=None
    if follow and follow['sequence']>e['sequence']:
        a,b=e['details'].get('time'),follow['details'].get('time')
        if isinstance(a,(int,float)) and isinstance(b,(int,float)) and b>=a:elapsed=b-a
    actions.append({'sequence':e['sequence'],'kind':(e['details'].get('action') or {}).get('kind'),
                    'seconds_to_fresh_advice':elapsed,'state':e['state'],'seed':e['seed']})
terminals=[e for e in events if e['kind']=='auto_run' and e['details'].get('event') in ('run_finished','session_stopped','collection_complete')]
report={'caps':CAPS,'actual':{**totals,'events':len(events),'files':len(loaded),'seconds':time.monotonic()-started},
        'errors':errors,'versions_declared':dict(versions),'first':{k:events[0][k] for k in ('file','sequence','at','state')} if events else None,
        'last':{k:events[-1][k] for k in ('file','sequence','at','state')} if events else None,
        'kind_counts':dict(kind_counts),'auto_event_counts':dict(auto_counts),'canonical_field_bytes':field_bytes.most_common(18),
        'large_string_repeats':{k:{'occurrences':sum(v.values()),'unique':len(v),'repeated_occurrences':sum(v.values())-len(v)} for k,v in field_repeats.items()},
        'changed_snapshot_splice':{'retained_fraction':stats([v['retained_fraction'] for v in changed]),
                                   'middle_bytes':stats([v['middle_bytes'] for v in changed])},
        'timing_windows':len(windows),'timing_metrics':metric_totals,'decision_status_counts':dict(decision_status),
        'largest_decisions':sorted(decisions,key=lambda d:d['elapsed_seconds'],reverse=True)[:CAPS['examples']],
        'largest_slow_frames':sorted(slow,key=lambda d:max(d.get('update_seconds',0),d.get('frame_interval_seconds',0)),reverse=True)[:CAPS['examples']],
        'action_intervals':stats([a['seconds_to_fresh_advice'] for a in actions if a['seconds_to_fresh_advice'] is not None]),
        'largest_actions':sorted([a for a in actions if a['seconds_to_fresh_advice'] is not None],key=lambda a:a['seconds_to_fresh_advice'],reverse=True)[:CAPS['examples']],
        'terminal_or_stop_receipts':terminals,
        'limits':['Selected captured suffix only; prior session prefix and first predecessor unverified.',
                  'Version strings do not attest loaded module hashes. No rescoring or alternative action simulation.',
                  'Metrics are elapsed wall time and overlap; no CPU percent or unmeasured terminal result inferred.',
                  'Canonical field-byte accounting is explanatory, not an exact decomposition of original encoded bytes.']}
write('events_index.json', {'events':events,'actions':actions,'windows':windows})
write('audit.json',report)
print(json.dumps({k:report[k] for k in ('actual','errors','versions_declared','kind_counts','auto_event_counts',
      'canonical_field_bytes','large_string_repeats','changed_snapshot_splice','timing_windows','decision_status_counts','action_intervals')},indent=2))
