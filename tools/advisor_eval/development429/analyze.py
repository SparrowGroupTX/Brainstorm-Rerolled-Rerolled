"""Descriptive aggregation only; never invokes a policy or simulator."""
from pathlib import Path
from collections import Counter, defaultdict
import json

HERE=Path(__file__).resolve().parent
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def save(p,x):
    with Path(p).open('x',encoding='utf-8') as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def ratio(a,b):return a/b if b else None
def action(v):return (v or {}).get('decision',{}).get('action') or {}
def brief(r):
    if r['status']!='complete':return {'worker_status':r['status']}
    v=r['result'];d=v.get('decision',{})
    return {'worker_status':'complete','status':v['status'],'action':action(v),
        'evaluations':d.get('evaluations'),'play':d.get('play'),
        'discard_before_clear':d.get('discard_before_clear'),'yorick_review':d.get('yorick_review')}
def actions_metric(values):
    acts=[action(v) for v in values];dis=[a for a in acts if a.get('kind')=='discard']
    cards=sum(len(a['indices']) for a in dis)
    return {'decisions':len(acts),'action_kinds':dict(Counter(a.get('kind') for a in acts)),
        'discard_actions':len(dis),'cards_discarded':cards,'cards_per_discard':ratio(cards,len(dis)),
        'five_card_discards':sum(len(a['indices'])==5 for a in dis),
        'discard_size_distribution':dict(Counter(len(a['indices']) for a in dis))}

def main():
    assert (HERE/'CLOSED.json').exists(),'Evaluation must close before aggregation'
    m=read(HERE/'manifest.json');cases=read(HERE/'cases.json');jobs=read(HERE/'jobs.json')
    rows={key:read(HERE/'results'/f'{key}.json') for key in jobs}
    out={'closed':read(HERE/'CLOSED.json'),'decision':{},'continuation':{},
        'limits':['Selected suspect states and controls, not representative rounds or fresh full runs.',
                  'Hypothetical private draw permutations, not the actual unobserved future.',
                  'Supported-clear results condition on adapter coverage; censoring is explicit.',
                  'Two worlds per round are correlated; primary continuation averages weight each round equally.']}
    details=[];groups=defaultdict(list)
    for key,c in cases.items():
        b=rows['D-'+key+'-baseline'];a=rows['D-'+key+'-candidate']
        paired=b['status']==a['status']=='complete'
        detail={'id':key,'group':c['group'],'round_key':c['round_key'],
                'recorded_action':c['recorded_action'],'baseline':brief(b),'candidate':brief(a),'paired_complete':paired}
        if paired:
            detail['action_changed']=action(b['result'])!=action(a['result'])
            detail['baseline_matches_recorded']=action(b['result'])==c['recorded_action']
            detail['candidate_matches_recorded']=action(a['result'])==c['recorded_action']
        details.append(detail);groups[c['group']].append(detail)
    for group,ds in [*groups.items(),('all',details)]:
        pairs=[d for d in ds if d['paired_complete']]
        metric={'registered':len(ds),'paired_complete':len(pairs),
            'baseline_matches_recorded':sum(d['baseline_matches_recorded'] for d in pairs),
            'candidate_matches_recorded':sum(d['candidate_matches_recorded'] for d in pairs),
            'changed_ids':[d['id'] for d in pairs if d['action_changed']],
            'worker_statuses':{role:dict(Counter(d[role]['worker_status'] for d in ds)) for role in ('baseline','candidate')}}
        for role in ('baseline','candidate'):
            metric[role]=actions_metric([rows['D-'+d['id']+'-'+role]['result'] for d in pairs])
        metric['action_transitions']=dict(Counter(
            str(d['baseline']['action'].get('kind'))+' -> '+str(d['candidate']['action'].get('kind')) for d in pairs))
        out['decision'][group]=metric
    worlds=[]
    for key in m['selection']['continuation_rounds']:
        c=cases[key]
        for world in (1,2):
            pair={'id':key,'round_key':c['round_key'],'world':world,'prefix_discards':c['prefix_discards'],
                'prefix_cards_discarded':c['prefix_cards_discarded'],'prefix_count_matches':c['prefix_count_matches']}
            for role in ('baseline','candidate'):
                r=rows[f'R-{key}-{world}-{role}'];v=r.get('result',{})
                pair[role]={'worker_status':r['status'],'status':v.get('status'),'reason':v.get('reason'),
                    **{k:v.get(k) for k in ('discards','cards_discarded','five_card_discards','remaining_discards','plays')}}
                if r['status']=='complete' and c['prefix_count_matches']:
                    pair[role]['round_discards']=c['prefix_discards']+v['discards']
                    pair[role]['round_cards_discarded']=c['prefix_cards_discarded']+v['cards_discarded']
            pair['both_clear']=all(pair[role]['status']=='supported_clear' for role in ('baseline','candidate'))
            worlds.append(pair)
    by_round=defaultdict(list)
    for p in worlds:by_round[p['round_key']].append(p)
    strict=[p for ps in by_round.values() if len(ps)==2 and all(p['both_clear'] and p['prefix_count_matches'] for p in ps) for p in ps]
    paired=[p for p in worlds if p['both_clear'] and p['prefix_count_matches']]
    def measures(ps):
        result={'round_world_pairs':len(ps),'distinct_rounds':len({p['round_key'] for p in ps})}
        for role in ('baseline','candidate'):
            ds=sum(p[role]['round_discards'] for p in ps);cards=sum(p[role]['round_cards_discarded'] for p in ps)
            cd=sum(p[role]['discards'] for p in ps);cc=sum(p[role]['cards_discarded'] for p in ps)
            result[role]={'discards_per_round':ratio(ds,len(ps)),'cards_discarded_per_round':ratio(cards,len(ps)),
                'cards_per_discard':ratio(cards,ds),'continuation_discards':cd,'continuation_cards':cc,
                'continuation_cards_per_discard':ratio(cc,cd),'continuation_five_card_discards':sum(p[role]['five_card_discards'] for p in ps),
                'mean_remaining_discards_at_clear':ratio(sum(p[role]['remaining_discards'] for p in ps),len(ps))}
        return result
    out['continuation']={'registered_rounds':len(by_round),'registered_round_world_pairs':len(worlds),
        'statuses':{role:dict(Counter(p[role]['status'] or p[role]['worker_status'] for p in worlds)) for role in ('baseline','candidate')},
        'primary_complete_two_world_rounds':measures(strict),'secondary_both_clear_worlds':measures(paired),
        'improved_discard_worlds':[{'id':p['id'],'world':p['world'],'before':p['baseline']['discards'],'after':p['candidate']['discards']} for p in paired if p['candidate']['discards']>p['baseline']['discards']],
        'fewer_discard_worlds':[{'id':p['id'],'world':p['world'],'before':p['baseline']['discards'],'after':p['candidate']['discards']} for p in paired if p['candidate']['discards']<p['baseline']['discards']]}
    save(HERE/'DECISION_PAIRS.json',details);save(HERE/'ROUND_PAIRS.json',worlds);save(HERE/'RESULTS.json',out)
    print(json.dumps(out,indent=2))

if __name__=='__main__':main()
