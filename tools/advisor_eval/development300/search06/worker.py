"""Registered S06: at most two synchronous native calls under one wall budget."""
from pathlib import Path
import ctypes
import hashlib
import json
import os
import time
from spec import make_request,native_args,parse_result,fallback,DOMAIN

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def create(path,value):
    with path.open('x',encoding='utf-8')as out:
        json.dump(value,out,indent=2,allow_nan=False);out.write('\n')

def execute(request, call, clock, emit, started=None):
    """Injectable serial state machine. call returns only after native exit/free."""
    if started is None:started=clock()
    deadline=started+request['original_native_budget_ms']/1000
    phases=[];phase=dict(query=request['phase_templates'][0],seed=request['start_seed'],
                        start_index=request['start_index'],max_indices=request['max_indices_total'])
    final_status='error';reason=None;found=None
    for number in (1,2):
        elapsed=clock()-started
        if elapsed<0:raise ValueError('Monotonic clock moved backwards')
        if clock()>=deadline:
            final_status='timeout';reason='Original native wall budget expired before dispatch';break
        # Phase1 is fixed9s; if dependency setup ever consumed its full allowance,
        # do not dispatch a call that cannot fit the original deadline.
        if number==1 and deadline-clock()<phase['query']['budget_ms']/1000:
            final_status='timeout';reason='Insufficient original wall budget for fixed first phase';break
        effective=dict(phase,phase=number)
        emit('phase_started',effective)
        entered=clock();raw=call(phase);returned=clock()
        emit('phase_raw',dict(phase=number,raw=raw))
        result=parse_result(raw,phase['query'])
        receipt=dict(phase=number,query=phase['query'],start_index=phase['start_index'],start_seed=phase['seed'],
          max_indices=phase['max_indices'],native_call_elapsed_seconds=returned-entered,
          elapsed_search_seconds=returned-started,fully_exited=True,result=result)
        phases.append(receipt);emit('phase_complete',receipt)
        if returned<entered:raise ValueError('Monotonic clock moved backwards')
        if returned>=deadline:
            final_status='timeout';reason='Native result returned after original deadline; no found seed accepted';break
        final_status=result['status']
        if final_status=='found':found=dict(seed=result['seed'],phase=number,query=phase['query'],receipt=receipt);break
        if number==2:break
        phase=fallback(request,result,clock()-started)
        if phase is None:break
    return dict(schema=1,job='S06',status=final_status,reason=reason,found=found,phases=phases,
      search_calls=len(phases),worker_state_machine_seconds=clock()-started,
      reserved_native_ms=sum(p['query']['budget_ms']for p in phases),
      qualification=False,acquisition_retention_survival_verified=False,
      product_thread_cancellation_or_launch_qualified=False,
      native_profile='synthetic_complete_unlock_discovery_only_canio_missing',
      method='Serial native calls with frozen production phase templates; Python owns timing/cursor. No LOVE thread or live product execution.')

def main():
    folder=Path(__file__).resolve().parent
    started=time.perf_counter()
    registration=json.loads((folder/'registration.json').read_text())
    spent=json.loads((folder/'spent.json').read_text())
    request=json.loads((folder/'request.json').read_text())
    generation=json.loads((folder/'query_generation.json').read_text())
    if (registration.get('job')!='S06' or registration.get('timeout_seconds')!=30 or
        spent.get('job')!='S06' or spent.get('registration_sha256')!=sha(folder/'registration.json') or
        request!=make_request(generation)):
        raise RuntimeError('Matching root-dispatched one-use S06 registration required')
    create(folder/'native_sequence_spent.json',dict(schema=1,job='S06',max_calls=2,one_use=True,
      registration_sha256=sha(folder/'registration.json'),no_retry=True))
    try:
        native=folder/'bin'/request['native_file']
        if sha(native)!=request['native_sha256']:raise ValueError('Native sidecar digest mismatch')
        directories=[os.add_dll_directory(str(native.parent))]if os.name=='nt'else []
        os.environ.pop('BRAINSTORM_THREADS',None)
        lib=ctypes.CDLL(str(native))
        P,I,B=ctypes.c_char_p,ctypes.c_int,ctypes.c_bool
        lib.brainstorm_v9.argtypes=[P,P,P,P,I,B,I,B,B,B,B,B,P,P,P,I,I,P,P,P,I,B,B,P,I,I,I,I]
        lib.brainstorm_v9.restype=ctypes.c_void_p
        lib.free_result.argtypes=[ctypes.c_void_p];lib.free_result.restype=None
        lib.brainstorm_set_search_thread_mode.argtypes=[I];lib.brainstorm_set_search_thread_mode.restype=None
        lib.brainstorm_set_search_thread_mode(1)
        def call(phase):
            os.environ['BRAINSTORM_SEARCH_LIMIT']=str(min(phase['max_indices'],DOMAIN-phase['start_index']))
            args=[v.encode('utf-8')if isinstance(v,str)else v for v in native_args(phase['query'],phase['seed'])]
            ptr=lib.brainstorm_v9(*args)
            if not ptr:raise RuntimeError('Native returned no result allocation')
            try:return ctypes.string_at(ptr)
            finally:lib.free_result(ptr)
        def emit(kind,value):
            number=value['phase']
            if kind=='phase_raw':
                with(folder/f'phase{number}_raw.json').open('xb')as out:out.write(value['raw'])
            else:
                create(folder/f'phase{number}_{kind}.json',value)
                print(json.dumps(dict(kind=kind,value=value),allow_nan=False),flush=True)
        # Include all worker/native-library setup against the same27s deadline.
        result=execute(request,call,time.perf_counter,emit,started=started)
        result['worker_elapsed_seconds']=time.perf_counter()-started
        create(folder/'result.json',result);print(json.dumps(result,allow_nan=False),flush=True)
    except BaseException as error:
        create(folder/'worker_error.json',dict(schema=1,job='S06',status='error',error=repr(error),
          elapsed_seconds=time.perf_counter()-started,qualification=False,no_retry=True))
        raise

if __name__=='__main__':main()
