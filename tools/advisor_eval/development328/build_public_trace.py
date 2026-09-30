"""One-use public-only postmortem index; never score states or expose internal keys."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
EVAL = ROOT / 'tools/advisor_eval'
sys.path.insert(0, str(EVAL))
from read_player_log import records, parsed

OUT = Path(__file__).parent / 'public_trace'
OUT.mkdir(exist_ok=False)
(OUT / 'snapshots').mkdir()
caps = dict(files=8, stored_bytes=67108864, decoded_bytes=536870912,
            events=2000, output_bytes=67108864, seconds=55)
plan = dict(authorization='User: Fix the losses. Passive analysis of preserved observations plus implementation; no simulation authority inferred.',
            scope='Only redacted context.snapshot, public advice, and action/time metadata. Raw internal fingerprint strings are never decoded into state or exported.',
            caps=caps, at_utc=datetime.now(timezone.utc).isoformat())
(OUT / 'plan.json').write_text(json.dumps(plan, indent=2)+'\n', encoding='utf-8')


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def details_public(value):
    # Only the known identity fields were raw internal snapshots. Keep an
    # opaque equality receipt, never their contents, including checkpoint data.
    if isinstance(value, dict):
        return {k: ({'internal_text_omitted': True, 'sha256': sha(v.encode('utf-8')),
                     'byte_length': len(v.encode('utf-8'))}
                    if k in ('fingerprint', 'before', 'after') and isinstance(v, str)
                    else details_public(v)) for k, v in value.items()}
    if isinstance(value, list):
        return [details_public(v) for v in value]
    return value


def card(c):
    return {k:c[k] for k in ('id','key','name','rank','suit','enhancement','edition','seal',
            'face_down','debuff','ability','sell_cost','cost','copy_source') if k in c}


start=time.monotonic()
capture=json.loads((EVAL/'development327/capture.json').read_text())
assert len(capture['files']) <= caps['files']
counts=dict(files=0, stored_bytes=0, decoded_bytes=0, events=0, output_bytes=0, snapshots=0)
traces={3:[],4:[],5:[]}
bounds={3:(2638,2758),4:(2767,3388),5:(3397,4392)}
seen=set()
for item in capture['files']:
    path=Path(item['captured_path'])
    path.resolve().relative_to((EVAL/'development327/captured_logs').resolve())
    raw=path.read_bytes()
    assert sha(raw)==item['sha256']
    counts['files']+=1;counts['stored_bytes']+=len(raw)
    assert counts['stored_bytes']<=caps['stored_bytes']
    with path.open('rb') as stream:
        for ordinal,(event_raw,meta) in enumerate(records(stream),1):
            counts['events']+=1;counts['decoded_bytes']+=len(event_raw)
            assert counts['events']<=caps['events'] and counts['decoded_bytes']<=caps['decoded_bytes']
            assert time.monotonic()-start<=caps['seconds']
            event=parsed(event_raw)
            n=event['sequence']
            run=next((run for run,(first,last) in bounds.items() if first<=n<=last),None)
            if run is None or event.get('kind')!='auto_run':continue
            detail=event.get('details',{})
            if detail.get('event') not in ('run_started','action_attempt','action_observed','run_finished'):continue
            context=event.get('context',{})
            snapshot=context.get('snapshot')
            ref=None;summary=None
            if isinstance(snapshot,dict):
                state_raw=encoded(snapshot)+b'\n';key=sha(state_raw)
                ref='snapshots/'+key+'.json'
                if key not in seen:
                    counts['output_bytes']+=len(state_raw)
                    assert counts['output_bytes']<=caps['output_bytes']
                    (OUT/ref).write_bytes(state_raw);seen.add(key);counts['snapshots']+=1
                summary={k:snapshot.get(k) for k in ('phase','ante','round','chips','dollars',
                    'hands_left','discards_left','hand_size','joker_limit','consumable_limit',
                    'blind','next_blind','blind_on_deck','hands','pack_type','pack_choices')}
                for key in ('jokers','consumeables','hand','shop_jokers','shop_booster','shop_vouchers','pack_cards'):
                    summary[key]=[card(c) for c in snapshot.get(key,[]) if isinstance(c,dict)]
            traces[run].append(dict(sequence=n,ordinal=ordinal,file=path.name,event_sha256=sha(event_raw),
                kind=detail.get('event'),at=event.get('at'),monotonic_seconds=event.get('monotonic_seconds'),
                snapshot=ref,state=summary,advice=context.get('advice'),details=details_public(detail),
                seed=context.get('seed'),game_over=context.get('game_over'),won_field=context.get('won_field')))
for run,trace in traces.items():
    raw=encoded(dict(run_number=run,scope=plan['scope'],events=trace))+b'\n'
    counts['output_bytes']+=len(raw)
    assert counts['output_bytes']<=caps['output_bytes']
    (OUT/('run'+str(run)+'.json')).write_bytes(raw)
receipt=dict(status='complete',counts=counts,seconds=time.monotonic()-start,
    runs={run:len(trace) for run,trace in traces.items()},
    files={p.relative_to(OUT).as_posix():sha(p.read_bytes()) for p in OUT.rglob('*.json')})
assert receipt['seconds']<=caps['seconds']
(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:receipt[k] for k in ('status','counts','seconds','runs')}))
