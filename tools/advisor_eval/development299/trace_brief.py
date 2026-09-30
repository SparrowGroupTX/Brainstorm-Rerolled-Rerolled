"""Compact read-only status of a registered synthetic trace, never player logs."""
from pathlib import Path
import collections,json,sys
from cycle import BASE,CAPS
job=sys.argv[1]
assert job in CAPS
folder=BASE/job
counts=collections.Counter();last={};terminal=None
with (folder/'trace.log').open(encoding='utf-8') as stream:
    for line in stream:
        if not line.startswith('{'):continue
        try:row=json.loads(line)
        except json.JSONDecodeError:continue
        kind=row.get('type');counts[kind]+=1
        if kind=='engine_episode_decision_started':
            s=row.get('snapshot',{});b=s.get('blind',{});goal=s.get('completionist_goal',{})
            last={'step':row.get('step'),'phase':row.get('phase'),'ante':row.get('ante'),'round':row.get('round'),
                  'blind':b.get('key'),'chips':s.get('chips'),'target':b.get('chips'),
                  'cash':s.get('dollars'),'hands':s.get('hands_left'),'discards':s.get('discards_left'),
                  'jokers':[c.get('key') for c in s.get('jokers',[])], 'gold_counts':goal.get('counts')}
        elif kind=='engine_episode_terminal':terminal=row
record=json.loads((folder/'record.json').read_text()) if (folder/'record.json').exists() else None
print(json.dumps({'job':job,'record':record,'counts':counts,'last_started':last,'terminal':terminal},indent=2))
