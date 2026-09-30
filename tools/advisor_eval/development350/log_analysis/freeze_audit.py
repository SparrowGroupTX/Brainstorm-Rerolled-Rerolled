"""Freeze a bounded named passive journal session; no policy or game execution."""
import collections
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
SOURCE=Path(r'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2')
PREFIX='session-20260916T063659Z-1'
paths=sorted(SOURCE.glob(PREFIX+'-*.brj'));assert 1<=len(paths)<=16
lengths={p:p.stat().st_size for p in paths};assert sum(lengths.values())<=48*1024*1024
FROZEN=HERE/'frozen_prefix';FROZEN.mkdir(exist_ok=False)
inputs=[];events=[];errors=[];versions=collections.Counter();counts=collections.Counter()
def card(c,g):
 return {**{k:c.get(k) for k in ('id','key','name','cost','sell_cost','ability','edition','debuff','pinned','blueprint_compat','face_down','identity_redacted')},
   'gold_record':g.get('by_key',{}).get(c.get('key'))}
for p in paths:
 before=p.stat()
 with p.open('rb') as handle:data=handle.read(lengths[p])
 after=p.stat();assert len(data)==lengths[p]
 dest=FROZEN/p.name
 with dest.open('xb') as handle:handle.write(data)
 item={'original_path':str(p),'frozen_path':str(dest),'bytes':len(data),'sha256':sha(data),'append_active':p==paths[-1],
   'stat_unchanged_during_read':(before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns),'original_size_after_read':after.st_size}
 n=0
 try:
  for ordinal,(raw,meta) in enumerate(records(io.BytesIO(data)),1):
   e=json.loads(raw);n+=1;c=e.get('context',{});s=c.get('snapshot',{});g=s.get('completionist_goal',{})
   counts[e.get('kind')]+=1
   if c.get('version'):versions[c['version']]+=1
   d=e.get('details',{});detail={k:v for k,v in d.items() if k not in ('receipt',)}
   if 'receipt' in d:
    rr=d['receipt'];detail['receipt']={k:v for k,v in rr.items() if k not in ('raw_result','request')}
   events.append({'anchor':{'segment':p.name,'ordinal':ordinal,'sequence':e.get('sequence'),'decoded_event_sha256':sha(raw),'stored_frame_sha256':meta.get('frame_sha256')},
     'kind':e.get('kind'),'at':e.get('at'),'version':c.get('version'),'seed':c.get('seed'),'details':detail,
     'state':{k:s.get(k) for k in ('ante','round','phase','state','dollars','chips','blind','hands_left','discards_left','next_blind','next_blind_chips','joker_limit','consumable_limit','consumeable_buffer','reroll_cost','bankrupt_at')},
     'goal':{k:g.get(k) for k in ('counts','eligibility','held_target_count','held_status','metadata_status','catalog_status')},
     'jokers':[card(j,g) for j in s.get('jokers',[])], 'shop_jokers':[card(j,g) for j in s.get('shop_jokers',[])],
     'pack_cards':[card(j,g) for j in s.get('pack_cards',[])],
     'shop_booster':[card(j,g) for j in s.get('shop_booster',[])],
     'shop_vouchers':[card(j,g) for j in s.get('shop_vouchers',[])],
     'consumeables':[card(j,g) for j in s.get('consumeables',[])],
     'hands':{k:{kk:vv.get(kk) for kk in ('level','chips','mult','played')} for k,vv in s.get('hands',{}).items()},
     'advice':c.get('advice')})
 except Exception as exc:errors.append({'segment':p.name,'completed_records':n,'error':str(exc)})
 item['event_count']=n;inputs.append(item)
out=HERE/'passive_audit.json'
report={'schema':1,'scope':'Read-only named passive journal prefix capture and static analysis only; no policy evaluations, replay, source/native workers, searches, simulations, save/profile/executable reads or game control.',
 'prefix':PREFIX,'inputs':inputs,'loaded_versions':dict(versions),'event_counts':dict(counts),'decode_errors':errors,
 'hash_semantics':'Hashes bind frozen byte prefixes; append-active original may grow later. Original files remain untouched.',
 'last_sequence':events[-1]['anchor']['sequence'],'last_at':events[-1]['at'],'events':events}
with out.open('x',encoding='utf-8') as handle:json.dump(report,handle,indent=2);handle.write('\n')
terminal=[e for e in events if e['details'].get('event')=='run_finished']
print(json.dumps({'path':str(out),'sha256':sha(out.read_bytes()),'input_bytes':sum(i['bytes'] for i in inputs),'event_count':len(events),
 'loaded_versions':dict(versions),'decode_errors':errors,'last_sequence':report['last_sequence'],'last_at':report['last_at'],
 'terminals':[{k:e[k] for k in ('anchor','at','version','seed','details','state','jokers')} for e in terminal]}))
