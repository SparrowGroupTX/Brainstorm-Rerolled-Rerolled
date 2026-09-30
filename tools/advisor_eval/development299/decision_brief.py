"""Read only a bounded selected-step summary from a registered synthetic trace."""
import json,sys
from cycle import BASE,CAPS
job=sys.argv[1];assert job in CAPS
step=int(sys.argv[2]) if len(sys.argv)>2 else None
def brief(value,depth=0):
    if depth>5:return '<nested>'
    if isinstance(value,dict):
        return {k:brief(v,depth+1) for k,v in value.items() if k not in ('snapshot','before_finishing','after_finishing','worlds','jokers','hand','deck','playing_cards','consumeables')}
    if isinstance(value,list):return [brief(v,depth+1) for v in value[:5]]+(['<more>'] if len(value)>5 else [])
    if isinstance(value,str) and len(value)>400:return value[:400]+'<more>'
    return value
with (BASE/job/'trace.log').open(encoding='utf-8') as stream:
    for line in stream:
        if not line.startswith('{'):continue
        row=json.loads(line)
        if row.get('type') not in ('engine_episode_decision','engine_episode_profile'):continue
        if step is not None and row.get('step')!=step:continue
        if step is None:
            if row['type']=='engine_episode_profile':continue
            s=row['snapshot'];r=row['result']
            print(json.dumps({'step':row['step'],'ante':s.get('ante'),'phase':s['phase'],'cash':s.get('dollars'),
                              'action':r.get('action'),'evaluations':r.get('evaluations'),
                              'pack_survival':brief((r.get('pack_diagnostics') or {}).get('survival_priority')),
                              'pack_comparisons':len((r.get('pack_diagnostics') or {}).get('comparisons') or [])}))
        else:print(json.dumps(brief(row),indent=2))
