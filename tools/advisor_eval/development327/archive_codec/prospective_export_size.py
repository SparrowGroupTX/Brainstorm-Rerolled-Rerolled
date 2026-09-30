"""Bounded prospective public-export size analysis; existing logs remain exact."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import time

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module);return module
reader=load('prospective_archive_reader',ROOT/'tools/advisor_eval/read_player_log.py')
host=load('prospective_fixture_host',ROOT/'tests/test_advisor_player_log_archive.py')
def digest(raw):return hashlib.sha256(raw).hexdigest()
def literal(item):
    raw=item.encode('utf-8') if isinstance(item,str) else item
    if b'\r' in raw or raw.startswith(b'\n'):return host.literal(raw)
    marker=b'='
    while b']'+marker+b']' in raw:marker+=b'='
    return b'['+marker+b'['+raw+b']'+marker+b']'
def value(item):
    if item is None:return b'nil'
    if type(item) is bool:return b'true' if item else b'false'
    if type(item) in (int,float):assert math.isfinite(item);return str(item).encode()
    if isinstance(item,str):return literal(item)
    if isinstance(item,list):return b'{'+b','.join(value(v) for v in item)+b'}'
    if isinstance(item,dict):return b'{'+b','.join(b'[ '+value(k)+b' ]='+value(v) for k,v in item.items())+b'}'
    raise TypeError(type(item))
def canonical(item):return json.dumps(item,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
def opaque(item):
    result={'schema':1,'kind':'snapshot_fingerprint_sha256','status':'unavailable'}
    if not isinstance(item,str):result['reason']='invalid_fingerprint_type';return result
    raw=item.encode('utf-8');result.update(status='available',byte_length=len(raw),sha256=digest(raw));return result

paths=sorted((HERE.parent/'captured_logs').glob('*.brj'))
limits={'files':8,'wire_bytes':67108864,'decoded_bytes':536870912,'events':12000,'seconds':45}
assert len(paths)<=8 and sum(p.stat().st_size for p in paths)<=limits['wire_bytes']
plan={'scope':'Prospective public-export logging reencoding of already captured repository observations. Not a lossless replacement for historical logs; only declared internal identity strings are replaced with SHA256 and byte length. No policy, scoring, game or save execution.',
      'limits':limits,'paths':[p.name for p in paths],
      'transform_paths':['auto_run.details.fingerprint','auto_run.details.before','auto_run.details.after',
                         'auto_run.details.interrupted_action.fingerprint'],
      'schema':{'schema':1,'kind':'snapshot_fingerprint_sha256','status':'available','byte_length':'exact UTF-8/Lua source string byte length','sha256':'lowercase SHA256 of exact source string bytes'},
      'source_sha256':{p:digest((ROOT/p).read_bytes()) for p in ('Brainstorm/Core/auto_run_product.lua','Brainstorm/Advisor/player_log_archive.lua','Brainstorm/Advisor/player_journal.lua','tools/advisor_eval/read_player_log.py')},
      'no_original_mutations':True,'no_policy_or_game_execution':True}
with (HERE/'prospective_export_plan.json').open('x',encoding='utf-8') as file:json.dump(plan,file,indent=2);file.write('\n')
started=time.monotonic();destination=HERE/'prospective_export_outputs';destination.mkdir(exist_ok=True)
report={'plan_sha256':digest((HERE/'prospective_export_plan.json').read_bytes()),'events':0,'original_decoded_bytes':0,
        'prospective_decoded_bytes':0,'original_stored_bytes':0,'prospective_stored_bytes':0,
        'identity_fields_replaced':0,'source_identity_string_bytes':0,'files':[],'complete':False,'errors':[]}
lua=host.Lua()
try:
    lua.evaluate('S={};return "ready"')
    for path in paths:
        expected=[];output=destination/path.name
        with path.open('rb') as stream,output.open('xb') as target:
            for raw,metadata in reader.records(stream):
                assert time.monotonic()-started<=45,'Wall-time cap reached'
                report['events']+=1;report['original_decoded_bytes']+=len(raw)
                assert report['events']<=12000 and report['original_decoded_bytes']<=512*1024*1024
                if not expected:
                    lua.evaluate(b'S.last=nil;S.session='+value(metadata['session'])+b';S.segment='+value(metadata['segment'])+b';return "boundary"')
                event=json.loads(raw);details=event.get('details',{})
                if event.get('kind')=='auto_run' and isinstance(details,dict):
                    containers=[(details,key) for key in ('fingerprint','before','after') if key in details]
                    interrupted=details.get('interrupted_action')
                    if isinstance(interrupted,dict) and 'fingerprint' in interrupted:containers.append((interrupted,'fingerprint'))
                    for container,key in containers:
                        item=container[key];report['identity_fields_replaced']+=1
                        if isinstance(item,str):report['source_identity_string_bytes']+=len(item.encode('utf-8'))
                        container[key]=opaque(item)
                expected.append(digest(canonical(event)))
                wire=lua.evaluate(b'local event='+value(event)+b''';local original=assert(J.encode(event));
                    local bytes,next_state=A.frame({encode=J.encode,encode_frame=J.encode_frame,
                    hash=HOST_HASH,compress=HOST_COMPRESS,decompress=HOST_DECOMPRESS},event,original,S);
                    next_state.session=S.session;next_state.segment=S.segment;S=next_state;return bytes''')
                target.write(wire)
        actual=[]
        with output.open('rb') as stream:
            for raw,metadata in reader.records(stream):
                actual.append(digest(canonical(json.loads(raw))));report['prospective_decoded_bytes']+=len(raw)
                assert metadata['format']==2
        assert actual==expected,'Prospective output changed undeclared values'
        old=path.stat().st_size;new=output.stat().st_size
        report['original_stored_bytes']+=old;report['prospective_stored_bytes']+=new
        report['files'].append({'name':path.name,'events':len(expected),'source_sha256':digest(path.read_bytes()),
            'derived_sha256':digest(output.read_bytes()),'original_stored_bytes':old,'prospective_stored_bytes':new,
            'declared_transform_only_verified':True})
    assert time.monotonic()-started<=45,'Wall-time cap reached'
    report['complete']=True
except Exception as error:
    report['errors'].append(type(error).__name__+': '+str(error));raise
finally:
    lua.close();report['elapsed_seconds']=time.monotonic()-started
    report['limits']=limits
    report['limitations']='Offline prospective export-size sample; internal serialized identity strings are deliberately replaced by opaque identity records. This is not a lossless old-log replacement, runtime CPU measurement, gameplay result or policy evaluation. All original captured observations remain preserved.'
    (HERE/'prospective_export_size.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
