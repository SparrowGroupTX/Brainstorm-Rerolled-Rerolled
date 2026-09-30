"""Bounded lossless codec validation over fixed public-log copies; no game code."""
import importlib.util
import json
import math
from pathlib import Path
import time
import io

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
reader=load('captured_codec_reader',HERE/'files/tools/advisor_eval/read_player_log.py')
host=load('captured_codec_fixture_host',ROOT/'tests/test_advisor_player_log_archive.py')
def literal(value):
    raw=value.encode('utf-8') if isinstance(value,str) else value
    if b'\r' in raw or raw.startswith(b'\n'):
        return host.literal(raw)
    marker=b'='
    while b']'+marker+b']' in raw:marker+=b'='
    return b'['+marker+b'['+raw+b']'+marker+b']'
def value(item):
    if item is None:return b'nil'
    if type(item) is bool:return b'true' if item else b'false'
    if type(item) in (int,float):
        assert math.isfinite(item);return str(item).encode()
    if isinstance(item,str):return literal(item)
    if isinstance(item,list):return b'{'+b','.join(value(v) for v in item)+b'}'
    if isinstance(item,dict):return b'{'+b','.join(b'[ '+value(k)+b' ]='+value(v) for k,v in item.items())+b'}'
    raise TypeError(type(item))

started=time.monotonic();paths=sorted((HERE.parent/'captured_logs').glob('*.brj'))
assert len(paths)<=8 and sum(p.stat().st_size for p in paths)<=64*1024*1024
destination=HERE/'roundtrip_outputs2';destination.mkdir(exist_ok=True)
report={'scope':'Codec-only transformation of frozen repository public observation copies; no source, policy, scoring, game, save or profile execution.',
        'caps':{'files':8,'wire_bytes':67108864,'decoded_bytes':536870912,'events':12000,'seconds':45},
        'events':0,'decoded_bytes':0,'original_stored_bytes':0,'candidate_stored_bytes':0,'files':[],
        'complete':False,'errors':[]}
lua=host.Lua()
try:
    lua.evaluate(b'A=dofile('+literal(str(HERE/'files/Brainstorm/Advisor/player_log_archive.lua').replace('\\','/'))+b');S={};return "loaded"')
    for path in paths:
        assert time.monotonic()-started<=45,'Wall-time cap reached'
        originals=[];output=destination/path.name
        old_size=path.stat().st_size
        with path.open('rb') as stream,output.open('xb') as target:
            for raw,metadata in reader.records(stream):
                assert time.monotonic()-started<=45,'Wall-time cap reached'
                report['events']+=1;report['decoded_bytes']+=len(raw)
                assert report['events']<=12000 and report['decoded_bytes']<=512*1024*1024
                if not originals:
                    lua.evaluate(b'S.slots=nil;S.recent=nil;S.session='+value(metadata['session'])+
                                 b';S.segment='+value(metadata['segment'])+b';return "boundary"')
                event=json.loads(raw)
                wire=lua.evaluate(b'local event='+value(event)+b';local original='+literal(raw)+b''';
                    local bytes,next_state=A.frame({encode=J.encode,encode_frame=J.encode_frame,
                    hash=HOST_HASH,compress=HOST_COMPRESS,decompress=HOST_DECOMPRESS},event,original,S);
                    next_state.session=S.session;next_state.segment=S.segment;S=next_state;return bytes''')
                target.write(wire);originals.append(reader.sha(raw))
        with output.open('rb') as stream:
            decoded=[reader.sha(raw) for raw,_ in reader.records(stream)]
        assert decoded==originals,'Reconstructed event hashes differ'
        file_result={'name':path.name,'events':len(originals),'original_stored_bytes':old_size,
                     'candidate_stored_bytes':output.stat().st_size,'source_sha256':reader.sha(path.read_bytes()),
                     'candidate_sha256':reader.sha(output.read_bytes()),'exact_event_hashes_equal':True}
        report['files'].append(file_result)
        report['original_stored_bytes']+=old_size;report['candidate_stored_bytes']+=output.stat().st_size
    assert time.monotonic()-started<=45,'Wall-time cap reached'
    report['complete']=True
except Exception as error:
    report['errors'].append(type(error).__name__+': '+str(error));raise
finally:
    lua.close();report['elapsed_seconds']=time.monotonic()-started
    report['limitations']='Offline codec-only output comparison, not live CPU, frame-time, gameplay, strategy or win-rate evidence. Captured originals and derived output files are preserved.'
    (HERE/'captured_roundtrip2.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='files'},indent=2))
