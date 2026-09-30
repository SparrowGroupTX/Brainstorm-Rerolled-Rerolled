"""Descriptive metrics from the fixed public cutoff; no policy/scoring imports."""
from pathlib import Path
from collections import Counter,defaultdict
import json,sys
H=Path(__file__).resolve().parent;sys.path.insert(0,str(H.parent))
import flag_suspect_decisions as screen
def read(p):return json.loads(p.read_text())
def save(name,x):
    with (H/name).open('x')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
capture=H/'log_copy/captures/001';cases=[]
screen.analyze(capture/'logs',capture/'manifest.json',256,on_settled=cases.append)
decisions=read(H/'analysis/decisions.json');by_seq={r['sequence']:r for r in decisions}
obs=read(H/'analysis/observations.json');runs=read(H/'analysis/runs.json')
groups=defaultdict(list)
for c in cases:groups[(c['run']['run_number'],c['state']['round'])].append(c)
closed={k:'clear'for k,v in groups.items()if any(c['action']['kind']=='play'for c in v)}
for r in runs:
    if r.get('end')and r['end']['details'].get('outcome')=='loss':closed[(r['run'],r['last_observation']['round'])]='loss'
rounds=[]
for key,outcome in sorted(closed.items()):
    start=next(o for o in obs if (o['run'],o['round'])==key and o['phase']=='hand')
    ds=[c for c in groups[key]if c['action']['kind']=='discard']
    clear=next((c for c in groups[key]if c['action']['kind']=='play'),None)
    rounds.append({'run':key[0],'round':key[1],'outcome':outcome,'ante':start['ante'],
      'blind':start['blind'].get('key'),'initial_discards':start['discards_left'],
      'used_discards':len(ds),'cards':sum(len(c['action']['indices'])for c in ds),
      'unused_at_clear':clear['after']['discards_left']if clear else None,
      'clear_request':clear['anchors']['request']['sequence']if clear else None})
discards=[c for c in cases if c['action']['kind']=='discard']
clears=[c for c in cases if c['action']['kind']=='play']
eligible=[r for r in rounds if r['initial_discards']>0]
unused=[c for c in clears if c['after']['discards_left']>0]
summary={'cutoff_events':13111,'complete_marathon':False,'runs_started':5,'wins':2,'losses':1,'stalls':1,'unfinished_runs':1,
 'qualified_settlements':len(cases),'confirmed_discards':len(discards),
 'discard_sizes':dict(sorted(Counter(len(c['action']['indices'])for c in discards).items())),
 'cards_discarded':sum(len(c['action']['indices'])for c in discards),
 'cards_per_discard':sum(len(c['action']['indices'])for c in discards)/len(discards),
 'confirmed_clears':len(clears),'clears_with_unused_discards':len(unused),
 'unused_at_clear':sum(c['after']['discards_left']for c in unused),
 'completed_rounds_including_loss':len(rounds),'positive_discard_completed_rounds':len(eligible),
 'zero_discard_rounds':[r for r in rounds if r['initial_discards']==0],
 'positive_discard_cards':sum(r['cards']for r in eligible),
 'positive_discard_average_cards':sum(r['cards']for r in eligible)/len(eligible),
 'positive_discard_average_uses':sum(r['used_discards']for r in eligible)/len(eligible),
 'positive_discard_average_target':sum(4*r['initial_discards']for r in eligible)/len(eligible),
 'rounds_below_target':sum(r['cards']<4*r['initial_discards']for r in eligible),
 'population_win_rate_claimed':False,'policy_or_scorer_executed':False,
 'censored_rounds_excluded':True,'rounds':rounds}
save('METRICS.json',summary)
trace={'cutoff':'session-20260928T183037Z-1 through event13111','unused_clears':[],
 'stall_reorders':[],'copy_financing':[],'death_uses':[]}
for c in unused:
    trace['unused_clears'].append({'run':c['run']['run_number'],'anchors':c['anchors'],
      'discards_left':c['after']['discards_left'],'receipt':c['advice'].get('discard_preference'),
      'advice':c['advice']})
for d in decisions:
    if 10319<=d['sequence']<=10486 and (d['action']or{}).get('kind')=='reorder_jokers':
        trace['stall_reorders'].append({k:d[k]for k in ('sequence','observation_sequence','advice_sequence','action','advice','before','after','settlement')})
    if d['sequence']in(11016,11027):trace['copy_financing'].append(d)
for d in read(H/'analysis/death_actions.json'):
    targets=d['action'].get('targets')or[];hand=d.get('hand')or[]
    trace['death_uses'].append({'sequence':d['sequence'],'run':d['run'],'action':d['action'],
      'source':hand[max(targets)-1]if targets else None,'replaced':hand[min(targets)-1]if targets else None})
save('TRACE.json',trace)
print(json.dumps({k:v for k,v in summary.items()if k!='rounds'}))
