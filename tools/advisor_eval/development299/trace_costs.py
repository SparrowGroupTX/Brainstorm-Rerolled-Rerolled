"""Read-only cost summary of completed selected synthetic episode decisions."""
from pathlib import Path
import collections,json,sys
from cycle import BASE,CAPS

job=sys.argv[1];assert job in CAPS and job.startswith('C')
starts={};decisions=[];profiles=[];kinds=collections.Counter()
for line in (BASE/job/'trace.log').open(encoding='utf-8'):
    if not line.startswith('{'):continue
    try:r=json.loads(line)
    except json.JSONDecodeError:continue
    kind=r.get('type');kinds[kind]+=1
    if kind=='engine_episode_decision_started':starts[r['step']]=r
    elif kind=='engine_episode_decision':decisions.append(r)
    elif kind=='engine_episode_profile':profiles.append(r)
if not decisions:
    print(json.dumps({'kinds':kinds,'decision_keys':[]},indent=2));sys.exit()
by_step={r['step']:r for r in decisions};groups={};rows=[]
for p in profiles:
    decision=by_step[p['step']];s=decision['snapshot'];r=decision['result']
    phase=p['phase'];a=r.get('action') or {};key=phase+':'+str(a.get('kind'))
    g=groups.setdefault(key,dict(count=0,seconds=0,calls=0))
    g['count']+=1;g['seconds']+=p['advisor_seconds'];g['calls']+=p['score_calls']
    rows.append({'step':p['step'],'phase':phase,'action':a,'kind':r.get('kind'),
      'ante':s.get('ante'),'round':s.get('round'),'jokers':[j['key'] for j in s.get('jokers',[])],
      'seconds':p['advisor_seconds'],'calls':p['score_calls'],'score_cache':r.get('score_cache')})
print(json.dumps({'job':job,'completed':len(profiles),
    'grouped':dict(sorted(groups.items(),key=lambda kv:-kv[1]['seconds'])),
    'most_expensive':sorted(rows,key=lambda r:-r['seconds'])[:12]},indent=2))
