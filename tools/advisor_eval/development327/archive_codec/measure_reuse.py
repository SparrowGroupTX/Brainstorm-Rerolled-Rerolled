"""Bounded read-only metrics from the parent's frozen public-log copies."""
import hashlib
import importlib.util
import json
from pathlib import Path
import time

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('reader',ROOT/'tools/advisor_eval/read_player_log.py')
reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
started=time.monotonic();paths=sorted((OUT.parent/'captured_logs').glob('*.brj'))
assert len(paths)<=8 and sum(p.stat().st_size for p in paths)<=64*1024*1024
result={'scope':'Frozen repository public-log copies only; no new gameplay or policy execution.',
        'caps':{'files':8,'wire_bytes':64*1024*1024,'decoded_bytes':512*1024*1024,'events':12000,'seconds':45},
        'files':[],'events':0,'decoded_bytes':0,'fingerprint_fields':0,'fingerprint_bytes':0,
        'two_slot_hits':0,'two_slot_hit_bytes':0,'two_slot_misses':0,'two_slot_miss_bytes':0,
        'unique_strings':0,'cross_field_hits':0,'same_field_hits':0}
unique=set()
for path in paths:
    slots=[]
    result['files'].append({'name':path.name,'size':path.stat().st_size,'sha256':reader.sha(path.read_bytes())})
    with path.open('rb') as stream:
        for raw,metadata in reader.records(stream):
            assert time.monotonic()-started<=45
            result['events']+=1;result['decoded_bytes']+=len(raw)
            assert result['events']<=12000 and result['decoded_bytes']<=512*1024*1024
            event=json.loads(raw);details=event.get('details',{})
            for field in ('after','before','fingerprint'):
                value=details.get(field) if isinstance(details,dict) else None
                if not isinstance(value,str) or len(value.encode('utf-8'))<4096:continue
                encoded=json.dumps(value,ensure_ascii=False,separators=(',',':')).encode('utf-8')
                key=hashlib.sha256(encoded).hexdigest();unique.add(key)
                result['fingerprint_fields']+=1;result['fingerprint_bytes']+=len(encoded)
                hit=next((entry for entry in slots if entry['key']==key),None)
                if hit:
                    result['two_slot_hits']+=1;result['two_slot_hit_bytes']+=len(encoded)
                    result['same_field_hits' if hit['field']==field else 'cross_field_hits']+=1
                    slots.remove(hit)
                else:
                    result['two_slot_misses']+=1;result['two_slot_miss_bytes']+=len(encoded)
                    if len(slots)==2:slots.pop(0)
                slots.append({'key':key,'field':field})
result['unique_strings']=len(unique)
result['elapsed_seconds']=time.monotonic()-started
result['limitation']='Reuse counts use exact JSON string encodings from the already captured observations; no runtime speedup or new compression size is measured.'
(OUT/'reuse_metrics.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='files'},indent=2))
