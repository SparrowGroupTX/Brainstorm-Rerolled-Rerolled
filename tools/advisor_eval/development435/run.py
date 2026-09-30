"""One-use435, four isolated local workers; manufactured preflight is separate."""
from pathlib import Path
from datetime import datetime,timezone
from concurrent.futures import ThreadPoolExecutor
import argparse,ctypes,hashlib,json,subprocess,sys,time,threading
HERE=Path(__file__).resolve().parent
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def now():return datetime.now(timezone.utc).isoformat()
def save(p,x):
 with Path(p).open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def literal(raw):
 raw=raw.encode()if isinstance(raw,str)else raw
 return b'"'+b''.join(bytes([c])if 32<=c<127 and c not in(34,92)else('\\%03d'%c).encode()for c in raw)+b'"'
def lua(x):
 if x is None:return b'nil'
 if isinstance(x,bool):return b'true'if x else b'false'
 if isinstance(x,(int,float)):return repr(x).encode()
 if isinstance(x,str):return literal(x)
 if isinstance(x,list):return b'{'+b','.join(lua(v)for v in x)+b'}'
 if isinstance(x,dict):return b'{'+b','.join(b'['+lua(k)+b']='+lua(v)for k,v in x.items())+b'}'
 raise TypeError(type(x))
def evaluate(job=None,preflight=False):
 runtime=read(HERE/'frozen/runtime.json');chunks=[b'local sources={}']
 for name,path in runtime['modules'].items():
  raw=Path(path).read_bytes()
  encoded=b'table.concat({'+b','.join(literal(raw[i:i+256])for i in range(0,len(raw),256))+b'})'
  chunks.append(b'sources['+literal(name)+b']='+encoded)
 chunks.append(b'''package.path='';package.cpath='';package.loaders={}
io=nil;dofile=nil;loadfile=nil;os={clock=os.clock};math.random=function()error('Unregistered randomness')end
pseudorandom=math.random;pseudoseed=math.random
local cache={};local function module(name)
 if cache[name]then return cache[name]end
 local value=assert(loadstring(assert(sources[name],'Missing frozen module '..name),'@frozen/'..name..'.lua'))()
 cache[name]=value;return value
end
local A={}
''')
 chunks.append((HERE/'frozen/module_setup.lua').read_bytes())
 chunks.append(b'local Adapter=(function()\n'+(HERE/'adapter.lua').read_bytes()+b'\nend)()')
 if preflight:chunks.append((HERE/'test_adapter.lua').read_bytes())
 else:chunks.append(b'return assert(A.player_journal.encode(Adapter.run(A,'+lua(job)+b')))')
 source=b'\n'.join(chunks);lib=ctypes.CDLL(str(HERE/'frozen/lua51.dll'))
 lib.luaL_newstate.restype=ctypes.c_void_p;lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
 lib.luaL_loadbuffer.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p]
 lib.lua_pcall.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
 lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
 lib.lua_tolstring.restype=ctypes.c_void_p;lib.lua_close.argtypes=[ctypes.c_void_p]
 state=lib.luaL_newstate();assert state
 try:
  lib.luaL_openlibs(state);status=lib.luaL_loadbuffer(state,source,len(source),b'@evaluation435')
  if not status:status=lib.lua_pcall(state,0,1,0)
  length=ctypes.c_size_t();ptr=lib.lua_tolstring(state,-1,ctypes.byref(length))
  result=ctypes.string_at(ptr,length.value).decode('utf-8','replace')if ptr else''
  if status:raise RuntimeError(result)
  return json.loads(result)
 finally:lib.lua_close(state)
def verify():
 m=read(HERE/'manifest.json')
 for p,h in m['files'].items():assert sha(p)==h,'Frozen input changed: '+p
 assert m['python_version']==sys.version
 assert sha(sys.executable)==m['python_sha256']
 return m
def sources(m):
 for p,h in m['source_files'].items():assert sha(p)==h,'Source changed: '+p
def worker(key):
 m=verify();job=read(HERE/'jobs.json')[key];claim=read(HERE/'ledger'/f'{key}.started.json')
 assert claim['manifest_sha256']==sha(HERE/'manifest.json')==read(HERE/'EXECUTION_STARTED.json')['manifest_sha256']
 assert not(HERE/'CLOSED.json').exists()
 save(HERE/'ledger'/f'{key}.worker.json',{'at':now(),'one_use':True})
 job['snapshot']=read(HERE/'cases.json')[job['case']]['snapshot']
 if job['mode']=='continuation'and not job['pack']:
  binding=read(HERE/'bindings'/f'{job["case"]}.json')
  assert claim['binding_sha256']==sha(HERE/'bindings'/f'{job["case"]}.json')
  p=HERE/'results'/f'{job["diagnostic"]}.json';assert sha(p)==binding['diagnostic_sha256']
  job['admission']=read(p)['result'];assert job['admission']['admitted']
 print(json.dumps(evaluate(job),allow_nan=False),flush=True)
class Budget:
 def __init__(self,registration):
  self.reg=registration;self.start=time.monotonic();self.reserved=0;self.lock=threading.Lock()
 def reserve(self,number):
  with self.lock:
   cap=self.reg['job_seconds']*number
   if self.reserved+cap>self.reg['aggregate_reserved_seconds']or time.monotonic()+cap>self.start+self.reg['overall_seconds']:return False
   self.reserved+=cap;return True
