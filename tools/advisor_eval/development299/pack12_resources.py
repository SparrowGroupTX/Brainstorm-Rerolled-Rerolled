"""Read only recorded C05 pack trajectories, without evaluating counterfactuals."""
import json
from cycle import BASE
with (BASE/'C05/trace.log').open(encoding='utf-8') as stream:
    for line in stream:
        if not line.startswith('{'):continue
        row=json.loads(line)
        if row.get('type')=='engine_episode_decision' and row.get('step')==12:break
    else:raise ValueError('Missing decision')
s=row['snapshot'];ds=row['result']['pack_diagnostics']
for i,entry in enumerate(ds['comparisons']):
    e=entry['evidence'];f=e['after_finishing']
    out={'offer':s['pack_cards'][i]['key'],'selected':f['selected']['name'],'policies':[]}
    for p in f['policies']:
        worlds=[]
        for w in p['worlds']:
            r=w['endpoint_resources'];f=w.get('finish_details') or {}
            worlds.append({k:w.get(k) for k in ('clear','score','hands_used','discards_used','action_count','population_loss','dollars_after')}|
                {'finish':{k:f.get(k) for k in ('blue_planets','planet_hand','held_dollars','hand_dollars','discard_dollars','slots_after_blue')},
                 'yorick':[{k:j['ability'].get(k) for k in ('yorick_discards','x_mult')} for j in r['jokers'] if j['key']=='j_yorick'],
                 'played':{k:v.get('played') for k,v in r['hands'].items() if v.get('played')}})
        out['policies'].append({'name':p['name'],'clears':p['clearing_samples'],'worlds':worlds})
    print(json.dumps(out,indent=2))
