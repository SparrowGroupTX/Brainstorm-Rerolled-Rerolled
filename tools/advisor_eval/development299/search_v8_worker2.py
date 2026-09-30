"""Registered fixed-filter Red Gold discovery only; no game/source/save access."""
from pathlib import Path
import ctypes
import json
import os
import sys
import time

CHARS='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
COEFF=[66231629136,1892332261,54066636,1544761,44136,1261,36,1]
DOMAIN=2318107019761
def seed_at(index):
    digits=[]
    for coefficient in COEFF:
        if index>0:
            digit=(index-1)//coefficient;index-=1+digit*coefficient;digits.append(CHARS[digit])
    return ''.join(reversed(digits))
def seed_id(seed):
    return sum(COEFF[i]*CHARS.index(c)+1 for i,c in enumerate(reversed(seed)))

folder=Path(__file__).resolve().parent
request=json.loads((folder/'request.json').read_text())
native=folder/'policy/Brainstorm'/request['native_file']
directories=[os.add_dll_directory(str(native.parent))] if os.name=='nt' else []
os.environ['BRAINSTORM_SEARCH_LIMIT']=str(request['batch_indices'])
lib=ctypes.CDLL(str(native))
lib.brainstorm_set_search_thread_mode.argtypes=[ctypes.c_int]
lib.brainstorm_set_search_thread_mode(1)
lib.brainstorm_v8.argtypes=[ctypes.c_char_p]*4+[ctypes.c_int,ctypes.c_bool,ctypes.c_int]+[ctypes.c_bool]*5+[ctypes.c_char_p]*3+[ctypes.c_int]*2+[ctypes.c_char_p]*3+[ctypes.c_int,ctypes.c_bool]
lib.brainstorm_v8.restype=ctypes.c_void_p
lib.free_result.argtypes=[ctypes.c_void_p]
began=time.monotonic();index=request['start_index'];found=[];batches=0;scanned=0
print(json.dumps({'kind':'search_request','request':request}),flush=True)
while time.monotonic()-began<request['soft_seconds'] and len(found)<request['matches'] and batches<request['max_batches']:
    seed=seed_at(index)
    args=[seed.encode(),b'',b'',request['tag_name'].encode(),2,False,0,False,False,False,False,False,b'No Filter',b'',b'',0,0,
        b'Yorick\x1fBrainstorm\x1fBurnt Joker\x1fPerkeo',b'Red Deck',b'soul_pack\x1fby_ante_5\x1fby_ante_5\x1fsoul_pack',8,True]
    started=time.monotonic();ptr=lib.brainstorm_v8(*args)
    if not ptr: raise RuntimeError('Native returned no result allocation')
    try: result=ctypes.string_at(ptr).decode('utf-8')
    finally: lib.free_result(ptr)
    batches+=1
    record={'kind':'search_batch','start_index':index,'start_seed':seed,'requested_indices':request['batch_indices'],
        'result_seed':result or None,'seconds':time.monotonic()-started}
    if result:
        assert 1<=len(result)<=8 and all(c in CHARS for c in result)
        used=(seed_id(result)-index)%DOMAIN+1
        assert used<=request['batch_indices'],'Result is outside registered search interval'
        record['actual_indices_through_match']=used;scanned+=used
        if result not in found: found.append(result)
        index=(seed_id(result)+1)%DOMAIN
    else:
        scanned+=request['batch_indices'];index=(index+request['batch_indices'])%DOMAIN
    print(json.dumps(record),flush=True)
result={'kind':'search_final','status':'found' if len(found)==request['matches'] else 'bounded_stop',
    'found':found,'batches':batches,'requested_indices_through_returns':scanned,'verified_indices_traversed':None,'next_index':index,'seconds':time.monotonic()-began,
    'conditional_static_offers_only':True,'acquisition_retention_survival_verified':False,'qualification':False}
with (folder/'result.json').open('x') as stream: json.dump(result,stream,indent=2)
print(json.dumps(result),flush=True)
