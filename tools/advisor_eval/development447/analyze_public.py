"""Descriptive public-event analysis; never evaluates policy or scorer."""
from pathlib import Path
from collections import Counter,defaultdict
import json,sqlite3,math

HERE=Path(__file__).resolve().parent
OUT=HERE/'analysis';OUT.mkdir(exist_ok=False)
verification=json.loads((HERE.parent/'development446/install/captures/001/summary.json').read_text())
end_sequences={x['details']['run_number']:x['sequence'] for x in verification['endings']}
db=sqlite3.connect('file:'+str(HERE.parent/'development446/install/captures/001/events.sqlite3')+'?mode=ro',uri=True)
def arr(x): return x if isinstance(x,list) else []
def card(c):
    return {k:c[k] for k in ('id','key','rank','suit','enhancement','edition','seal','debuff','face_down','identity_redacted','cost','sell_cost','blueprint_compat','ability') if k in c}
def compact(s):
    row={k:s.get(k) for k in ('phase','ante','round','dollars','chips','hands_left','discards_left','hands_played','discards_used','hand_size','joker_limit','consumable_limit','rental_rate','bankrupt_at','reroll_cost','interest_amount','round_bonus','blind_on_deck')}
    row['blind']=s.get('blind');row['route_blinds']=s.get('route_blinds')
    row['jokers']=[card(c) for c in arr(s.get('jokers'))]
    row['consumeables']=[card(c) for c in arr(s.get('consumeables'))]
    row['hand_levels']={k:{'level':v.get('level'),'played':v.get('played')} for k,v in (s.get('hands') or {}).items()}
    pool=arr(s.get('playing_cards'));row['deck_population']=len(pool)
    row['composition']={field:dict(Counter(str(c.get(field)) for c in pool)) for field in ('rank','suit','enhancement','seal')}
    row['editions']=dict(Counter(json.dumps(c.get('edition'),sort_keys=True) for c in pool))
    return row
obs={};advice={};callbacks={};settle={};requests=[];byrun=defaultdict(list);owned={};offers={};packs={};times={};ends={};starts={}
for seq,kind,run,oid,advseq,data in db.execute('SELECT seq,kind,run,obs,advice_seq,data FROM events ORDER BY seq'):
    e=json.loads(data);ctx=e.get('context') or {};d=e.get('details') or {}
    # The raw index tags the interval between starts. Menu/new-run loading
    # observations after an ending are lifecycle gaps, not prior-run resources.
    if run in end_sequences and seq>end_sequences[run]: run=0
    if kind=='teacher_observation':
        s=ctx.get('snapshot') or {};o={'sequence':seq,'run':run,'observation_id':oid,'snapshot':s,'game_over':ctx.get('game_over'),'at':e.get('at')}
        obs[oid]=o;byrun[run].append(o)
        for c in arr(s.get('jokers')): owned.setdefault((run,c.get('id')),seq)
        for area in ('shop_jokers','pack_cards','shop_booster'):
            for slot,c in enumerate(arr(s.get(area)),1):
                kindkey=c.get('key') or '';is_copy=kindkey in ('j_blueprint','j_brainstorm','j_invisible');is_pack='buffoon' in kindkey
                if not is_copy and not is_pack:continue
                target=offers if is_copy else packs;key=(run,c.get('id'))
                row=target.setdefault(key,{'run':run,'card':card(c),'area':area,'first_sequence':seq,'observation_ids':[],'opened_actions':[],'purchase_actions':[]})
                row['observation_ids'].append(oid);row['last_sequence']=seq
    elif kind=='teacher_advice':
        a=ctx.get('advice') or {};advice[seq]=a
        t=a.get('timing')
        if t: times.setdefault(t.get('decision_id'),{'sequence':seq,'run':run,**t})
    elif kind=='action_requested': requests.append({'sequence':seq,'run':run,'observation_id':oid,'advice_sequence':advseq,'source':d.get('source'),'input':d.get('input'),'action':(d.get('input') or {}).get('action')})
    elif kind=='action_callback_result':callbacks[d.get('action_sequence')]={'sequence':seq,'details':d}
    elif kind=='state_after_actions':
        for actionseq in arr(d.get('action_sequences')):settle.setdefault(actionseq,{'sequence':seq,'observation_id':oid,'details':d})
    elif kind=='auto_run':
        if d.get('event')=='run_started':starts[run]={'sequence':seq,'details':d}
        if d.get('event') in ('run_finished','run_abandoned'):ends[run]={'sequence':seq,'details':d}

decisions=[];death=[];action_counts=defaultdict(Counter);inventory_actions=defaultdict(Counter);blind_entries=[];shop_exits=[]
for req in requests:
    action=req['action'] or {};o=obs.get(req['observation_id']);s=(o or {}).get('snapshot') or {};a=advice.get(req['advice_sequence'],{})
    after_ref=settle.get(req['sequence']);after=obs.get((after_ref or {}).get('observation_id'))
    area=action.get('area');idx=action.get('index');cards=arr(s.get(area));selected=cards[idx-1] if isinstance(idx,int) and 1<=idx<=len(cards) else {}
    row={**req,'observation_sequence':(o or {}).get('sequence'),'advice':a,'selected_card':card(selected),'before':compact(s) if o else None,'callback':callbacks.get(req['sequence']),'settlement':after_ref,'after':compact(after['snapshot']) if after else None}
    decisions.append(row);action_counts[req['run']][action.get('kind','other')]+=1
    key=(req['run'],selected.get('id'))
    if key in packs and action.get('kind')=='open':packs[key]['opened_actions'].append(req['sequence'])
    if key in offers and action.get('kind') in ('buy','choose'):offers[key]['purchase_actions'].append(req['sequence'])
    if selected.get('key'):inventory_actions[req['run']][action.get('kind','?')+':'+selected['key']]+=1
    if action.get('kind')=='select_blind':blind_entries.append(row)
    if action.get('kind')=='leave_shop':shop_exits.append(row)
    if action.get('kind') in ('use','choose') and selected.get('key')=='c_death':
        death.append({**row,'hand':[card(c) for c in arr(s.get('hand'))],
          'public_deck':[card(c) for c in arr(s.get('deck'))],
          'after_hand':[card(c) for c in arr((after or {}).get('snapshot',{}).get('hand'))]})
