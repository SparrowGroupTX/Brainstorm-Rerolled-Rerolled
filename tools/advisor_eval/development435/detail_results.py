"""Passive resource and diagnostic extraction from already closed435 outputs."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
assert read(HERE/'CLOSED.json')['remaining_authority']==0
cases=read(HERE/'cases.json');out={'admission':{},'endpoints':[],'censored':[],'paired_hand_totals':{}}
for case in ('10102','13255','18317','27883'):
 d=read(HERE/'results'/f'diag_{case}.json')['result'];s=cases[case]['snapshot']
 def cards(a):return [{k:s['hand'][i-1].get(k)for k in ('id','rank','suit','enhancement','seal')}for i in a['indices']]
 out['admission'][case]={'default_cards':cards(d['default']),'five_cards':cards(d['five']),
  'alternatives':[a for a in d['alternatives']if a['indices']in(d['default']['indices'],d['five']['indices'])]}
for f in sorted((HERE/'results').glob('*.json')):
 row=read(f);r=row.get('result',{})
 if not r.get('steps'):continue
 y=next((j for j in r['resources']['jokers']if j['key']=='j_yorick'),{}).get('ability',{})
 out['endpoints'].append({'job':f.stem,'status':r['status'],'discards':r['discards'],'cards':r['cards_discarded'],
  'dollars':r['resources']['dollars'],'hands_left':r['resources']['hands_left'],'population':r['resources']['population'],
  'yorick_x_mult':y.get('x_mult'),'yorick_countdown':y.get('yorick_discards'),'resources_final':r['final_resources_supported']})
 if r['status']=='unsupported':
  selected=set(r['steps'][-1]['card_ids']);lucky=[c['id']for c in r['resources']['held']if c['id']in selected and c.get('enhancement')=='m_lucky']
  out['censored'].append({'job':f.stem,'raw_reason':r['reason'],'last_step':r['steps'][-1],'selected_lucky_ids':lucky,
   'interpretation':'Owned-Lucky uncertain transition is outside sampled_outcomes support; inferred from saved trace and frozen source, without rerunning.'})
for role in ('default','five'):
 rows=[read(HERE/'results'/f'{case}_w{w}_{role}.json')['result']for case in ('10102','18317','27883')for w in range(4)]
 out['paired_hand_totals'][role]={'branches':len(rows),'clears':sum(r['status']=='supported_clear'for r in rows),
  **{k:sum(r[k]for r in rows)for k in ('discards','cards_discarded','five_card_discards','plays','remaining_discards')}}
with(HERE/'DETAILS.json').open('x',encoding='utf-8')as f:json.dump(out,f,indent=2);f.write('\n')
print(json.dumps(out['paired_hand_totals']))
