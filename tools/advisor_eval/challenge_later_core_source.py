"""Bounded Core admission against original challenge starts, without native search.

Reads the executable ZIP and invokes only isolated lua51.dll. No executable
launch, saves, played blinds or win-rate qualification. Run in a capped worker.
"""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import struct
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2]
IDS='omelette city rich knife xray mad_world luxury non_perishable medusa double_nothing typecast inflation fragile monolith blast_off five_card golden_needle cruelty'.split()
def literal(data):
    sep=b'='
    while b']'+sep+b']' in data: sep+=b'='
    return b'['+sep+b'['+data+b']'+sep+b']'
def sha(data): return hashlib.sha256(data).hexdigest()
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--install',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro'))
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False);started=time.monotonic()
    with zipfile.ZipFile(a.install/'Balatro.exe') as z:
        sources={name:z.read(name) for name in z.namelist() if name.endswith('.lua')}
        dimensions={}
        for name in z.namelist():
            if name.endswith('.png'):
                with z.open(name) as png: header=png.read(24)
                if header[:8]==b'\x89PNG\r\n\x1a\n': dimensions[name]=struct.unpack('>II',header[16:24])
    core=(ROOT/'Brainstorm/Core/challenge_opening.lua').read_bytes()
    bootstrap=(ROOT/'tools/advisor_eval/engine_probe.lua').read_bytes()
    payload=Path(__file__).with_suffix('.lua').read_bytes()
    for name,data in [('challenge_opening.lua',core),('engine_probe.lua',bootstrap),('payload.lua',payload),('probe.py',Path(__file__).read_bytes())]: (a.output/name).write_bytes(data)
    provenance=dict(scope='original_source_fresh_start_admission_no_search_no_gameplay_no_win_evidence',
        core_sha256=sha(core),bootstrap_sha256=sha(bootstrap),payload_sha256=sha(payload),driver_sha256=sha(Path(__file__).read_bytes()),
        runtime_sha256=sha((a.install/'lua51.dll').read_bytes()),source_sha256={k:sha(v) for k,v in sources.items()},
        max_cases=36,profiles=['source_defaults_v1','all_unlocked_discovered_v1'],seed='I1L21111')
    (a.output/'provenance.json').write_text(json.dumps(provenance,indent=2))
    base=[b'PROBE_PNG={}']
    for name,(w,h) in dimensions.items(): base.append(b'PROBE_PNG[ '+literal(name.encode())+b']={'+str(w).encode()+b','+str(h).encode()+b'}')
    for name,source in sources.items(): base.append(b'package.preload[ '+literal(name[:-4].encode())+b']=assert(loadstring('+literal(source)+b','+literal(b'@original/'+name.encode())+b'))')
    base += [b'PROBE_CORE='+literal(core),b'PROBE_EPISODE='+literal(payload),b'PROBE_SEED="I1L21111"',
        b'PROBE_RECORD_PROFILE=function(text)PROBE_DECLARED_PROFILE_TEXT=text;return 1 end']
    lua=ctypes.CDLL(str((a.install/'lua51.dll').resolve()));lua.luaL_newstate.restype=ctypes.c_void_p
    for fn in ('luaL_openlibs','lua_close'): getattr(lua,fn).argtypes=[ctypes.c_void_p]
    lua.luaL_loadbuffer.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p];lua.luaL_loadbuffer.restype=ctypes.c_int
    lua.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int];lua.lua_pcall.restype=ctypes.c_int
    lua.lua_getfield.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_char_p]
    lua.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)];lua.lua_tolstring.restype=ctypes.c_void_p
    def text_at(state,key=None):
        if key: lua.lua_getfield(state,-10002,key.encode())
        n=ctypes.c_size_t();ptr=lua.lua_tolstring(state,-1,ctypes.byref(n))
        return ctypes.string_at(ptr,n.value).decode('utf8','replace') if ptr else ''
    results=[]
    for challenge in IDS:
        for mode in ('source_defaults_v1','all_unlocked_discovered_v1'):
            cid='c_'+challenge+'_1';record=dict(challenge=cid,profile=mode,status='started');path=a.output/(cid+'_'+mode+'.json');path.write_text(json.dumps(record))
            code=b'\n'.join(base+[b'PROBE_CHALLENGE='+literal(cid.encode()),b'PROBE_PROFILE_SPEC={schema=1,name='+literal(mode.encode())+b",scope={'P_CENTERS','P_TAGS','P_BLINDS'}}",bootstrap])
            state=lua.luaL_newstate();assert state
            try:
                lua.luaL_openlibs(state);status=lua.luaL_loadbuffer(state,code,len(code),b'@challenge_later_core_source')
                if not status: status=lua.lua_pcall(state,0,0,0)
                if status: raise RuntimeError(text_at(state))
                record.update(status='passed',admission=text_at(state,'PROBE_CORE_ADMISSION'),profile_sha256=sha(text_at(state,'PROBE_DECLARED_PROFILE_TEXT').encode()))
            except BaseException as e:
                record.update(status='error',error=repr(e));raise
            finally:
                lua.lua_close(state);path.write_text(json.dumps(record,indent=2))
            results.append(record)
    summary=dict(status='passed',cases=len(results),seconds=time.monotonic()-started,scope=provenance['scope'])
    (a.output/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary),flush=True)
if __name__=='__main__': main()
