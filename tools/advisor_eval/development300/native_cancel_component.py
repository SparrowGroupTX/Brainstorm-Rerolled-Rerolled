"""Prospective mechanical cancellation fixture; root must register before use.

Two-thread native call: at most1B indices/1000ms, canceled10ms after entry.
Its Perkeo encounter quota is restricted to Ante8, where this modeled route has
no Soul/Judgement generation; the fixed query is intentionally nonmatching.
No game/source/save access and no terminal attempt.
"""
import argparse
import ctypes
import json
import os
from pathlib import Path
import threading
import time

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dll', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    out = Path(args.output); out.mkdir(parents=True, exist_ok=True)
    target = out/'cancellation.json'
    if target.exists(): raise SystemExit('Fresh one-use output required')
    native = Path(args.dll).resolve()
    directories = [os.add_dll_directory(str(native.parent))] if os.name=='nt' else []
    os.environ['BRAINSTORM_THREADS']='2'
    os.environ['BRAINSTORM_SEARCH_LIMIT']='1000000000'
    lib = ctypes.CDLL(str(native))
    P,I,B=ctypes.c_char_p,ctypes.c_int,ctypes.c_bool
    lib.brainstorm_v9.argtypes=[P,P,P,P,I,B,I,B,B,B,B,B,P,P,P,I,I,P,P,P,I,B,B,P,I,I,I,I]
    lib.brainstorm_v9.restype=ctypes.c_void_p
    lib.free_result.argtypes=[ctypes.c_void_p]
    lib.brainstorm_cancel_v9.argtypes=[];lib.brainstorm_cancel_v9.restype=None
    us=b'\x1f'
    query=[b'11111111',b'',b'',b'Charm Tag',2,False,0,False,False,False,False,False,
           b'No Filter',b'',b'',0,0,us.join([b'Yorick',b'Brainstorm',b'Burnt Joker',b'Perkeo']),
           b'Red Deck',us.join([b'soul_pack',b'by_ante_5',b'by_ante_5',b'soul_pack']),
           8,True,True,b'Perkeo',1,8,8,1000]
    values=[];started=threading.Event();times={}
    def work():
        times['entered']=time.perf_counter();started.set()
        try:
            ptr=lib.brainstorm_v9(*query)
            if not ptr: raise RuntimeError('Null native result')
            try: values.append(json.loads(ctypes.string_at(ptr)))
            finally: lib.free_result(ptr)
        except BaseException as exc: values.append({'status':'error','error':str(exc)})
        finally: times['returned']=time.perf_counter()
    worker=threading.Thread(target=work,daemon=True);worker.start()
    started.wait(1)
    time.sleep(.010);times['cancelled']=time.perf_counter();lib.brainstorm_cancel_v9()
    worker.join(1.5)
    elapsed=times.get('returned',time.perf_counter())-times['entered']
    latency=times.get('returned',time.perf_counter())-times['cancelled']
    passed=bool(values) and values[0].get('status')=='cancelled' and not worker.is_alive() and 0<=latency<.250 and elapsed<.250
    result={'schema':1,'status':'passed' if passed else 'failed',
            'native_result':values[0] if values else None,'elapsed_seconds':elapsed,
            'cancel_to_return_seconds':latency,'cancel_requested_seconds':times['cancelled']-times['entered'],
            'index_limit':1000000000,'native_budget_ms':1000,'thread_override':2,
            'worker_still_running':worker.is_alive(),
            'scope':'Intentional nonmatching Ante8 Perkeo offer quota; cancellation mechanics only.'}
    target.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
    raise SystemExit(0 if passed else 1)

if __name__=='__main__':main()
