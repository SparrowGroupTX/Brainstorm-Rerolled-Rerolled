"""One frozen v9 query, no game/process/save access."""
from pathlib import Path
import ctypes,json,os

folder=Path(__file__).resolve().parent
request=json.loads((folder/'request.json').read_text())
native=folder/'bin/Immolate.dll'
dirs=[os.add_dll_directory(str(native.parent))]
os.environ['BRAINSTORM_SEARCH_LIMIT']=str(request['max_indices'])
lib=ctypes.CDLL(str(native));P,I,B=ctypes.c_char_p,ctypes.c_int,ctypes.c_bool
lib.brainstorm_v9.argtypes=[P,P,P,P,I,B,I,B,B,B,B,B,P,P,P,I,I,P,P,P,I,B,B,P,I,I,I,I]
lib.brainstorm_v9.restype=ctypes.c_void_p;lib.free_result.argtypes=[ctypes.c_void_p]
lib.brainstorm_set_search_thread_mode.argtypes=[I];lib.brainstorm_set_search_thread_mode(1)
us=b'\x1f'
args=[request['seed'].encode(),b'',b'',b'Charm Tag',2,False,0,False,False,False,False,False,
 b'No Filter',b'Kings',b'Any Suit',0,0,us.join(x.encode() for x in request['targets']),request['deck'].encode(),
 us.join(x.encode() for x in request['locations']),8,True,request['copy_alternatives'],b'',0,1,8,request['budget_ms']]
print(json.dumps({'kind':'request','request':request}),flush=True)
ptr=lib.brainstorm_v9(*args)
if not ptr:raise RuntimeError('Missing result allocation')
try:result=json.loads(ctypes.string_at(ptr))
finally:lib.free_result(ptr)
result['qualification']=False;result['acquisition_retention_survival_verified']=False
with (folder/'result.json').open('x') as stream:json.dump(result,stream,indent=2)
print(json.dumps(result),flush=True)
