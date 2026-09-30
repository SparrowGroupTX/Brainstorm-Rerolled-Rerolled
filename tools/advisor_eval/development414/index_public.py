"""Index immutable copied public journals. No policy/scorer/game imports."""
from pathlib import Path
from collections import Counter
import hashlib, io, json, sqlite3, sys
from datetime import datetime, timezone

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT))
from tools.advisor_eval.read_player_log import records, parsed

manifest=json.loads((HERE/'capture/manifest.json').read_text())
dbpath=HERE/'events.sqlite3'
assert not dbpath.exists()
db=sqlite3.connect(dbpath)
db.execute('CREATE TABLE events(seq INTEGER PRIMARY KEY,kind TEXT,run INTEGER,obs TEXT,advice_seq INTEGER,segment TEXT,ordinal INTEGER,raw_sha TEXT,data TEXT,run_instance TEXT)')
sequence=0;run=0;kinds=Counter();versions=Counter();profiles=Counter()
starts={};endings={};lifecycle=[];segments=[];failures=[];tail=None
for item in manifest['segments']:
    data=(HERE/'logs1'/item['name']).read_bytes()
    assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256']
    count=0;first=sequence+1
    try:
        for ordinal,(raw,meta) in enumerate(records(io.BytesIO(data)),1):
            e=parsed(raw)
            assert meta.get('format')==2 and meta['session']==manifest['session']
            if tail:
                assert meta['previous_frame_sha256']==tail['frame_sha256']
                assert meta['segment']>=tail['segment']
            tail=meta
            assert e['sequence']==sequence+1,(item['name'],sequence,e['sequence'])
            sequence=e['sequence'];count+=1
            kind=e['kind'];ctx=e.get('context') or {};d=e.get('details') or {}
            anchor={'sequence':sequence,'segment':item['name'],'ordinal':ordinal,'raw_sha256':hashlib.sha256(raw).hexdigest()}
            if kind=='auto_run':
                ev=d.get('event')
                if ev=='run_started':
                    run=d['run_number'];identity=d['run_id']
                    assert identity not in starts
                    starts[identity]={'anchor':anchor,'details':d,'public_run_instance':ctx.get('run_instance')}
                if ev in ('run_finished','run_abandoned'):
                    identity=d.get('run_id')
                    assert identity in starts and identity not in endings,(ev,identity)
                    endings[identity]={'anchor':anchor,'details':d}
                if ev in ('session_started','run_started','run_finished','run_abandoned','session_stopped','search_start_failed'):
                    lifecycle.append({'anchor':anchor,'details':d})
            kinds[kind]+=1
            if ctx.get('version'): versions[ctx['version']]+=1
            snap=ctx.get('snapshot') or {}
            if kind=='teacher_observation' and snap.get('teacher_profile'): profiles[snap['teacher_profile']]+=1
            db.execute('INSERT INTO events VALUES(?,?,?,?,?,?,?,?,?,?)',(sequence,kind,run,e.get('observation_id'),e.get('advice_sequence'),item['name'],ordinal,anchor['raw_sha256'],raw.decode('utf-8'),ctx.get('run_instance')))
    except Exception as ex:
        failures.append({'segment':item['name'],'last_good_sequence':sequence,'error':repr(ex)})
        break
    segments.append({**item,'events':count,'first_sequence':first,'last_sequence':sequence})
db.execute('UPDATE events SET run=0')
for identity,start in starts.items():
    number=start['details']['run_number'];end=endings.get(identity,{}).get('anchor',{}).get('sequence',sequence)
    assert start['public_run_instance']
    db.execute('UPDATE events SET run=? WHERE run_instance=? AND seq<=?',(number,start['public_run_instance'],end))
db.execute('CREATE INDEX events_kind_run ON events(kind,run,seq)')
db.execute('CREATE INDEX events_obs ON events(obs,kind)')
db.commit();db.close()
summary={'verified_utc':datetime.now(timezone.utc).isoformat(),'session':manifest['session'],'segments':segments,'events':sequence,'failures':failures,'kinds':dict(kinds),'versions':dict(versions),'profiles':dict(profiles),'starts':list(starts.values()),'endings':list(endings.values()),'unended_run_ids':sorted(set(starts)-set(endings)),'lifecycle':lifecycle,'outcomes':dict(Counter(x['details'].get('outcome') for x in endings.values())),'database_sha256':hashlib.sha256(dbpath.read_bytes()).hexdigest(),'indexer_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
with (HERE/'capture/verification.json').open('x') as out: json.dump(summary,out,indent=2,allow_nan=False)
print(json.dumps({k:summary[k] for k in ('events','failures','versions','profiles','outcomes','unended_run_ids','kinds')}))
for x in lifecycle: print(json.dumps({'sequence':x['anchor']['sequence'],**x['details']}))
assert not failures