for target in (offers,packs):
    for key,row in target.items():
        row['first_owned_sequence']=owned.get(key)
        row['observations']=[{'sequence':obs[oid]['sequence'],**compact(obs[oid]['snapshot'])} for oid in row['observation_ids']]
        ids=set(row['observation_ids']);row['decisions']=[d for d in decisions if d['observation_id'] in ids]

runs=[]
for run,start in sorted(starts.items()):
    observations=byrun[run];end=ends.get(run);last=observations[-1]
    hands=[o for o in observations if o['snapshot'].get('phase')=='hand']
    selected=[d for d in decisions if d['run']==run and d['action']]
    runs.append({'run':run,'start':start,'end':end,'last_observation':{'sequence':last['sequence'],**compact(last['snapshot'])},
      'last_hand':{'sequence':hands[-1]['sequence'],**compact(hands[-1]['snapshot'])} if hands else None,
      'last_actions':selected[-8:],'action_counts':dict(action_counts[run]),'inventory_actions':dict(inventory_actions[run]),
      'observations':len(observations),'copies':[{'card':o['card'],'first':o['first_sequence'],'owned':o['first_owned_sequence']} for o in offers.values() if o['run']==run],
      'buffoon_offers':sum(p['run']==run for p in packs.values()),'buffoon_opened':sum(p['run']==run and bool(p['opened_actions']) for p in packs.values()),
      'death_uses':sum(d['run']==run for d in death),
      'first_copy_owned':next((o['sequence'] for o in observations if any(c.get('key') in ('j_blueprint','j_brainstorm') for c in arr(o['snapshot'].get('jokers')))),None)})

def distribution(values):
    v=sorted(values)
    return {'count':len(v),'sum':sum(v),'max':max(v,default=None),'p50':v[max(0,math.ceil(len(v)*.5)-1)] if v else None,'p95':v[max(0,math.ceil(len(v)*.95)-1)] if v else None}
timing={phase:{k:distribution([t[k] for t in times.values() if t.get('phase')==phase and isinstance(t.get(k),(int,float))]) for k in ('active_seconds','elapsed_seconds','evaluations','max_resume_seconds')} for phase in sorted({t.get('phase','unknown') for t in times.values()})}
summary={'runs':len(runs),'observations':len(obs),'actions':len(requests),'actions_with_policy_action':sum(bool(r['action']) for r in requests),'missing_observation_links':sum(r['observation_id'] not in obs for r in requests),'missing_advice_links':sum(r['advice_sequence'] not in advice for r in requests if r['action']),'missing_callbacks':sum(r['sequence'] not in callbacks for r in requests),'missing_settlement_markers':sum(r['sequence'] not in settle for r in requests if r['action']),'copy_offers':len(offers),'copy_first_owned':sum(x['first_owned_sequence'] is not None for x in offers.values()),'copy_request_count':sum(len(x['purchase_actions']) for x in offers.values()),'buffoon_offers':len(packs),'buffoon_opened':sum(bool(x['opened_actions']) for x in packs.values()),'death_uses':len(death),'death_areas':dict(Counter(d['action'].get('area') for d in death)),'timing_unique_decisions':len(times),'timing_by_phase':timing}
artifacts={'runs.json':runs,'decisions.json':decisions,'copy_opportunities.json':list(offers.values()),'buffoon_opportunities.json':list(packs.values()),'death_actions.json':death,'blind_entries.json':blind_entries,'shop_exits.json':shop_exits,'summary.json':summary,'timings.json':list(times.values()),'observations.json':[{'sequence':o['sequence'],'run':o['run'],'observation_id':o['observation_id'],**compact(o['snapshot'])} for o in obs.values()]}
for name,value in artifacts.items():
    with (OUT/name).open('x',encoding='utf-8') as out:json.dump(value,out,indent=2,allow_nan=False)
print(json.dumps(summary))
for r in runs:
    h=r['last_hand'] or {};print(json.dumps({'run':r['run'],'outcome':(r['end'] or {}).get('details',{}).get('outcome','in_progress'),'last_hand_seq':h.get('sequence'),'ante':h.get('ante'),'blind':(h.get('blind') or {}).get('name'),'chips':h.get('chips'),'target':(h.get('blind') or {}).get('chips'),'cash':h.get('dollars'),'row':[(c.get('key'),(c.get('ability') or {}).get('extra')) for c in h.get('jokers',[])],'copies':r['copies'],'buffoons':[r['buffoon_opened'],r['buffoon_offers']],'death_uses':r['death_uses']}))
