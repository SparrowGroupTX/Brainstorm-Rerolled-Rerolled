"""Descriptive results only; never imports or invokes a policy."""
from pathlib import Path
from collections import Counter
import json
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def terminal(r):return r.get('status')in('supported_clear','supported_clear_floor','modeled_failure')
def clear(r):return r.get('status')in('supported_clear','supported_clear_floor')
closed=read(HERE/'CLOSED.json');assert closed['remaining_authority']==0
reg=read(HERE/'registration.json');jobs=read(HERE/'jobs.json')
results={key:read(HERE/'results'/f'{key}.json')for key in jobs}
summary={'closed':closed,'all_registered_jobs':len(jobs),'cases':{},'interpretation':'Selected local positions and hypothetical worlds, not full-run population outcomes.'}
for case in read(HERE/'cases.json'):
 diag=results['diag_'+case];pack=case=='10067';roles=['j_sly','j_trio']if pack else['default','five']
 rows={role:[r for r in results.values()if r['case']==case and r['role']==role]for role in roles}
 pairs=[]
 for keys in reg['pairs']:
  if jobs[keys[0]]['case']!=case:continue
  byrole={jobs[key]['role']:results[key]for key in keys};models={k:v.get('result',{})for k,v in byrole.items()}
  complete=all(terminal(v)for v in models.values())
  row={'world':jobs[keys[0]]['world'],'statuses':{k:v.get('result',{}).get('status',v['status'])for k,v in byrole.items()},'both_terminal':complete}
  if complete:
   left,right=(models[k]for k in roles)
   row.update(clear={k:clear(v)for k,v in models.items()},clear_delta=int(clear(right))-int(clear(left)),
    metric_delta={k:right[k]-left[k]for k in ('discards','cards_discarded','five_card_discards','plays','remaining_discards')},
    final_resources_supported=all(v.get('final_resources_supported')for v in models.values()))
  pairs.append(row)
 byrole={}
 for role,rr in rows.items():
  models=[r['result']for r in rr if r['status']=='complete'];tt=[r for r in models if terminal(r)]
  byrole[role]={'registered':len(rr),'statuses':dict(Counter(r.get('result',{}).get('status',r['status'])for r in rr)),
   'terminal':len(tt),'clears':sum(clear(r)for r in tt),
   'terminal_totals':{k:sum(r[k]for r in tt)for k in ('discards','cards_discarded','five_card_discards','plays','remaining_discards')},
   'terminal_final_resources_supported':sum(r.get('final_resources_supported',False)for r in tt)}
 summary['cases'][case]={'diagnostic':diag,'roles':byrole,'pairs':pairs,'terminal_pairs':sum(p['both_terminal']for p in pairs),
  'right_only_clear':sum(p.get('clear_delta')==1 for p in pairs),'left_only_clear':sum(p.get('clear_delta')==-1 for p in pairs)}
with(HERE/'RESULTS.json').open('x',encoding='utf-8')as f:json.dump(summary,f,indent=2,allow_nan=False);f.write('\n')
compact={k:{'diagnostic_status':v['diagnostic']['status'],'admitted':v['diagnostic'].get('result',{}).get('admitted'),
 'default':v['diagnostic'].get('result',{}).get('default'),'five':v['diagnostic'].get('result',{}).get('five'),
 'roles':v['roles'],'terminal_pairs':v['terminal_pairs'],'right_only_clear':v['right_only_clear'],'left_only_clear':v['left_only_clear']}for k,v in summary['cases'].items()}
print(json.dumps(compact,indent=2))
