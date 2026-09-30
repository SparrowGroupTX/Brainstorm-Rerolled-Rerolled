"""Capture bounded current public-journal prefixes; never control or score games."""
from pathlib import Path
from datetime import datetime,timezone
from collections import Counter
import hashlib,io,json,sqlite3,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from read_player_log import records,parsed,ArchiveError
from benchmark import file_digest,policy_hashes
SESSION='session-20260927T010446Z-1'
SOURCE=Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2')
def now():return datetime.now(timezone.utc).isoformat()
def save(path,obj):
 with path.open('x',encoding='utf-8') as f:json.dump(obj,f,indent=2,allow_nan=False);f.write('\n')
def processes():
 r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
 return json.loads(r.stdout) if r.stdout.strip() else []
base=json.loads((EVAL/'SESSION_RESET_416.json').read_text())
assert policy_hashes(Path(base['installed']).parent)==base['policy_files']
ps=processes();parent=HERE/'captures';parent.mkdir(exist_ok=True)
number=max([int(p.name) for p in parent.iterdir() if p.is_dir() and p.name.isdecimal()]+[0])+1
out=parent/f'{number:03d}';out.mkdir(exist_ok=False);(out/'logs').mkdir()
paths=sorted(SOURCE.glob(SESSION+'-*.brj'));assert paths,'Target public session absent; do not inspect another session'
sizes={p:p.stat().st_size for p in paths};assert sum(sizes.values())<=1024**3
manifest={'captured_utc':now(),'session':SESSION,'source':str(SOURCE),'processes_before':ps,'segments':[],'scope':'User-authorized passive active-public prefix capture; no game control, save/profile or policy/scorer execution.'}
for p in paths:
 n=sizes[p]
 with p.open('rb') as f:raw=f.read(n)
 assert len(raw)==n,'Source shrank during bounded copy; preserve prior captures and retry only with new evidence'
 target=out/'logs'/p.name;target.write_bytes(raw)
 with p.open('rb') as f:again=f.read(n)
 manifest['segments'].append({'name':p.name,'bytes':n,'sha256':hashlib.sha256(raw).hexdigest(),
  'source_prefix_still_matched':again==raw,'source_size_after':p.stat().st_size})
manifest['processes_after']=processes();save(out/'manifest.json',manifest)
assert all(x['source_prefix_still_matched'] for x in manifest['segments']),'Concurrent source replacement detected'
db=sqlite3.connect(out/'events.sqlite3');db.execute('CREATE TABLE events(seq INTEGER PRIMARY KEY,kind TEXT,run INTEGER,obs TEXT,advice_seq INTEGER,segment TEXT,ordinal INTEGER,raw_sha TEXT,data TEXT,run_instance TEXT)')
tail=None;seq=0;counts=Counter();versions=Counter();starts={};ends={};lifecycle=[];errors=[];segments=[];last_observation=None;last_advice=None
for i,item in enumerate(manifest['segments']):
 raw=(out/'logs'/item['name']).read_bytes();assert hashlib.sha256(raw).hexdigest()==item['sha256']
 stream=io.BytesIO(raw);boundary=0;count=0
 try:
  for ordinal,(body,meta) in enumerate(records(stream),1):
   e=parsed(body);assert meta['session']==SESSION and meta['format']==2
   if tail:assert meta['previous_frame_sha256']==tail['frame_sha256'],'Cross-segment chain mismatch'
   assert e['sequence']==seq+1,'Session sequence discontinuity'
   tail=meta;seq=e['sequence'];boundary=stream.tell();count+=1
   kind=e['kind'];ctx=e.get('context') or {};d=e.get('details') or {};counts[kind]+=1
   if ctx.get('version'):versions[ctx['version']]+=1
   if kind=='teacher_observation':last_observation={'sequence':seq,'at':e.get('at'),'context':ctx}
   if kind=='teacher_advice':last_advice={'sequence':seq,'at':e.get('at'),'advice':ctx.get('advice')}
   if kind=='auto_run':
    ev=d.get('event')
    if ev=='run_started':starts[d['run_id']]={'sequence':seq,'run_instance':ctx.get('run_instance'),'details':d}
    if ev in ('run_finished','run_abandoned'):ends[d['run_id']]={'sequence':seq,'details':d}
    if ev in ('run_started','run_finished','run_abandoned','session_started','session_stopped','search_start_failed'):
     lifecycle.append({'sequence':seq,'at':e.get('at'),'details':{k:v for k,v in d.items() if k not in ('goal','binding','last_action')}})
   db.execute('INSERT INTO events VALUES(?,?,?,?,?,?,?,?,?,?)',(seq,kind,0,e.get('observation_id'),e.get('advice_sequence'),item['name'],ordinal,hashlib.sha256(body).hexdigest(),body.decode(),ctx.get('run_instance')))
 except (ArchiveError,AssertionError) as ex:
  pending=i==len(manifest['segments'])-1 and str(ex) in ('Truncated archive tail','Invalid frame header length')
  errors.append({'segment':item['name'],'error':str(ex),'classification':'incomplete_live_tail' if pending else 'verification_failure','verified_prefix_bytes':boundary,'captured_bytes':len(raw)})
 segments.append({**item,'events':count,'verified_prefix_bytes':boundary})
 if errors:break
for identity,start in starts.items():
 end=ends.get(identity,{}).get('sequence',seq)
 db.execute('UPDATE events SET run=? WHERE run_instance=? AND seq<=?',(start['details']['run_number'],start['run_instance'],end))
db.execute('CREATE INDEX events_kind_run ON events(kind,run,seq)');db.execute('CREATE INDEX events_obs ON events(obs,kind)');db.commit();db.close()
s=(last_observation or {}).get('context',{}).get('snapshot',{})
summary={'created_utc':now(),'session':SESSION,'events':seq,'segments':segments,'errors':errors,'counts':dict(counts),'versions':dict(versions),'starts':list(starts.values()),'endings':list(ends.values()),'unended_run_ids':sorted(set(starts)-set(ends)),
 'lifecycle':lifecycle,'outcomes':dict(Counter(x['details'].get('outcome') for x in ends.values())),
 'last_observation':last_observation,'last_advice':last_advice,'database_sha256':file_digest(out/'events.sqlite3'),
 'runtime_digest':base['policy_digest'],'runtime_unchanged':True,'processes':manifest['processes_after']}
save(out/'summary.json',summary)
latest={'capture':out.relative_to(ROOT).as_posix(),'session':SESSION,'last_sequence':seq,'created_utc':summary['created_utc'],'summary_sha256':file_digest(out/'summary.json'),'capture_mode':'manual_passive','heartbeat_restarted':False}
(HERE/'LATEST.json').write_text(json.dumps(latest,indent=2)+'\n')
print(json.dumps({k:summary[k] for k in ('events','versions','outcomes','unended_run_ids','errors','processes')}))
print(json.dumps({'capture':latest['capture'],'last_phase':s.get('phase'),'last_ante':s.get('ante'),'last_blind':s.get('blind'),'last_action':(last_advice or {}).get('advice',{}).get('action')}))
for l in lifecycle:print(json.dumps(l))