def binding_value(key,result,digest):
 model=result.get('result',{})
 return {'diagnostic':key,'diagnostic_sha256':digest,'diagnostic_status':result['status'],
  'diagnostic_model_status':model.get('status'),'diagnostic_reason':result.get('reason')or model.get('reason'),
  'admitted':result['status']=='complete'and model.get('admitted')is True}
def execute():
 m=verify();sources(m);reg=read(HERE/'registration.json');jobs=read(HERE/'jobs.json')
 assert read(HERE/'READY.json')['manifest_sha256']==sha(HERE/'manifest.json')
 assert reg['max_jobs']==len(jobs)==53 and reg['max_workers']==4 and reg['job_seconds']==15
 save(HERE/'EXECUTION_STARTED.json',{'at':now(),'manifest_sha256':sha(HERE/'manifest.json'),'one_use':True})
 budget=Budget(reg);reports={};lock=threading.Lock()
 def record(key,row):
  row.update(job=key,case=jobs[key]['case'],mode=jobs[key]['mode'],role=jobs[key].get('role'),world=jobs[key].get('world'))
  save(HERE/'results'/f'{key}.json',row)
  with lock:reports[key]=row
  print(json.dumps({'finished':len(reports),'job':key,'status':row['status'],'model_status':row.get('result',{}).get('status')}),flush=True)
  return row
 def claim(key):
  job=jobs[key];row={'at':now(),'cap_seconds':15,'manifest_sha256':sha(HERE/'manifest.json')}
  if job['mode']=='continuation'and not job['pack']:row['binding_sha256']=sha(HERE/'bindings'/f'{job["case"]}.json')
  save(HERE/'ledger'/f'{key}.started.json',row)
 def child(key):
  log=HERE/'results'/f'{key}.log';tick=time.monotonic()
  with log.open('x',encoding='utf-8')as f:
   try:code=subprocess.run([sys.executable,'-B','-u',str(HERE/'run.py'),'--worker',key],stdout=f,stderr=subprocess.STDOUT,
    timeout=15,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0)|getattr(subprocess,'BELOW_NORMAL_PRIORITY_CLASS',0)).returncode
   except subprocess.TimeoutExpired:code='timeout'
  row={'exit_code':code,'seconds':time.monotonic()-tick,'log_sha256':sha(log),'status':'error'}
  if code=='timeout':row['status']='timeout'
  elif code==0:
   try:row['result']=read(log);row['status']='complete'
   except ValueError as e:row['reason']=str(e)
  return record(key,row)
 def diagnostic(key):
  if not budget.reserve(1):return record(key,{'status':'not_started','reason':'budget'})
  claim(key);return child(key)
 def pair(keys):
  job=jobs[keys[0]]
  if not job['pack']:
   binding=read(HERE/'bindings'/f'{job["case"]}.json')
   if not binding['admitted']:
    for key in keys:record(key,{'status':'not_admitted'if binding['diagnostic_status']=='complete'else'not_started',
     'reason':'diagnostic did not admit continuation','originating_diagnostic':binding})
    return
  if not budget.reserve(2):
   for key in keys:record(key,{'status':'not_started','reason':'paired budget'})
   return
  for key in keys:claim(key)
  for key in keys:child(key)
 error=None
 try:
  with ThreadPoolExecutor(max_workers=4)as pool:list(pool.map(diagnostic,reg['diagnostics']))
  for key in reg['diagnostics']:
   job=jobs[key]
   if job['mode']=='admission':
    result=reports[key];save(HERE/'bindings'/f'{job["case"]}.json',binding_value(key,result,sha(HERE/'results'/f'{key}.json')))
  with ThreadPoolExecutor(max_workers=4)as pool:list(pool.map(pair,reg['pairs']))
 except Exception as e:error=repr(e)
 finally:
  for key in jobs:
   if key not in reports and not(HERE/'results'/f'{key}.json').exists():record(key,{'status':'not_started','reason':'runner aborted: '+str(error)})
  verified=False
  try:verify();sources(m);verified=True
  except Exception as e:error=(error or'')+' verification: '+repr(e)
  save(HERE/'CLOSED.json',{'at':now(),'seconds':time.monotonic()-budget.start,'jobs':len(reports),'reserved_child_seconds':budget.reserved,
   'observed_child_seconds':sum(r.get('seconds',0)for r in reports.values()),'remaining_authority':0,'allowance_closed':True,
   'no_auto_resume':True,'frozen_inputs_unchanged':verified,'error':error,
   'counts':{status:sum(r['status']==status for r in reports.values())for status in sorted({r['status']for r in reports.values()})}})
 print(json.dumps(read(HERE/'CLOSED.json')),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();g=p.add_mutually_exclusive_group(required=True)
 g.add_argument('--worker');g.add_argument('--execute',action='store_true');g.add_argument('--preflight',action='store_true');args=p.parse_args()
 if args.worker:worker(args.worker)
 elif args.preflight:print(json.dumps(evaluate(preflight=True),allow_nan=False))
 else:execute()
