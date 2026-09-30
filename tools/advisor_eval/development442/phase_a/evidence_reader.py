"""Read bounded full graph receipts. Never executes Lua/policy/game code."""
import json,math
SCHEMA='advisor_evidence_graph_v1'
def restore(raw):
 if len(raw.encode())>67108864:raise ValueError('Evidence byte bound')
 frames=[json.loads(line)for line in raw.splitlines()if line.strip()]
 h,z=frames[0],frames[-1];count=h['node_count']
 assert h['schema']==z['schema']==SCHEMA and h['kind']=='header'and z['kind']=='end'and z['complete']is True
 assert type(count)is int and 0<=count<=25000 and h['fields_omitted']==0
 assert z['node_count']==count and z['entry_count']==h['entry_count']
 records=[]
 for p in frames[1:-1]:
  assert p['schema']==SCHEMA and p['kind']=='nodes'and p['first']==len(records)+1 and 1<=len(p['nodes'])<=16
  for node in p['nodes']:
   assert node['id']==len(records)+1 and len(node['fields'])<=2048;records.append(node)
 assert len(records)==count
 built={};active=set();entries=0
 def decode(v,depth=0):
  nonlocal entries
  assert depth<=64
  if v['kind']=='ref':
   i=v['id'];assert type(i)is int and 1<=i<=count and i not in active
   if i in built:return built[i]
   active.add(i);out={}
   for f in records[i-1]['fields']:
    entries+=1;assert entries<=500000
    k=decode(f['key'],depth+1);assert type(k)in(str,int,float)and k not in out
    out[k]=decode(f['value'],depth+1)
   if out and all(type(k)is int and 1<=k<=len(out)for k in out):out=[out[k]for k in range(1,len(out)+1)]
   active.remove(i);built[i]=out;return out
  k=v['kind'];x=v.get('value')
  assert k=='nil'and x is None or k=='string'and type(x)is str and len(x.encode())<=262144 or k=='boolean'and type(x)is bool or k=='number'and type(x)in(int,float)and math.isfinite(x)
  return x
 result=decode(h['root']);assert entries==h['entry_count']and len(built)==count
 return result
