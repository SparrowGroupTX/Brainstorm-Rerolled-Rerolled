#!/usr/bin/env python3
"""Bounded Jokerless opening model/search and original-source mechanics probes.

Never launches Balatro.exe: source is read only as a ZIP and Lua runs in an
isolated lua51.dll state. Every invocation registers immutable inputs before
its one-use child. This tool does not play a blind or inspect saves.
"""
from __future__ import annotations
import argparse
import ctypes
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2]
INSTALL=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
AUTH=ROOT/'tools/advisor_eval/runs/jokerless271_push_20260912_214242/authorization.json'
MODEL='Brainstorm/Core/jokerless_opening.lua'

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def literal(data):
    if isinstance(data,str): data=data.encode()
    eq=b'='
    while b']'+eq+b']' in data: eq+=b'='
    return b'['+eq+b'['+data+b']'+eq+b']'
def lua_value(v):
    if v is None:return b'nil'
    if isinstance(v,bool):return b'true' if v else b'false'
    if isinstance(v,str):return literal(v)
    if isinstance(v,(int,float)):return str(v).encode()
    if isinstance(v,list):return b'{'+b','.join(lua_value(x) for x in v)+b'}'
    return b'{'+b','.join(b'[ '+lua_value(k)+b' ]='+lua_value(x) for k,x in v.items())+b'}'

def worker(request_path):
    request=json.loads(request_path.read_text(encoding='utf-8'));out=request_path.parent
    authority_path=Path(request['authorization'])
    if sha(authority_path)!=request['authorization_sha256']:raise ValueError('Authorization changed')
    authority=read_authority(authority_path)
    require_worker_time(authority,request['timeout_seconds'])
    for name,digest in request['frozen_files'].items():
        if sha(out/'frozen'/name)!=digest:raise ValueError('Frozen file changed: '+name)
    install=Path(request['install'])
    if sha(install/'lua51.dll')!=request['runtime_sha256']:raise ValueError('Lua runtime changed')
    base=[]
    if request['kind']=='source':
        if sha(install/'Balatro.exe')!=request['executable_sha256']:raise ValueError('Source ZIP changed')
        with zipfile.ZipFile(install/'Balatro.exe') as archive:
            sources={name:archive.read(name) for name in archive.namelist() if name.endswith('.lua')}
            dimensions={}
            for name in archive.namelist():
                if name.endswith('.png'):
                    with archive.open(name) as stream:header=stream.read(24)
                    if header[:8]==b'\x89PNG\r\n\x1a\n':dimensions[name]=list(struct.unpack('>II',header[16:24]))
        base=[b'PROBE_PNG='+lua_value(dimensions)]
        for name,source in sources.items():
            base.append(b'package.preload[ '+literal(name[:-4])+b' ]=assert(loadstring('+literal(source)+b','+literal('@source/'+name)+b'))')
        profile={'schema':1,'name':request['profile'],'scope':['P_CENTERS','P_TAGS','P_SEALS','P_BLINDS']}
        base += [b'PROBE_PROFILE_SPEC='+lua_value(profile),b'PROBE_CHALLENGE="c_jokerless_1"',
                 b'PROBE_SEED='+lua_value(request['seed']),
                 b'PROBE_RECORD_PROFILE=function(text) PROBE_UNLOCK_PROFILE_TEXT=text;return 1 end']
    model=out/'frozen'/MODEL
    if model.exists():base += [b'package.preload.jokerless_opening=assert(loadstring('+literal(model.read_bytes())+b',"@frozen/jokerless_opening.lua"))']
    payload=(out/'frozen/payload.lua').read_bytes()
    if request['kind']=='source':
        base += [b'PROBE_EPISODE='+literal(payload),(out/'frozen/engine_probe.lua').read_bytes()]
    else:base += [b'SEARCH_REQUEST='+lua_value(request['options']),payload]
    code=b'\n'.join(base)
    lua=ctypes.CDLL(str(install/'lua51.dll'))
    lua.luaL_newstate.restype=ctypes.c_void_p
    lua.luaL_openlibs.argtypes=[ctypes.c_void_p]
    lua.luaL_loadbuffer.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
    lua.luaL_loadbuffer.restype=ctypes.c_int
    lua.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
    lua.lua_pcall.restype=ctypes.c_int
    lua.lua_getfield.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_char_p]
    lua.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype=ctypes.c_void_p
    lua.lua_close.argtypes=[ctypes.c_void_p]
    state=lua.luaL_newstate()
    def text_at(index):
        size=ctypes.c_size_t();ptr=lua.lua_tolstring(state,index,ctypes.byref(size))
        return ctypes.string_at(ptr,size.value).decode('utf-8','replace') if ptr else None
    try:
        lua.luaL_openlibs(state)
        status=lua.luaL_loadbuffer(state,code,len(code),b'@registered_jokerless_probe')
        if not status:status=lua.lua_pcall(state,0,0,0)
        reason=text_at(-1) if status else None
        lua.lua_getfield(state,-10002,b'PROBE_UNLOCK_PROFILE_TEXT');profile=text_at(-1)
        if profile:
            (out/'profile.txt').write_text(profile,encoding='utf-8')
            print(json.dumps({'type':'applied_synthetic_profile','name':request['profile'],
                'sha256':hashlib.sha256(profile.encode()).hexdigest(),'qualification':False}),flush=True)
        lua.lua_getfield(state,-10002,b'PROBE_RESULT_JSON');result=text_at(-1)
        if result:
            parsed=json.loads(result);(out/'result.json').write_text(json.dumps(parsed,indent=2)+'\n',encoding='utf-8')
            print(json.dumps({'type':'bounded_result','result':parsed}),flush=True)
        if status:raise RuntimeError(reason)
        if not result:raise RuntimeError('Worker returned no complete structured result')
    finally:lua.lua_close(state)

