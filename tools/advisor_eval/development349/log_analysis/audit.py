"""One-use read-only freeze of a named passive log session. No policy execution."""
import collections
import hashlib
import io
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'tools/advisor_eval'))
from read_player_log import records

def sha(data): return hashlib.sha256(data).hexdigest()
SOURCE = Path(r'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2')
PREFIX = 'session-20260916T063659Z-1'
paths = sorted(SOURCE.glob(PREFIX + '-*.brj'))
assert 1 <= len(paths) <= 16
lengths = {p: p.stat().st_size for p in paths}
assert sum(lengths.values()) <= 32 * 1024 * 1024
FROZEN = HERE / 'frozen_prefix'; FROZEN.mkdir(exist_ok=False)
inputs = []; events = []; errors = []; versions = collections.Counter(); kinds = collections.Counter()
for p in paths:
    before = p.stat()
    with p.open('rb') as handle: data = handle.read(lengths[p])
    after = p.stat(); assert len(data) == lengths[p]
    frozen = FROZEN / p.name
    with frozen.open('xb') as handle: handle.write(data)
    item = {'original_path': str(p), 'frozen_path': str(frozen), 'bytes': len(data), 'sha256': sha(data),
        'append_active': p == paths[-1], 'stat_unchanged_during_read': (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns),
        'original_size_after_read': after.st_size}
    count = 0
    try:
        for ordinal, (raw, meta) in enumerate(records(io.BytesIO(data)), 1):
            event = json.loads(raw); count += 1
            a = {'segment': p.name, 'ordinal': ordinal, 'sequence': event.get('sequence'),
                'decoded_event_sha256': sha(raw), 'stored_frame_sha256': meta.get('frame_sha256')}
            c = event.get('context', {}); version = c.get('version')
            if version: versions[version] += 1
            kinds[event.get('kind')] += 1
            events.append((event, a, raw))
    except Exception as exc:
        errors.append({'segment': p.name, 'completed_records': count, 'error': str(exc)})
    item['event_count'] = count; inputs.append(item)

def slim_card(card, goal):
    return {**{k: card.get(k) for k in ('id','key','name','cost','sell_cost','edition','ability','debuff')},
        'gold_record': goal.get('by_key', {}).get(card.get('key'))}

def brief(e, a):
    c=e.get('context',{}); s=c.get('snapshot',{}); g=s.get('completionist_goal',{})
    return {'anchor':a, 'at':e.get('at'), 'kind':e.get('kind'), 'version':c.get('version'), 'seed':c.get('seed'),
        'details':e.get('details'), 'state':{k:s.get(k) for k in ('ante','round','phase','state','dollars','joker_limit','consumable_limit','next_blind','next_blind_chips','hands_left','discards_left')},
        'goal_counts':g.get('counts'), 'advice':c.get('advice')}

decisions = []; receipts = []; observations=[]
for index, (e,a,raw) in enumerate(events):
    c=e.get('context',{}); s=c.get('snapshot',{}); advice=c.get('advice') or {}
    if e.get('kind')!='action_requested': continue
    action=e.get('details',{}).get('input',{}).get('action',{})
    area=action.get('area'); ix=action.get('index')
    card=None
    if isinstance(ix,int) and isinstance(s.get(area),list) and 0<ix<=len(s[area]): card=s[area][ix-1]
    if not (card and card.get('key')=='j_droll') and 'Droll' not in advice.get('title',''): continue
    g=s.get('completionist_goal',{})
    report=brief(e,a); report['selected_card']=slim_card(card,g) if card else None
    report['selected_action']=action
    report['jokers_before']=[slim_card(j,g) for j in s.get('jokers',[])]
    report['hands']={name:{k:v.get(k) for k in ('level','chips','mult','played','played_this_round')} for name,v in s.get('hands',{}).items()}
    report['shop_jokers']=[slim_card(j,g) for j in s.get('shop_jokers',[])]
    report['pack_cards']=[slim_card(j,g) for j in s.get('pack_cards',[])]
    report['pack_type']=s.get('pack_type'); report['pack_choices']=s.get('pack_choices')
    report['rank_population']=dict(collections.Counter(str(j.get('base',{}).get('id')) for j in s.get('playing_cards',[])))
    follow=[]
    chosen_records=[(e,a,raw)]
    for ee,aa,rr in events[index+1:index+9]:
        if ee.get('kind') not in ('action_callback_result','state_after_actions'): continue
        follow.append(brief(ee,aa)); chosen_records.append((ee,aa,rr))
        if ee.get('kind')=='state_after_actions':
            ss=ee.get('context',{}).get('snapshot',{}); gg=ss.get('completionist_goal',{})
            report['jokers_after']=[slim_card(j,gg) for j in ss.get('jokers',[])]
            break
    report['immediate_following_records']=follow
    for ee,aa,rr in chosen_records:
        dest=HERE/('original_event_'+str(aa['sequence'])+'.json')
        with dest.open('xb') as handle: handle.write(rr)
        receipts.append({'path':str(dest),'sha256':sha(rr),'anchor':aa})
    decisions.append(report)

for e,a,raw in events:
    if e.get('details',{}).get('event') in ('run_finished','session_stopped'):
        observations.append(brief(e,a))

out=HERE/'report.json'
report={'schema':1,'scope':'Read-only named passive journal prefix freeze; no policy evaluations, replay, source/native components, searches, simulations, save/profile reads or game control.',
    'prefix':PREFIX,'inputs':inputs,'hash_semantics':'Exact frozen byte prefixes; append-active source may grow later. Original and decoded-frame hashes preserve provenance.',
    'loaded_versions':dict(versions),'event_counts':dict(kinds),'decode_errors':errors,
    'last_sequence':events[-1][1]['sequence'],'last_at':events[-1][0].get('at'),
    'droll_decisions':decisions,'terminal_or_stop_records':observations,'original_event_receipts':receipts,
    'limits':['No counterfactual policy was executed.','No outcome beyond the frozen prefix is imputed.','Scores and decision labels are recorded advice, not independently reevaluated.']}
with out.open('x',encoding='utf-8') as handle: json.dump(report,handle,indent=2);handle.write('\n')
print(json.dumps({'path':str(out),'sha256':sha(out.read_bytes()),'input_bytes':sum(i['bytes'] for i in inputs),'loaded_versions':dict(versions),
    'event_count':len(events),'last_sequence':report['last_sequence'],'last_at':report['last_at'],'decode_errors':errors,
    'droll':[{'sequence':d['anchor']['sequence'],'at':d['at'],'state':d['state'],'selected_action':d['selected_action'],
        'selected_card':d['selected_card'],'advice':d['advice'],'immediate_following_records':[{k:v for k,v in f.items() if k in ('anchor','kind','details','state')} for f in d['immediate_following_records']]} for d in decisions]}))
