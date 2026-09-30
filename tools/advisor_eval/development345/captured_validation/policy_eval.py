"""Fresh registered one-use single-policy public shop evaluation. Import is inert."""
import ctypes
import hashlib
import json
from pathlib import Path
import sys
import time
from lua_bytes import literal,lua_value
from module_graph import module_setup

JOB_IDS=('B2070','C2070','B2192','C2192')
LIMITS={'policy_jobs':4,'seconds_per_policy_job':30,'total_worker_seconds':120,
        'shop_score_calls_per_job':50000,'source_jobs':0,'search_jobs':0,'complete_attempt_jobs':0}
MAX_BYTES=16*1024**2
HERE=Path(__file__).resolve().parent
def canonical(v): return json.dumps(v,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'),parse_constant=lambda v: (_ for _ in ()).throw(ValueError('Nonfinite JSON')))
def write(p,value):
    with Path(p).open('x',encoding='utf-8',newline='\n') as f: json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
def checked(ref):
    p=Path(ref['path']).resolve()
    if not p.is_file() or sha(p)!=ref['sha256']: raise ValueError('Changed registered file: '+str(p))
    return p
def verify(reg_path):
    reg=read(reg_path);job=reg.get('job_id');role='baseline' if str(job).startswith('B') else 'candidate'
    if (reg.get('kind')!='gold345_captured_policy_job' or reg.get('status')!='REGISTERED' or job not in JOB_IDS or
        reg.get('role')!=role or reg.get('timeout_seconds')!=30 or reg.get('score_cap')!=50000 or
        reg.get('source_execution') is not False or reg.get('action_dispatch') is not False or
        reg.get('certificate_refresh') is not False or reg.get('selected_action_rescore') is not False or
        reg.get('options')!='product_defaults_no_overrides' or reg.get('one_use') is not True):
        raise ValueError('Fresh exact registered single-policy shop scope required')
    authority=read(checked(reg['authority']))
    if (authority.get('kind')!='gold345_captured_shop_authority' or authority.get('status')!='AUTHORIZED' or
        authority.get('approved_by')!='user' or not authority.get('approval_text') or not authority.get('approval_reference') or
        authority.get('job_ids')!=list(JOB_IDS) or authority.get('limits')!=LIMITS or
        authority.get('serial_only') is not True or authority.get('no_replacements') is not True):
        raise ValueError('Fresh explicit root-frozen user authorization required')
    ledger=Path(authority['ledger_directory']).resolve()
    if reg_path.resolve()!=ledger/job/'registration.json' or (ledger/'CLOSED.json').exists():
        raise ValueError('Require unchanged active authority ledger and exact registration location')
    spent=read(ledger/job/'spent.json')
    if (spent.get('kind')!='gold345_captured_policy_spent' or spent.get('job_id')!=job or spent.get('one_use') is not True or
        spent.get('registration_sha256')!=sha(reg_path) or spent.get('authority_sha256')!=reg['authority']['sha256'] or
        spent.get('reserved_seconds')!=30): raise ValueError('Root one-use spent receipt required before launch')
    required=('policy_eval.py','driver.lua','module_graph.py','lua_bytes.py','launch_serial.py')
    if set(reg['adapter_files'])!=set(required): raise ValueError('Exact complete adapter freeze required')
    for name in required:
        p=checked(reg['adapter_files'][name])
        if p!=HERE/name: raise ValueError('Run exact registered adapter files')
    if not reg.get('source_references'): raise ValueError('Frozen preserved-source reference hashes required')
    for ref in reg['source_references']: checked(ref)
    if checked(reg['python'])!=Path(sys.executable).resolve(): raise ValueError('Wrong registered Python runtime')
    runtime=checked(reg['lua_runtime'])
    if runtime.name.lower()!='lua51.dll': raise ValueError('Isolated Lua runtime only')
    snapshot_path=checked(reg['snapshot']);snapshot=read(snapshot_path)
    provenance=read(checked(reg['input_provenance']));profile=read(checked(reg['profile']))
    if (snapshot.get('phase')!='shop' or provenance.get('kind')!='gold345_exact_public_snapshot' or
        provenance.get('snapshot_sha256')!=reg['snapshot']['sha256'] or provenance.get('certificate_refresh') is not False or
        provenance.get('anchor',{}).get('sequence')!=int(job[1:]) or
        hashlib.sha256(canonical(snapshot)).hexdigest()!=provenance.get('snapshot_canonical_sha256') or
        profile.get('kind')!='actual_passive_public_player_context' or profile.get('synthetic') is not False or
        profile.get('constructor_certificate_refresh') is not False or
        profile.get('snapshot_sha256')!=reg['snapshot']['sha256']): raise ValueError('Unchanged public input/profile required')
    if any(k in snapshot for k in ('retry_context','_retry','_retry_context','_shop_scoring','pseudorandom')):
        raise ValueError('Internal/retry/RNG state is not admitted')
    record=read(checked(reg['policy']['record']));policy=record['policy'];root=Path(reg['policy']['root']).resolve()
    if (policy.get('policy_digest')!=reg['policy']['policy_digest'] or
        hashlib.sha256(canonical(policy['policy_files'])).hexdigest()!=policy['policy_digest']):
        raise ValueError('Frozen complete policy manifest mismatch')
    for name,expected in policy['policy_files'].items():
        file=(root/name).resolve();file.relative_to(root)
        if sha(file)!=expected: raise ValueError('Changed frozen policy '+name)
    setup,omitted=module_setup((root/'Brainstorm/Advisor/runtime.lua').read_bytes())
    if sha(checked(reg['module_setup']))!=hashlib.sha256(setup).hexdigest(): raise ValueError('Runtime graph derivation mismatch')
    return reg,snapshot,(root,policy,setup,omitted),runtime,ledger/job

class Lua:
    def __init__(self,runtime,deadline):
        lib=self.lib=ctypes.CDLL(str(runtime));self.deadline=deadline
        lib.luaL_newstate.restype=ctypes.c_void_p
        lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
        lib.luaL_loadbuffer.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
        lib.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
        lib.lua_close.argtypes=[ctypes.c_void_p]
        lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)];lib.lua_tolstring.restype=ctypes.c_void_p
        lib.lua_pushcclosure.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int]
        lib.lua_pushnumber.argtypes=[ctypes.c_void_p,ctypes.c_double]
        lib.lua_pushboolean.argtypes=[ctypes.c_void_p,ctypes.c_int]
        lib.lua_setfield.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_char_p]
        callback=ctypes.CFUNCTYPE(ctypes.c_int,ctypes.c_void_p)
        @callback
        def clock(state): lib.lua_pushnumber(state,time.perf_counter());return 1
        @callback
        def expired(state): lib.lua_pushboolean(state,time.perf_counter()>=deadline);return 1
        self.clock,self.expired=clock,expired
    def evaluate(self,source):
        lib=self.lib;state=lib.luaL_newstate()
        if not state: raise RuntimeError('Could not allocate isolated Lua state')
        try:
            lib.luaL_openlibs(state)
            for key,fn in ((b'PROBE_MONOTONIC_SECONDS',self.clock),(b'PROBE_DEADLINE_EXCEEDED',self.expired)):
                lib.lua_pushcclosure(state,fn,0);lib.lua_setfield(state,-10002,key)
            status=lib.luaL_loadbuffer(state,source,len(source),b'@gold345_captured_shop')
            if not status: status=lib.lua_pcall(state,0,1,0)
            n=ctypes.c_size_t();pointer=lib.lua_tolstring(state,-1,ctypes.byref(n))
            if n.value>MAX_BYTES: raise RuntimeError('Detached output exceeded 16 MiB')
            raw=ctypes.string_at(pointer,n.value) if pointer else b''
            if status: raise RuntimeError(raw.decode('utf-8','replace')[:2048])
            return raw
        finally: lib.lua_close(state)

