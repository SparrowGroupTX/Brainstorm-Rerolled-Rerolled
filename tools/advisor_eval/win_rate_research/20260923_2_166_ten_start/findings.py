"""Recorded public quantities and slot arithmetic only; never invokes policy/scorer."""
from pathlib import Path
from collections import Counter
import json, hashlib
P=Path(__file__).resolve().parent
def read(n):return json.loads((P/n).read_text(encoding='utf-8'))
def save(n,x):(P/n).write_text(json.dumps(x,indent=2)+'\n',encoding='utf-8')
A=read('actions.json');R=read('runs.json');B=read('rounds.json')
E=[json.loads(x)for x in (P/'capture/events.jsonl').read_text().splitlines()]
old=read('../20260923_ten_start/runs.json')
early=[b for b in B if b['ante']<=3 and b['cleared'] and b['remaining_discards']>0]
blocked=[]
for b in early:
 keys=[j['key'] for j in b['jokers'] if not j['debuff'] and j['key'] in ('j_blue_joker','j_raised_fist','j_blackboard','j_shoot_the_moon')]
 if keys:blocked.append({'run':b['run'],'round':b['round'],'sequence':b['exit_sequence'],'unused':b['remaining_discards'],'keys':keys})
stock=[{'sequence':a['sequence'],'action':a['action'],'key':(a.get('selected')or{}).get('key')} for a in A if any('Compare remaining usable stock' in l for l in a['advice'].get('lines',[]))]
generator_shops=[]
for a in A:
 if a['action'].get('kind')!='leave_shop':continue
 s=a['before'];cards=s['consumeables']
 if not any(j['key']=='j_perkeo' and not j['debuff'] for j in s['jokers']):continue
 candidates=[]
 for i,c in enumerate(cards,1):
  if c['key'] not in ('c_emperor','c_high_priestess','c_judgement'):continue
  neg=bool((c.get('edition')or{}).get('negative'))
  slots=(s['joker_limit']-len(s['jokers'])) if c['key']=='c_judgement' else s['consumable_limit']-int(neg)-(len(cards)-1)
  candidates.append({'index':i,'key':c['key'],'negative':neg,'public_slots_after_removal':slots})
 if candidates:generator_shops.append({'sequence':a['sequence'],'run_instance':a['run_instance'],'ante':s['ante'],'candidates':candidates,'positive_space':any(c['public_slots_after_removal']>0 for c in candidates)})
save('generator_shop_opportunities.json',generator_shops)
focus=[a for a in A if a['sequence'] in (4800,12595,14809,3099,2316,2327,6400,14282,9195,16950)]
save('focused_actions.json',focus)
markers=Counter();timings=0;caps=0
for a in A:
 timing=a['advice'].get('timing')or{}
 if a.get('before',{}).get('phase')=='hand' and timing.get('evaluations') is not None:
  timings+=1;caps+=timing['evaluations']>=140000
 for name,term in [('mouth_cycle','Cycle a non-scoring hand'),('stock_management','Compare remaining usable stock'),('consumable_budget','consumable search budget'),('order_budget','order-search budget')]:
  if term in ' '.join([a['advice'].get('title','')]+a['advice'].get('lines',[])):markers[name]+=1
cursor=Path('C:/Users/trevo/AppData/Roaming/Balatro/brainstorm_collection_cursor_v1.txt').read_bytes()
(P/'cursor_observation.txt').write_bytes(cursor)
coeff=[66231629136,1892332261,54066636,1544761,44136,1261,36,1];chars='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
last_id=sum(1+chars.index(c)*coeff[i] for i,c in enumerate(reversed(R[-1]['seed'])))
summary={'same_seed_overlap':sorted({r['seed']for r in R}&{r['seed']for r in old}),
 'cursor_sha256':hashlib.sha256(cursor).hexdigest(),'cursor_value':int(cursor.decode().strip().split(':')[1]),'last_seed_plus_one':last_id+1,
 'boss_rounds':[{'run':b['run'],'blind':b['blind'],'entry':b['entry_sequence'],'exit':b['exit_sequence'],'cleared':b['cleared']}for b in B if b['blind']in('The Mouth','Amber Acorn')],
 'stock_actions':stock,'stock_keys':dict(Counter(x['key']for x in stock)),
 'generator_shop_exits':len(generator_shops),'generator_shop_exits_with_positive_space':sum(x['positive_space']for x in generator_shops),
 'generator_runs':sorted({r['run']for r in R if any(x['run_instance']==r['run_instance']for x in generator_shops)}),
 'growth_scope_block_presence':blocked,'unused_under_draw_dependent_jokers':sum(x['unused']for x in blocked),
 'hand_timings_available':timings,'ordinary_cap_reached':caps,'action_markers':dict(markers),
 'limitations':['Slot arithmetic is not a complete legality/profitability certificate.','Gate presence does not prove growth reached that guard or a safe useful discard exists.','No Acorn exposure or Mouth-cycle execution is not a successful test of those fallbacks.','Different seeds do not provide matched causal before/after outcomes.']}
save('findings.json',summary)
print(json.dumps(summary))
