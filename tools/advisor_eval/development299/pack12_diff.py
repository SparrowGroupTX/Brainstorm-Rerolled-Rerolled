"""Read-only comparison of preserved C05 pack evidence; no policy evaluation."""
import json
from cycle import BASE
with (BASE/'C05/trace.log').open(encoding='utf-8') as stream:
    for line in stream:
        if not line.startswith('{'):continue
        row=json.loads(line)
        if row.get('type')=='engine_episode_decision' and row.get('step')==12:break
    else:raise ValueError('Missing decision')
ds=row['result']['pack_diagnostics'];entries=ds['comparisons']
print(json.dumps({'priority':ds.get('survival_priority'),'comparisons':len(entries),'snapshot_cards':len(row['snapshot']['playing_cards'])}))
def differences(a,b,path='',out=None):
    out=[] if out is None else out
    if type(a)!=type(b):out.append({'path':path,'a':str(a)[:180],'b':str(b)[:180]})
    elif isinstance(a,dict):
        for key in sorted(a.keys()|b.keys()):
            if key not in a or key not in b:out.append({'path':path+'/'+key,'missing':'a' if key not in a else 'b'})
            else:differences(a[key],b[key],path+'/'+key,out)
    elif isinstance(a,list):
        if len(a)!=len(b):out.append({'path':path,'length_a':len(a),'length_b':len(b)})
        for i,(x,y) in enumerate(zip(a,b)):differences(x,y,path+'/'+str(i+1),out)
    elif a!=b:out.append({'path':path,'a':str(a)[:180],'b':str(b)[:180]})
    return out
first=entries[0]['evidence']
for index,entry in enumerate(entries[1:],2):
    e=entry['evidence']
    for key in ('common_worlds','before_finishing'):
        out=differences(first.get(key),e.get(key))
        print(json.dumps({'comparison':index,'field':key,'differences':len(out),'first50':out[:50]}))
