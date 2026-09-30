"""One-use ten targeted round continuations; no game, saves or original code."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timezone
import ctypes,hashlib,json,subprocess,sys,time
from evidence_reader import restore
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def now():return datetime.now(timezone.utc).isoformat()
def save(p,x):
 p.parent.mkdir(parents=True,exist_ok=True)
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def lua(x):
 if x is None:return 'nil'
 if isinstance(x,bool):return 'true'if x else'false'
 if isinstance(x,(int,float)):return repr(x)
 if isinstance(x,str):return '"'+''.join('\\%03d'%v for v in x.encode())+'"'
 if isinstance(x,list):return '{'+','.join(lua(v)for v in x)+'}'
 return '{'+','.join('['+lua(k)+']='+lua(v)for k,v in x.items())+'}'
def verify():
 m=read(HERE/'manifest.json')
 for rel,h in m['files'].items():assert sha(HERE/rel)==h,'Frozen input changed: '+rel
 for path in m['modules'].values():
  rel=Path(path).resolve().relative_to(HERE.resolve()).as_posix();assert rel in m['files']
 assert m['python_version']==sys.version and sha(sys.executable)==m['python_sha256']
 return m
def evaluate(job,m):
 sources={name:Path(path).read_text(encoding='utf-8')for name,path in m['modules'].items()}
 code='local sources='+lua(sources)+'''\npackage.path='';package.cpath='';package.loaders={}
io=nil;dofile=nil;loadfile=nil;os={clock=os.clock};math.random=function()error('Unregistered randomness')end
pseudorandom=math.random;pseudoseed=math.random
local cache={};local function module(name)
 if not cache[name]then cache[name]=assert(loadstring(assert(sources[name]),'@frozen/'..name..'.lua'))()end;return cache[name]
end
local A={}
'''+(HERE/'frozen/module_setup.lua').read_text()+'\nlocal Adapter=(function()\n'+(HERE/'frozen/continuation_adapter.lua').read_text()+'\nend)()\nAdapter.evidence=(function()\n'+(HERE/'frozen/continuation_evidence.lua').read_text()+'\nend)()\nreturn table.concat(assert(Adapter.run_frames(A,'+lua(job)+')))'
 raw=code.encode();lib=ctypes.CDLL(str(HERE/'frozen/lua51.dll'))
 lib.luaL_newstate.restype=ctypes.c_void_p;lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
 lib.luaL_loadbuffer.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
 lib.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
 lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)];lib.lua_tolstring.restype=ctypes.c_void_p
 lib.lua_close.argtypes=[ctypes.c_void_p];state=lib.luaL_newstate();assert state
 try:
  lib.luaL_openlibs(state);status=lib.luaL_loadbuffer(state,raw,len(raw),b'@targeted437')
  if not status:status=lib.lua_pcall(state,0,1,0)
  length=ctypes.c_size_t();ptr=lib.lua_tolstring(state,-1,ctypes.byref(length))
  result=ctypes.string_at(ptr,length.value).decode('utf-8','replace')if ptr else''
  if status:raise RuntimeError(result)
  return result
 finally:lib.lua_close(state)
def worker(key):
 m=verify();assert not(HERE/'CLOSED.json').exists()
 claim=read(HERE/'ledger'/f'{key}.started.json')
 assert claim['manifest_sha256']==sha(HERE/'manifest.json')==read(HERE/'EXECUTION_STARTED.json')['manifest_sha256']
 save(HERE/'ledger'/f'{key}.worker.json',{'at':now(),'one_use':True})
 job=read(HERE/'jobs.json')[key];job['snapshot']=read(HERE/'cases.json')[key]['snapshot']
 sys.stdout.write(evaluate(job,m));sys.stdout.flush()
def execute():
 m=verify();jobs=read(HERE/'jobs.json');reg=read(HERE/'registration.json')
 for path,h in m.get('source_files',{}).items():assert sha(path)==h,'Source changed: '+path
 assert len(jobs)==reg['max_jobs']==10 and reg['max_workers']==4 and reg['job_seconds']==40
 assert reg['reserved_seconds']==400 and reg['overall_seconds']==600
 assert read(HERE/'READY.json')['manifest_sha256']==sha(HERE/'manifest.json')
 assert not(HERE/'CLOSED.json').exists()
 save(HERE/'EXECUTION_STARTED.json',{'at':now(),'manifest_sha256':sha(HERE/'manifest.json'),'one_use':True,'reserved_seconds':400})
 start=time.monotonic();results={}
 def child(key):
  if time.monotonic()+40>start+600:
   row={'status':'not_started','reason':'overall time cap'}
  else:
   save(HERE/'ledger'/f'{key}.started.json',{'at':now(),'manifest_sha256':sha(HERE/'manifest.json'),'cap_seconds':40})
   log=HERE/'results'/f'{key}.jsonl';log.parent.mkdir(exist_ok=True);tick=time.monotonic()
   with log.open('x',encoding='utf-8')as f:
    try:code=subprocess.run([sys.executable,'-B','-u',str(HERE/'run.py'),'--worker',key],stdout=f,stderr=subprocess.STDOUT,timeout=40,
     creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0)|getattr(subprocess,'BELOW_NORMAL_PRIORITY_CLASS',0)).returncode
    except subprocess.TimeoutExpired:code='timeout'
   row={'status':'timeout'if code=='timeout'else'error','seconds':time.monotonic()-tick,'exit_code':code,'output_sha256':sha(log)}
   if code==0:
    try:row['result']=restore(log.read_text());row['status']='complete'
    except Exception as exc:row['reason']=str(exc)
  row['job']=key;save(HERE/'results'/f'{key}.json',row);return key,row
 error=None
 try:
  with ThreadPoolExecutor(max_workers=4)as pool:
   for key,row in pool.map(child,jobs):
    results[key]=row;print(json.dumps({'job':key,'status':row['status'],'model_status':row.get('result',{}).get('status')}),flush=True)
 except Exception as exc:error=repr(exc)
 finally:
  save(HERE/'CLOSED.json',{'at':now(),'elapsed_seconds':time.monotonic()-start,'registered':10,'reserved_seconds':400,
   'received':len(results),'remaining_authority':0,'retries':0,'resumption_permitted':False,'error':error})
 return 1 if error else 0
if __name__=='__main__':
 if len(sys.argv)==3 and sys.argv[1]=='--worker':worker(sys.argv[2])
 elif sys.argv[1:]==['--execute']:raise SystemExit(execute())
 else:raise SystemExit('Use explicit one-use --execute or claimed --worker')
