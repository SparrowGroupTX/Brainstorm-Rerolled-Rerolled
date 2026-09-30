"""One-use429 offline A/B, with separately capped isolated Lua workers."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, ctypes, hashlib, importlib.util, json, os, subprocess, sys, time

HERE=Path(__file__).resolve().parent

def read(p): return json.loads(Path(p).read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,x):
    with Path(p).open('x',encoding='utf-8') as f: json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def now(): return datetime.now(timezone.utc).isoformat()
def verify():
    m=read(HERE/'manifest.json')
    for path,h in m['files'].items():
        if sha(path)!=h: raise ValueError('Frozen input changed: '+path)
    if sys.version!=m['python_version']: raise ValueError('Python version changed')
    return m

def evaluate(job,m):
    spec=importlib.util.spec_from_file_location('frozen_literal',HERE/'frozen/literal.py')
    helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    def literal(raw):
        raw=raw.encode() if isinstance(raw,str) else raw
        return b'"'+b''.join(bytes([c]) if 32<=c<127 and c not in (34,92) else ('\\%03d'%c).encode() for c in raw)+b'"'
    helper.literal=literal
    chunks=[b'local sources={}']
    for name,path in m['policies'][job['policy']]['modules'].items():
        raw=Path(path).read_bytes()
        # Preserve CR bytes without a thousands-deep right-associative Lua
        # concatenation expression. Flat bounded string pieces retain exact bytes.
        encoded=b'table.concat({'+b','.join(helper.literal(raw[i:i+256]) for i in range(0,len(raw),256))+b'})'
        chunks.append(b'sources[ '+helper.literal(name)+b' ]='+encoded)
    chunks.append(b'''package.path='';package.cpath='';package.loaders={}
io=nil;dofile=nil;loadfile=nil;os={clock=os.clock}
local cache={}
local function module(name)
 if cache[name] then return cache[name] end
 local code=assert(sources[name],'Missing frozen module '..name)
 local value=assert(loadstring(code,'@frozen/'..name..'.lua'))()
 cache[name]=value;return value
end
local A={}
''')
    chunks.append((HERE/'frozen/module_setup.lua').read_bytes())
    chunks.append(b'local INPUT='+helper.lua_value(job))
    chunks.append((HERE/'frozen/driver.lua').read_bytes())
    source=b'\n'.join(chunks)
    lib=ctypes.CDLL(str(HERE/'frozen/lua51.dll'))
    lib.luaL_newstate.restype=ctypes.c_void_p
    lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
    lib.luaL_loadbuffer.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
    lib.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
    lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
    lib.lua_tolstring.restype=ctypes.c_void_p;lib.lua_close.argtypes=[ctypes.c_void_p]
    state=lib.luaL_newstate()
    if not state: raise RuntimeError('Lua allocation failed')
    try:
        lib.luaL_openlibs(state)
        status=lib.luaL_loadbuffer(state,source,len(source),b'@evaluation429')
        if status==0: status=lib.lua_pcall(state,0,1,0)
        length=ctypes.c_size_t();ptr=lib.lua_tolstring(state,-1,ctypes.byref(length))
        result=ctypes.string_at(ptr,length.value).decode('utf-8','replace') if ptr else ''
        if status: raise RuntimeError(result)
        return json.loads(result)
    finally: lib.lua_close(state)

def worker(key):
    m=verify();jobs=read(HERE/'jobs.json');job=jobs[key]
    assert (HERE/'ledger'/f'{key}.started.json').exists(),'Unclaimed job'
    save(HERE/'ledger'/f'{key}.worker.json',{'started_utc':now(),'one_use':True})
    print(json.dumps(evaluate(job,m),allow_nan=False),flush=True)

def execute():
    m=verify();jobs=read(HERE/'jobs.json')
    save(HERE/'EXECUTION_STARTED.json',{'at':now(),'manifest_sha256':sha(HERE/'manifest.json'),
        'user_authority':m['authorization'],'one_use':True,'no_replacements':True})
    started=time.monotonic();reports=[]
    for stage,seconds in [('decision',660),('continuation',240)]:
        began=time.monotonic();stage_deadline=min(started+900,began+seconds)
        for key in m['job_order'][stage]:
            job=jobs[key];cap=10 if stage=='decision' else 20
            if time.monotonic()+cap>stage_deadline:
                row={'job':key,'status':'not_started','reason':'stage_deadline','mode':stage,'case':job['case'],'policy':job['policy']}
                save(HERE/'results'/f'{key}.json',row);reports.append(row);continue
            # One fixed ledger prevents reruns under another output directory.
            save(HERE/'ledger'/f'{key}.started.json',{'at':now(),'cap_seconds':cap,'manifest_sha256':sha(HERE/'manifest.json')})
            log=HERE/'results'/f'{key}.log';tick=time.monotonic()
            with log.open('x',encoding='utf-8') as f:
                try:
                    code=subprocess.run([sys.executable,'-B','-u',str(HERE/'run.py'),'--worker',key],
                        stdout=f,stderr=subprocess.STDOUT,timeout=cap,
                        creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0)|getattr(subprocess,'BELOW_NORMAL_PRIORITY_CLASS',0)).returncode
                except subprocess.TimeoutExpired: code='timeout'
            row={'job':key,'mode':stage,'case':job['case'],'policy':job['policy'],'exit_code':code,
                'seconds':time.monotonic()-tick,'log_sha256':sha(log),'status':'error'}
            if code=='timeout': row['status']='timeout'
            elif code==0:
                try: row['result']=read(log);row['status']='complete'
                except ValueError as e: row['reason']=str(e)
            save(HERE/'results'/f'{key}.json',row);reports.append(row)
            if len(reports)%16==0: print(json.dumps({'stage':stage,'finished':len(reports),'seconds':round(time.monotonic()-started,2)}),flush=True)
    verify()
    save(HERE/'CLOSED.json',{'at':now(),'seconds':time.monotonic()-started,'jobs':len(reports),
        'remaining_authority':0,'allowance_closed':True,'no_auto_resume':True,'frozen_inputs_unchanged':True,
        'counts':{status:sum(r['status']==status for r in reports) for status in ('complete','error','timeout','not_started')}})
    print(json.dumps(read(HERE/'CLOSED.json')),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();g=p.add_mutually_exclusive_group(required=True)
    g.add_argument('--worker');g.add_argument('--execute',action='store_true');g.add_argument('--preflight',action='store_true')
    a=p.parse_args()
    if a.worker: worker(a.worker)
    elif a.preflight:
        # Only explicitly invented inputs, before any public-policy evaluation.
        m=verify();jobs=read(HERE/'manufactured.json')
        values=[evaluate(j,m) for j in jobs]
        assert all(v['input_unchanged'] for v in values)
        assert values[0]['decision']['action']['kind'] in ('play','reorder_hand')
        assert values[1]['decision']['action']['kind']=='discard'
        assert len(values[1]['decision']['action']['indices'])==5
        assert values[2]['status']=='supported_clear' and values[3]['status']=='supported_clear'
        assert values[3]['discards']>values[2]['discards']
        print(json.dumps({'manufactured_checks':'passed','results':values},allow_nan=False))
    else: execute()
