"""Passive bounded archive capture and compact public trajectory index. No scorer."""
from pathlib import Path
from datetime import datetime, timezone
from collections import Counter
import sys, json, hashlib, io
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
sys.path.insert(0,str(ROOT))
from tools.advisor_eval.read_player_log import records, parsed
from tools.advisor_learning.teacher_demonstrations import TeacherConverter
SOURCE=Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2')
PREFIX='session-20260923T044625Z-1'
OUT=HERE/'capture';OUT.mkdir(exist_ok=False);(OUT/'frozen').mkdir()
paths=sorted(SOURCE.glob(PREFIX+'-*.brj'));sizes={p:p.stat().st_size for p in paths}
assert 1<=len(paths)<=64 and sum(sizes.values())<=128*1024*1024
def sha(b):return hashlib.sha256(b).hexdigest()
def dump(name,x):(OUT/name).write_text(json.dumps(x,indent=2,allow_nan=False)+'\n',encoding='utf-8')
def cards(cs):
 return [{k:c.get(k) for k in ('id','key','rank','suit','enhancement','seal','debuff','ability','edition','cost','sell_cost','face_down','identity_redacted')} for c in cs or []]
def state(s):
 out={k:s.get(k) for k in ('phase','ante','round','deck_key','stake','chips','dollars','bankrupt_at','hands_left','discards_left','hands_played','discards_used','blind','next_blind','route_blinds','teacher_profile','joker_limit','consumable_limit','used_vouchers','consumeable_usage','reroll_cost','current_round','normal_opening','opening_pack','blind_choices','skip_tags','route_tags')}
 for key in ('jokers','consumeables','hand','shop_jokers','shop_booster','shop_vouchers','pack_cards'):out[key]=cards(s.get(key))
 out['hands']=s.get('hands');out['collection_progress_present']='collection_progress' in s
 out['completionist_goal_present']='completionist_goal' in s
 out['population_size']=len(s.get('playing_cards')or[])
 out['public_rank_counts']=dict(Counter(str(c.get('rank')) for c in s.get('playing_cards')or[] if not (c.get('identity_redacted')or c.get('face_down'))))
 return out
manifest=[];errors=[];counts=Counter();versions=Counter();profiles=Counter();lifecycle=[]
converter=TeacherConverter();conversion_error=None;decoded=0;last=0;first_at=None;gaps=[]
with (OUT/'events.jsonl').open('w',encoding='utf-8')as out:
 for path in paths:
  before=path.stat()
  with path.open('rb')as f:data=f.read(sizes[path])
  after=path.stat();assert len(data)==sizes[path]
  (OUT/'frozen'/path.name).write_bytes(data)
  item={'source':str(path),'frozen':str((OUT/'frozen'/path.name).relative_to(ROOT)),'bytes':len(data),'sha256':sha(data),'stable':(before.st_size,before.st_mtime_ns)==(after.st_size,after.st_mtime_ns),'records':0}
  try:
   for ordinal,(raw,meta)in enumerate(records(io.BytesIO(data)),1):
    decoded+=len(raw);assert decoded<=3*1024**3 and last<100000
    e=parsed(raw);seq=e['sequence'];item['records']+=1
    if seq!=last+1:gaps.append([last,seq])
    last=seq;first_at=first_at or e.get('at');last_at=e.get('at')
    if conversion_error is None:
     try:converter.accept(e)
     except Exception as ex:conversion_error={'sequence':seq,'error':str(ex)}
    c=e.get('context')or{};d=e.get('details')or{};s=c.get('snapshot');kind=e['kind']
    counts[kind]+=1
    if c.get('version'):versions[c['version']]+=1
    if s:profiles[str(s.get('teacher_profile'))]+=1
    row={k:e.get(k) for k in ('sequence','kind','at','monotonic_seconds','observation_id','advice_sequence','collection_id')}
    row.update({'seed':c.get('seed'),'run_instance':c.get('run_instance'),'teacher':c.get('teacher'),
      'anchor':{'segment':path.name,'ordinal':ordinal,'raw_sha256':sha(raw)},'details':d})
    if s:row['state']=state(s)
    if c.get('advice'):row['advice']=c['advice']
    if c.get('advice_timing'):row['advice_timing']=c['advice_timing']
    out.write(json.dumps(row,allow_nan=False)+'\n')
    if kind=='auto_run' and d.get('event')in ('explicit_start_requested','session_started','run_started','run_finished','run_abandoned','session_stopped','manual_continuation','session_resumed'):lifecycle.append(row)
  except Exception as ex:errors.append({'segment':path.name,'error':str(ex),'last_sequence':last})
  manifest.append(item)
dump('manifest.json',{'captured_utc':datetime.now(timezone.utc).isoformat(),'inputs':manifest,'input_bytes':sum(sizes.values()),'decoded_bytes':decoded,'first_at':first_at,'last_at':last_at,'last_sequence':last,'gaps':gaps,'errors':errors,'scope':'Frozen public prefixes only. No game/save/profile/policy/scorer execution.'})
dump('summary.json',{'kinds':dict(counts),'versions':dict(versions),'snapshot_profiles':dict(profiles),'converter_error':conversion_error,'converter':converter.summary(),'lifecycle':lifecycle})
print(json.dumps({'records':sum(counts.values()),'input_bytes':sum(sizes.values()),'decoded_bytes':decoded,'first_at':first_at,'last_at':last_at,'versions':dict(versions),'profiles':dict(profiles),'errors':errors,'converter_error':conversion_error,'converter':converter.summary()}))
print(json.dumps([{'sequence':e['sequence'],'seed':e['seed'],'event':e['details'].get('event'),'run':e['details'].get('run_number'),'outcome':e['details'].get('outcome'),'reason':e['details'].get('reason')}for e in lifecycle if e['details'].get('event')not in ('session_started','explicit_start_requested')]))