def build_source(snapshot,manifest):
    root,policy,setup,_=manifest
    chunks=[b'PROFILE_INPUT='+lua_value(snapshot),b'PROFILE_SCORE_CAP=50000',
      b'package.path="";package.cpath="";package.loaders={package.loaders[1]};io=nil;dofile=nil;loadfile=nil',
      b'os={clock=os.clock};math.random=function()error("RNG unavailable")end;math.randomseed=math.random',
      b'pseudorandom=math.random;pseudoseed=math.random;G=nil;Brainstorm=nil']
    for name in sorted(policy['policy_files']):
        if name.startswith('Brainstorm/Advisor/') and name.endswith('.lua'):
            p=root/name
            chunks.append(b'package.preload[ '+literal('probe_policy_'+p.stem)+b' ]=assert(loadstring('+literal(p.read_bytes())+b','+literal('@frozen/'+p.name)+b'))')
    return b'\n'.join(chunks+[setup,b'load=nil;loadstring=nil',(HERE/'driver.lua').read_bytes()])

def main():
    started=time.perf_counter();deadline=started+30
    reg_path=Path(sys.argv[1]).resolve();reg,snapshot,manifest,runtime,out=verify(reg_path)
    write(out/'worker_started.json',{'job_id':reg['job_id'],'one_use':True,'registration_sha256':sha(reg_path),'worker_limit_seconds':30})
    try:
        raw=Lua(runtime,deadline).evaluate(build_source(snapshot,manifest));result=json.loads(raw);summary=result['summary']
        summary.update(job_id=reg['job_id'],role=reg['role'],snapshot_sha256=reg['snapshot']['sha256'],policy_digest=manifest[1]['policy_digest'],
          full_result_sha256=hashlib.sha256(raw).hexdigest(),worker_elapsed_seconds=time.perf_counter()-started,
          certificate_refresh=False,profile_kind='actual_passive_public_player_context',runtime_setup_omissions=manifest[3])
        if sha(reg['snapshot']['path'])!=reg['snapshot']['sha256']: raise RuntimeError('Input file changed during evaluation')
        encoded=canonical(summary)
        if len(encoded)>65536 or len(encoded)+len(raw)>MAX_BYTES: raise RuntimeError('Combined output exceeded 16 MiB')
        with (out/'result.json').open('xb') as f: f.write(raw)
        with (out/'summary.json').open('xb') as f: f.write(encoded)
        print(json.dumps({k:summary.get(k) for k in ('job_id','status','action','score_calls','reported_evaluations','input_unchanged','full_result_status','full_result_sha256')}),flush=True)
        return 0 if summary['status']=='complete' and summary['input_unchanged'] else 2
    except Exception as error:
        write(out/'worker_error.json',{'job_id':reg['job_id'],'status':'timeout' if time.perf_counter()>=deadline else 'error',
          'error':str(error)[:2048],'worker_elapsed_seconds':time.perf_counter()-started,
          'snapshot_file_unchanged':sha(reg['snapshot']['path'])==reg['snapshot']['sha256']})
        raise
if __name__=='__main__': raise SystemExit(main())
