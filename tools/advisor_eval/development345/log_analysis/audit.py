"""Passive journal audit only: no policy execution or game access."""
import collections
import hashlib
import io
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
from read_player_log import records
SOURCE = Path(r'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2')
OUT = Path(__file__).parent

def sha(x): return hashlib.sha256(x).hexdigest()
def cards(xs,g):
    result=[]
    for c in xs:
        r={k:c[k] for k in ('id','key','name','cost','sell_cost','base_cost','edition','debuff','pinned','face_down','ability','base','tarot_hold_source','blueprint_compat') if k in c}
        r['gold_status']=g.get('by_key',{}).get(c.get('key'),{}).get('status')
        result.append(r)
    return result
def brief(e,a):
    c=e.get('context',{});s=c.get('snapshot',{});g=s.get('completionist_goal',{})
    return {'anchor':a,'kind':e.get('kind'),'at':e.get('at'),'monotonic_seconds':e.get('monotonic_seconds'),
      'details':e.get('details'),'version':c.get('version'),'seed':c.get('seed'),
      'state':{k:s.get(k) for k in ('ante','round','phase','state','dollars','chips','blind','hands_left','discards_left','reroll_cost','next_blind','next_blind_chips','win_ante','bankrupt_at','joker_limit','consumable_limit','consumeable_buffer','ordering_safe','jokers_shuffling')},
      'goal':{k:v for k,v in g.items() if k not in ('by_key','records','missing_keys','complete_keys','unknown_keys','held')},
      'jokers':cards(s.get('jokers',[]),g),'shop_jokers':cards(s.get('shop_jokers',[]),g),
      'consumeables':cards(s.get('consumeables',[]),g),'advice':c.get('advice')}

paths=sorted(SOURCE.glob('session-20260916T042025Z-1-*.brj'))
inputs=[];events=[];counts=collections.Counter();failures=[];versions=collections.Counter();last=None
for p in paths:
    st=p.stat();data=p.read_bytes();st2=p.stat();n=0
    item={'path':str(p),'bytes':len(data),'input_sha256':sha(data),'stat_unchanged_during_read':(st.st_size,st.st_mtime_ns)==(st2.st_size,st2.st_mtime_ns),'append_active':p==paths[-1]}
    try:
        for ordinal,(raw,m) in enumerate(records(io.BytesIO(data)),1):
            e=json.loads(raw);n+=1;counts[e.get('kind')]+=1;last=e.get('sequence');c=e.get('context',{});s=c.get('snapshot',{});d=e.get('details',{})
            if c.get('version'): versions[c['version']]+=1
            a={'segment':p.name,'ordinal':ordinal,'sequence':e.get('sequence'),'decoded_event_sha256':sha(raw),'stored_frame_sha256':m.get('frame_sha256')}
            if e.get('kind') in ('action_requested','collection_run_start','collection_run_end') or d.get('event') in ('run_started','run_finished','run_terminal','terminal_overlay_close_requested','session_stopped') or d.get('outcome') is not None or s.get('phase')=='shop' and s.get('ante')==8 and (c.get('advice') or {}).get('gold_review'):
                events.append(brief(e,a))
    except Exception as error: failures.append({'path':str(p),'after_complete_records':n,'error':str(error)})
    item['event_count']=n;inputs.append(item)
report={'schema':1,'scope':'Passive public journal decode only; no policy replay, simulation, original-source execution, saves/profile access, search or game control.',
  'hash_semantics':{'input_sha256':'Exact observed bytes, not a permanent append-active file hash.','stored_frame_sha256':'BRJ2 frame header, stored payload and newline.','decoded_event_sha256':'Exact reconstructed original JSONL event bytes including newline.'},
  'inputs':inputs,'event_counts':dict(counts),'loaded_versions':dict(versions),'last_sequence':last,'decode_errors':failures,'events':events}
path=OUT/'passive_audit.json'
with path.open('x',encoding='utf-8') as f: json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'path':str(path),'sha256':sha(path.read_bytes()),'events':len(events),'failures':failures,'loaded_versions':dict(versions),'last_sequence':last}))