def read_authority(path):
    authority=json.loads(path.read_text(encoding='utf-8'))
    allowance=authority['allowances']['seed_search_agent']
    expected={'source_mechanical_workers':12,'per_mechanical_seconds':15,
              'mechanical_seconds_total':180,'seed_search_seconds_total':300}
    if allowance!=expected:raise ValueError('Unexpected authorization')
    resumed=authority.get('resumes_authorization')
    if resumed:
        previous=Path(resumed)
        if not previous.is_absolute():previous=path.parent/previous.name
        if sha(previous)!=authority.get('resumes_authorization_sha256'):raise ValueError('Original authorization changed')
        original=json.loads(previous.read_text(encoding='utf-8'))
        if authority['allowances']!=original['allowances']:raise ValueError('Resumed authorization changed shared allowances')
        if previous.parent.resolve()!=path.parent.resolve():raise ValueError('Resumed authorization must share its original ledger')
        for name,digest in authority.get('existing_registrations_at_resume',{}).items():
            if sha(path.parent/name)!=digest:raise ValueError('Previously registered request changed')
    return authority

def require_worker_time(authority,seconds,now=None):
    deadline=datetime.fromisoformat(authority['worker_deadline_utc'])
    if deadline.tzinfo is None:raise ValueError('Worker deadline must include its UTC offset')
    now=now or datetime.now(timezone.utc)
    if now+timedelta(seconds=seconds)>deadline:raise ValueError('Complete worker lease does not fit before deadline')

def register(args):
    authority=read_authority(args.authorization)
    require_worker_time(authority,args.seconds)
    entries=[]
    for path in args.authorization.parent.glob('seed_*/request.json'):
        item=json.loads(path.read_text(encoding='utf-8'))
        if item.get('owner')=='seed_search_agent':entries.append(item)
    if args.kind=='source':
        if args.seconds>15 or sum(x['kind']=='source' for x in entries)>=12:raise ValueError('Source-worker allowance exhausted')
    elif args.seconds+sum(x['timeout_seconds'] for x in entries if x['kind']=='search')>300:raise ValueError('Search allowance exhausted')
    if args.output.parent.resolve()!=args.authorization.parent.resolve() or not args.output.name.startswith('seed_'):
        raise ValueError('Fresh output must be seed_* under the authorization directory')
    args.output.mkdir(exist_ok=False);frozen=args.output/'frozen';frozen.mkdir()
    files={'runner.py':Path(__file__),'payload.lua':args.payload}
    if (ROOT/MODEL).exists():files[MODEL]=ROOT/MODEL
    if args.kind=='source':files['engine_probe.lua']=ROOT/'tools/advisor_eval/engine_probe.lua'
    hashes={}
    for name,path in files.items():
        target=frozen/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target);hashes[name]=sha(target)
    request={'schema':1,'owner':'seed_search_agent','kind':args.kind,'authorization':str(args.authorization.resolve()),
        'authorization_sha256':sha(args.authorization),'timeout_seconds':args.seconds,'install':str(args.install),
        'runtime_sha256':sha(args.install/'lua51.dll'),'executable_sha256':sha(args.install/'Balatro.exe'),
        'profile':args.profile,'seed':args.seed,'options':json.loads(args.options),'frozen_files':hashes,
        'scope':'opening_mechanics_no_blind_play_no_save_no_game_process','qualification':False,
        'registered_utc':datetime.now(timezone.utc).isoformat()}
    path=args.output/'request.json';path.write_text(json.dumps(request,indent=2)+'\n',encoding='utf-8')
    (args.output/'started.json').write_text(json.dumps({'one_use':True,'request_sha256':sha(path)})+'\n',encoding='utf-8')
    started=time.perf_counter()
    with (args.output/'stdout.log').open('w',encoding='utf-8') as stdout,(args.output/'stderr.log').open('w',encoding='utf-8') as stderr:
        try:
            completed=subprocess.run([sys.executable,str(frozen/'runner.py'),'_worker',str(path.resolve())],
                cwd=ROOT,stdout=stdout,stderr=stderr,timeout=args.seconds)
            status='complete' if completed.returncode==0 else 'error';code=completed.returncode
        except subprocess.TimeoutExpired:status='timeout';code=None
    record={'status':status,'returncode':code,'wall_seconds':time.perf_counter()-started,
        'frozen_unchanged':all(sha(frozen/n)==d for n,d in hashes.items()),
        'stdout_sha256':sha(args.output/'stdout.log'),'stderr_sha256':sha(args.output/'stderr.log'),
        'lease_spent':True,'source_worker':args.kind=='source','qualification':False}
    (args.output/'record.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record,indent=2));print((args.output/'stderr.log').read_text(encoding='utf-8'))
    return 0 if status=='complete' else 1

def main():
    if len(sys.argv)==3 and sys.argv[1]=='_worker':worker(Path(sys.argv[2]));return 0
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('kind',choices=['source','search']);p.add_argument('--payload',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--seconds',type=int,required=True)
    p.add_argument('--authorization',type=Path,default=AUTH);p.add_argument('--install',type=Path,default=INSTALL)
    p.add_argument('--seed',default='J2710001');p.add_argument('--profile',choices=['source_defaults_v1','all_unlocked_discovered_v1'],default='all_unlocked_discovered_v1')
    p.add_argument('--options',default='{}')
    args=p.parse_args()
    if args.seconds<1 or args.seconds>300:p.error('seconds must be1..300')
    return register(args)
if __name__=='__main__':raise SystemExit(main())
