"""Read-only, bounded passive journal index for the zero-sticker win report."""
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
def cards(xs, goal=None):
    return [{**{k:c[k] for k in ('key','name','cost','sell_cost','edition','debuff') if k in c},
             'ability': {k:c.get('ability',{}).get(k) for k in ('eternal','perishable','rental') if k in c.get('ability',{})},
             **({'gold_status':goal.get('by_key',{}).get(c.get('key'),{}).get('status')} if goal else {})}
            for c in xs if isinstance(c,dict)]
def goal_summary(g):
    return {k:v for k,v in g.items() if k not in ('by_key','records','missing_keys','complete_keys','unknown_keys','held')}
def brief(e,a):
    c=e.get('context',{});s=c.get('snapshot',{});g=s.get('completionist_goal',{});d=e.get('details',{})
    return dict(anchor=a, kind=e.get('kind'), at=e.get('at'), monotonic_seconds=e.get('monotonic_seconds'),
                event=d.get('event'), details=d, version=c.get('version'),seed=c.get('seed'),
                state={k:s.get(k) for k in ('ante','round','phase','state','dollars','chips','blind','hands_left','discards_left','reroll_cost','next_blind','next_blind_chips')},
                goal=goal_summary(g),jokers=cards(s.get('jokers',[]),g),
                shop_jokers=cards(s.get('shop_jokers',[]),g),shop_booster=cards(s.get('shop_booster',[]),g),
                pack_cards=cards(s.get('pack_cards',[]),g),advice=c.get('advice'))

paths=sorted(SOURCE.glob('session-20260916T031815Z-1-*.brj'))
inputs=[];events=[];counts=collections.Counter();failures=[];last=None
for p in paths:
    st=p.stat();data=p.read_bytes();st2=p.stat();n=0
    item={'path':str(p),'bytes':len(data),'input_sha256':sha(data),'stat_unchanged_during_read':(st.st_size,st.st_mtime_ns)==(st2.st_size,st2.st_mtime_ns),'append_active':p==paths[-1]}
    try:
        for ordinal,(raw,m) in enumerate(records(io.BytesIO(data)),1):
            e=json.loads(raw);n+=1;counts[e.get('kind')]+=1;last=e['sequence']
            a=dict(segment=p.name,ordinal=ordinal,sequence=e['sequence'],decoded_event_sha256=sha(raw),stored_frame_sha256=m.get('frame_sha256'))
            d=e.get('details',{});sub=d.get('event');seq=e['sequence']
            if (4597<=seq<=5938 and (e.get('kind') in ('action_requested','collection_run_start') or sub in ('run_started','run_terminal','terminal_overlay_close_requested'))) or (d.get('outcome') is not None):
                events.append(brief(e,a))
    except Exception as error:
        failures.append({'path':str(p),'after_complete_records':n,'error':str(error)})
    item['event_count']=n;inputs.append(item)
report={'schema':1,'scope':'Read-only passive journal decoding; no source execution, policy replay, saves/profile reads, search, simulations or game control.',
        'hash_semantics':{'input_sha256':'Exact bytes observed on this read, not a permanent hash for append-active input.','stored_frame_sha256':'BRJ2 header plus stored payload plus newline.','decoded_event_sha256':'Exact reconstructed original JSONL event bytes including newline.'},
        'inputs':inputs,'event_counts':dict(counts),'last_sequence':last,'decode_errors':failures,'events':events}
path=OUT/'zero_sticker_win_audit.json'
with path.open('x',encoding='utf-8') as f: json.dump(report,f,indent=2);f.write('\n')
print(json.dumps({'path':str(path),'sha256':sha(path.read_bytes()),'events':len(events),'failures':failures}))
