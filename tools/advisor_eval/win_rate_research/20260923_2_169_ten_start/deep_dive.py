"""Deterministic public-log aggregation. No game/policy/scorer imports or calls."""
from pathlib import Path
from collections import Counter
import json
P=Path(__file__).resolve().parent
E=[json.loads(x) for x in (P/'capture/events.jsonl').read_text().splitlines()]
A=json.loads((P/'actions.json').read_text()); R=json.loads((P/'runs.json').read_text())
B=json.loads((P/'rounds.json').read_text())
byseq={e['sequence']:e for e in E}
def save(n,x): (P/n).write_text(json.dumps(x,indent=2)+'\n',encoding='utf-8')
out=[];offers=[]
for r in R:
 rid=r['run_instance']; aa=[a for a in A if a['run_instance']==rid]
 ss=[e for e in E if e['run_instance']==rid and e.get('state') and e['sequence']<=r['end_sequence']]
 first=next(e for e in ss if {c['key'] for c in e['state']['jokers']} >= {'j_yorick','j_perkeo'})
 search=next(e for e in reversed(E[:r['start_sequence']]) if e['kind']=='collection_search_finished')
 sr=search['details']['receipt']; seen={}; copies=[]
 for a in aa:
  s=a.get('before',{});act=a['action'];kind=act.get('kind')
  if kind in ('buy','choose','leave_shop'):
   for area in ('shop_jokers','pack_cards'):
    for i,c in enumerate(s.get(area)or[],1):
     if c['key'] not in ('j_blueprint','j_brainstorm'):continue
     k=c['id'];bought=kind in ('buy','choose') and act.get('area')==area and act.get('index')==i
     if k not in seen or bought or kind=='leave_shop':
      seen[k]={'run':r['run'],'sequence':a['sequence'],'observation':a['before_sequence'],'advice':a['advice_sequence'],
       'key':c['key'],'ante':s['ante'],'cost':c['cost'],'cash':s['dollars'],'bankrupt_at':s['bankrupt_at'],
       'bought':bought,'area':area,'rental':bool(c['ability'].get('rental')),'perishable':bool(c['ability'].get('perishable')),
       'affordable_before_sale':area=='pack_cards' or c['cost']<=s['dollars']-s['bankrupt_at'],
       'sellable_keys':[x['key'] for x in s['jokers'] if not x['ability'].get('eternal')],
       'gold_review':a['advice'].get('gold_review'),'anchor':a['anchor']}
  if kind in ('leave_shop','discard','play') and any(c['key'] in ('j_blueprint','j_brainstorm') for c in s.get('jokers',[])):
   row=s['jokers']
   def resolve(i,visited):
    if i<0 or i>=len(row) or i in visited:return 'invalid_or_cycle'
    c=row[i];key=c['key']
    if c.get('identity_redacted') or c.get('face_down') or not key:return 'unknown_public_order'
    if c.get('debuff'):return 'debuffed'
    if key=='j_blueprint':return resolve(i+1,visited|{i})
    if key=='j_brainstorm':return resolve(0,visited|{i})
    return key # structural target only, not an assertion of compatible effect
   copies.append({'sequence':a['sequence'],'phase':kind,'targets':[resolve(i,set()) for i,c in enumerate(row) if c['key'] in ('j_blueprint','j_brainstorm')]})
 early=[b for b in B if b['run']==r['run'] and b['ante']<=3 and b['cleared']]
 termround=r['last_round'];lastactions=[a for a in aa if a.get('before',{}).get('round')==termround and a['action'].get('kind')in ('play','discard','use','reorder')]
 out.append({'run':r['run'],'first_yorick_perkeo':first['sequence'],'search_sequence':search['sequence'],
  'search_request':sr['request'],'search_result':sr['result'],
  'actual_opening_actions':[{'sequence':a['sequence'],'action':a['action'],'selected':(a.get('selected')or{}).get('key'),'phase':a.get('before',{}).get('phase'),'ante':a.get('before',{}).get('ante'),'blind':a.get('before',{}).get('blind_choices')} for a in aa if a['sequence']<=first['sequence']],
  'early_clears':len(early),'early_unused_discards':sum(b['remaining_discards'] for b in early),
  'early_clears_with_unused':sum(b['remaining_discards']>0 for b in early),
  'discarded_cards':sum(len(a['action'].get('indices',[])) for a in aa if a['action'].get('kind')=='discard'),
  'observatory_snapshots':sum(bool((e['state'].get('used_vouchers')or{}).get('v_observatory')) for e in ss),
  'copy_targets':copies,'terminal_actions':[{'sequence':a['sequence'],'before_sequence':a['before_sequence'],'after_sequence':a['after_sequence'],'action':a['action'],'advice':a['advice'],'cash':a['before']['dollars'],'hands_left':a['before']['hands_left'],'discards_left':a['before']['discards_left'],'before_chips':a['before']['chips'],'first_settled_chips':a.get('after',{}).get('chips'),'hand':a['before']['hand'],'current_round':a['before']['current_round']} for a in lastactions],
  'sales':r['sales']})
 offers.extend(seen.values())
save('deep_dive.json',out);save('copy_opportunities.json',offers)
summary={'early_clears':sum(x['early_clears']for x in out),'early_unused_discards':sum(x['early_unused_discards']for x in out),
 'early_clears_with_unused':sum(x['early_clears_with_unused']for x in out),'observatory_snapshots':sum(x['observatory_snapshots']for x in out),
 'profile_projection':dict(Counter(str((e['state']['teacher_profile'],e['state']['completionist_goal_present'],e['state']['collection_progress_present']))for e in E if 'state'in e)),
 'action_sources':dict(Counter(a['source']for a in A)),'auto_events':dict(Counter(e['details'].get('event')for e in E if e['kind']=='auto_run')),
 'unique_seed_count':len(set(r['seed']for r in R)),
 'copy_offers':[{k:x[k]for k in ('run','sequence','key','ante','cost','cash','bought','affordable_before_sale','rental','perishable')}for x in offers],
 'consumable_sale_count':sum(a['action'].get('kind')=='sell' and a['action'].get('area')=='consumeables' for a in A)}
save('deep_summary.json',summary)
print(json.dumps(summary))
