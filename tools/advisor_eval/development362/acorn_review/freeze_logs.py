"""Bounded passive prefix capture; no gameplay, policy evaluation or save access."""
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
import hashlib, io, json, sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT))
from tools.advisor_eval.read_player_log import records, parsed
from tools.advisor_learning.teacher_demonstrations import TeacherConverter

SOURCE=Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2')
PREFIX='session-20260922T172657Z-1'
paths=sorted(SOURCE.glob(PREFIX+'-*.brj'))
assert 1<=len(paths)<=32
sizes={p:p.stat().st_size for p in paths}
assert sum(sizes.values())<=64*1024*1024
label=sys.argv[1] if len(sys.argv)>1 else 'logs1'
assert label in ('logs1','logs2')
OUT=HERE/label
OUT.mkdir(exist_ok=False)
(OUT/'frozen').mkdir()
def sha(x):return hashlib.sha256(x).hexdigest()
def write(name,x):(OUT/name).write_text(json.dumps(x,indent=2,allow_nan=False)+'\n',encoding='utf-8')
def cards(value):
    return [{k:c.get(k) for k in ('id','key','rank','suit','enhancement','seal','debuff','ability','edition','cost','sell_cost','blueprint_compat','face_down','identity_redacted')} for c in value or []]
def compact(s):
    q={k:s.get(k) for k in ('phase','ante','round','deck_key','stake','chips','dollars','hands_left','discards_left','hands_played','discards_used','blind','next_blind','route_blinds','teacher_profile','joker_limit','consumable_limit','reroll_cost')}
    for a in ('jokers','consumeables','shop_jokers','shop_booster','shop_vouchers','pack_cards','hand'):q[a]=cards(s.get(a))
    q['hands']={k:{f:v.get(f) for f in ('level','chips','mult','played')} for k,v in (s.get('hands')or{}).items()}
    q['population']=dict(Counter(str(c.get('rank')) for c in s.get('playing_cards',[]) or []))
    q['collection_counts']=(s.get('collection_progress')or s.get('completionist_goal')or{}).get('counts')
    return q

manifest=[];events=[];observations={};counts=Counter();versions=Counter();errors=[]
converter=TeacherConverter();conversion_error=None;decoded=0
for path in paths:
    before=path.stat()
    with path.open('rb')as f:data=f.read(sizes[path])
    after=path.stat();assert len(data)==sizes[path]
    dest=OUT/'frozen'/path.name;dest.write_bytes(data)
    item={'path':str(path),'frozen':str(dest.relative_to(ROOT)),'bytes':len(data),'sha256':sha(data),
          'stable_during_read':(before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns),
          'size_after_read':after.st_size,'completed_records':0}
    try:
        for ordinal,(raw,meta)in enumerate(records(io.BytesIO(data)),1):
            decoded+=len(raw);assert decoded<=512*1024*1024 and len(events)<25000
            e=parsed(raw);item['completed_records']+=1
            if conversion_error is None:
                try:converter.accept(e)
                except Exception as ex:conversion_error={'sequence':e.get('sequence'),'error':str(ex)}
            c=e.get('context')or{};d=e.get('details')or{};s=c.get('snapshot')or{}
            if c.get('version'):versions[c['version']]+=1
            counts[e['kind']]+=1
            oid=e.get('observation_id')
            if s:observations[oid]={'seed':c.get('seed'),'run_instance':c.get('run_instance'),'state':compact(s)}
            linked=observations.get(oid,{})
            event={'sequence':e['sequence'],'kind':e['kind'],'at':e.get('at'),'monotonic_seconds':e.get('monotonic_seconds'),
                   'observation_id':oid,'advice_sequence':e.get('advice_sequence'),
                   'seed':c.get('seed')or linked.get('seed'),'run_instance':c.get('run_instance')or linked.get('run_instance'),
                   'anchor':{'segment':path.name,'ordinal':ordinal,'raw_sha256':sha(raw)},
                   'details':d,'advice':c.get('advice')}
            if s:event['state']=compact(s)
            events.append(event)
    except Exception as ex:errors.append({'segment':path.name,'completed_records':item['completed_records'],'error':str(ex)})
    manifest.append(item)
write('manifest.json',{'schema':1,'captured_utc':datetime.now(timezone.utc).isoformat(),'scope':'Passive frozen public-log prefixes only. Originals unchanged. No experiments or game/save/profile control.',
    'inputs':manifest,'decode_errors':errors,'decoded_bytes':decoded,'last_sequence':events[-1]['sequence']})
write('events.json',events);write('observations.json',observations)
terminals=[e for e in events if e['kind']=='auto_run'and e['details'].get('event')in('run_finished','run_abandoned','session_stopped','run_started','run_launch_accepted')]
summary={'event_count':len(events),'input_bytes':sum(sizes.values()),'decoded_bytes':decoded,'versions':dict(versions),'kinds':dict(counts),
    'last_at':events[-1]['at'],'last_sequence':events[-1]['sequence'],'decode_errors':errors,
    'converter_error':conversion_error,'converter':converter.summary(),'lifecycle':terminals}
write('summary.json',summary)
print(json.dumps({k:v for k,v in summary.items()if k!='lifecycle'}))
print(json.dumps([{k:e[k]for k in ('sequence','at','seed','details')}for e in terminals]))
