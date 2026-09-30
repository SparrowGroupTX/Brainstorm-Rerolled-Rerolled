"""Registered mechanical lease only: <=30 seconds, no game/source execution.

Root must freeze this wrapper, DLL and executables before authorizing a call.
Two native v9 smoke calls each have <=100ms and <=50000-index limits. Their
results remain development observations, never terminal attempts or win odds.
"""
import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import threading
import time

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dll', required=True)
    parser.add_argument('--api', required=True)
    parser.add_argument('--synthetic', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    receipt = output / 'native_validation.json'
    if receipt.exists():
        raise SystemExit('Fresh one-use output required')
    started = time.perf_counter()
    result = {'schema': 1, 'status': 'running', 'component_cap_seconds': 30,
              'scope': 'Mechanical native fixtures and two bounded v9 smoke calls; no game, source or saves.'}
    try:
        native_dir = Path(args.dll).resolve().parent
        dll_directories = [os.add_dll_directory(str(native_dir))] if os.name == 'nt' else []
        native_env = dict(os.environ)
        native_env['PATH'] = str(native_dir) + os.pathsep + native_env.get('PATH', '')
        for label, exe, cap in [('synthetic', args.synthetic, 2), ('legacy_api', args.api, 22)]:
            began = time.perf_counter()
            done = subprocess.run([str(Path(exe).resolve())], capture_output=True,
                env=native_env, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
                timeout=min(cap, 27-(time.perf_counter()-started)))
            (output/(label+'.log')).write_bytes(done.stdout+done.stderr)
            result[label] = {'code': done.returncode, 'seconds': time.perf_counter()-began}
            if done.returncode:
                raise RuntimeError(label+' failed')
        os.environ['BRAINSTORM_SEARCH_LIMIT'] = '50000'
        os.environ['BRAINSTORM_THREADS'] = '2'
        dll = ctypes.CDLL(str(Path(args.dll).resolve()))
        P, I, B = ctypes.c_char_p, ctypes.c_int, ctypes.c_bool
        dll.brainstorm_v9.argtypes = [P,P,P,P,I,B,I,B,B,B,B,B,P,P,P,I,I,P,P,P,I,B,B,P,I,I,I,I]
        dll.brainstorm_v9.restype = ctypes.c_void_p
        dll.free_result.argtypes = [ctypes.c_void_p]
        dll.brainstorm_cancel_v9.argtypes = []
        dll.brainstorm_cancel_v9.restype = None
        dll.brainstorm_set_search_thread_mode.argtypes = [I]
        dll.brainstorm_set_search_thread_mode(1)
        us = b'\x1f'
        query = [b'11111111',b'',b'',b'Charm Tag',2,False,0,False,False,False,False,False,
                 b'No Filter',b'',b'',0,0,
                 us.join([b'Yorick',b'Brainstorm',b'Burnt Joker',b'Perkeo']),b'Red Deck',
                 us.join([b'soul_pack',b'by_ante_5',b'by_ante_5',b'soul_pack']),8,True,
                 True,us.join([b'Joker',b'Burnt Joker',b'Yorick',b'Perkeo']),2,1,8,100]
        def call(values):
            ptr = dll.brainstorm_v9(*values)
            if not ptr: raise RuntimeError('Null v9 response')
            try: return json.loads(ctypes.string_at(ptr))
            finally: dll.free_result(ptr)
        invalid = list(query); invalid[-1] = 30001
        result['invalid_request'] = call(invalid)
        if result['invalid_request'].get('status') != 'invalid': raise RuntimeError('budget gate failed')
        result['smoke'] = call(query)
        result['smoke']['rank_suit_input'] = 'blank, with both count minima zero'
        if result['smoke'].get('status') not in ('found','not_found','timeout'):
            raise RuntimeError('valid original-order v9 request rejected')
        outcomes = []
        query[13], query[14] = b'Kings', b'Any Suit'
        def cancel_work():
            try: outcomes.append(call(query))
            except BaseException as exc: outcomes.append({'exception': str(exc)})
        worker = threading.Thread(target=cancel_work, daemon=True)
        worker.start()
        time.sleep(.005)
        dll.brainstorm_cancel_v9()
        worker.join(1)
        if worker.is_alive(): raise RuntimeError('v9 cancellation did not return within one second')
        result['cancel'] = outcomes[0]
        if outcomes[0].get('status') not in ('cancelled','found','not_found','timeout'):
            raise RuntimeError('cancellation smoke returned unexpected status')
        result['status'] = 'passed'
    except BaseException as exc:
        result['status'], result['error'] = 'failed', type(exc).__name__+': '+str(exc)
    result['seconds'] = time.perf_counter()-started
    receipt.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result), flush=True)
    raise SystemExit(0 if result['status']=='passed' else 1)

if __name__=='__main__':
    main()
