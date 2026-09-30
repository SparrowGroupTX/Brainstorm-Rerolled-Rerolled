"""Summarize decisions already recorded in a frozen public journal. No policy execution."""
from pathlib import Path
from collections import Counter,defaultdict
import json,sys
HERE=Path(__file__).resolve().parent
label=sys.argv[1] if len(sys.argv)>1 else 'logs1'
assert label in ('logs1','logs2')
DATA=HERE/label
e=json.loads((DATA/'events.json').read_text())
obs=json.loads((DATA/'observations.json').read_text())
def state(x):return x.get('state')or obs.get(x.get('observation_id'),{}).get('state',{})
def jokers(s):return [{k:j.get(k)for k in ('key','ability','debuff','edition')}for j in s.get('jokers',[])]
runs=defaultdict(lambda:{'actions':Counter(),'rounds':{},'sales':[],'last_state':{},'consumable_uses':Counter()})
for x in e:
    seed=x.get('seed');s=state(x);r=runs[seed]
    if s:r['last_state']=s
    d=x.get('details')or{}
    if x['kind']=='auto_run'and d.get('event')=='run_finished':
        r['terminal']={'sequence':x['sequence'],'at':x['at'],'outcome':d['outcome'],'run_seconds':d['run_seconds'],
          'state':{k:s.get(k)for k in ('ante','round','chips','blind','dollars','hands_left','discards_left')},'jokers':jokers(s)}
    if x['kind']!='action_requested':continue
    a=(d.get('input')or{}).get('action')or{}
    r['actions'][a.get('kind')]+=1
    round_key=str(s.get('round'))+'|'+str((s.get('blind')or{}).get('key'))
    rd=r['rounds'].setdefault(round_key,{'round':s.get('round'),'ante':s.get('ante'),'blind':s.get('blind'),
        'discards':[],'plays':[],'initial_jokers':jokers(s),'last_jokers':[],'cash_at_start':s.get('dollars')})
    rd['last_jokers']=jokers(s)
    if a.get('kind')in('discard','play'):
        row={'sequence':x['sequence'],'action':a,'chips_before':s.get('chips'),'discards_left':s.get('discards_left'),
             'hands_left':s.get('hands_left'),'cards':[s['hand'][i-1]for i in a.get('indices',[])],
             'advice':x.get('advice'),'jokers':jokers(s)}
        rd['discards'if a['kind']=='discard'else'plays'].append(row)
    if a.get('kind')=='sell':
        cards=s.get(a.get('area'),[]);i=a.get('index',0)
        r['sales'].append({'sequence':x['sequence'],'ante':s.get('ante'),'round':s.get('round'),'cash':s.get('dollars'),
          'action':a,'sold':cards[i-1]if 0<i<=len(cards)else None,'advice':x.get('advice')})
    if a.get('kind')=='use':
        cards=s.get(a.get('area'),[]);i=a.get('index',0)
        if 0<i<=len(cards):r['consumable_uses'][cards[i-1].get('key')]+=1

out=DATA/'run_analysis.json'
out.write_text(json.dumps(runs,indent=2,allow_nan=False)+'\n')
short=[]
for seed,r in runs.items():
    if not r['actions']:continue
    terminal=r.get('terminal');last=r['last_state']
    rounds=[]
    for key,rd in r['rounds'].items():
        if not(rd['discards']or rd['plays']):continue
        y=[j for j in rd['last_jokers']if j['key']=='j_yorick']
        rounds.append({'ante':rd['ante'],'round':rd['round'],'blind':(rd['blind']or{}).get('key'),
          'discard_sizes':[len(v['action'].get('indices',[]))for v in rd['discards']],
          'plays':len(rd['plays']),'yorick':{k:y[0]['ability'].get(k)for k in ('x_mult','yorick_discards')}if y else None})
    short.append({'seed':seed,'terminal':terminal,'last_ante':last.get('ante'),'actions':r['actions'],
      'sales':[{k:v for k,v in sale.items()if k!='advice'}for sale in r['sales']],
      'rounds':rounds,'consumable_uses':r['consumable_uses']})
(DATA/'run_summary.json').write_text(json.dumps(short,indent=2)+'\n')
print(json.dumps(short))
