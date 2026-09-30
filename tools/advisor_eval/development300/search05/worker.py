"""One registered native query. No game/source/save or profile-file access."""
from pathlib import Path
import ctypes
import hashlib
import json
import os
import time
from spec import native_args, request

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def create(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')

def main():
    folder = Path(__file__).resolve().parent
    registration = json.loads((folder/'registration.json').read_text())
    spent = json.loads((folder/'spent.json').read_text())
    q = json.loads((folder/'request.json').read_text())
    if (registration.get('job') != 'S05' or registration.get('timeout_seconds') != 30 or
        spent.get('job') != 'S05' or spent.get('registration_sha256') != sha(folder/'registration.json') or
        q != request()):
        raise RuntimeError('Matching root-dispatched one-use S05 registration required')
    create(folder/'native_call_spent.json', {'schema': 1, 'job': 'S05', 'calls': 1,
        'registration_sha256': sha(folder/'registration.json'), 'one_use': True})
    started = time.perf_counter()
    try:
        native = folder/'bin'/q['native_file']
        if sha(native) != q['native_sha256']:
            raise RuntimeError('Native sidecar digest differs from the preregistered request')
        directories = [os.add_dll_directory(str(native.parent))] if os.name == 'nt' else []
        os.environ.pop('BRAINSTORM_THREADS', None)
        os.environ['BRAINSTORM_SEARCH_LIMIT'] = str(q['max_indices'])
        lib = ctypes.CDLL(str(native))
        P, I, B = ctypes.c_char_p, ctypes.c_int, ctypes.c_bool
        lib.brainstorm_v9.argtypes = [P,P,P,P,I,B,I,B,B,B,B,B,P,P,P,I,I,P,P,P,I,B,B,P,I,I,I,I]
        lib.brainstorm_v9.restype = ctypes.c_void_p
        lib.free_result.argtypes = [ctypes.c_void_p];lib.free_result.restype = None
        lib.brainstorm_set_search_thread_mode.argtypes = [I]
        lib.brainstorm_set_search_thread_mode.restype = None
        lib.brainstorm_set_search_thread_mode(1)
        values = native_args(q)
        args = [value.encode('utf-8') if isinstance(value, str) else value for value in values]
        print(json.dumps({'kind': 'request', 'request': q}), flush=True)
        entered = time.perf_counter()
        ptr = lib.brainstorm_v9(*args)
        returned = time.perf_counter()
        if not ptr:
            raise RuntimeError('Native returned no result allocation')
        try:
            raw = ctypes.string_at(ptr)
        finally:
            lib.free_result(ptr)
        with (folder/'raw_result.json').open('xb') as stream:
            stream.write(raw)
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError('Native response is not an object')
        result.update(qualification=False, acquisition_retention_survival_verified=False,
                      worker_elapsed_seconds=time.perf_counter()-started,
                      native_call_elapsed_seconds=returned-entered, search_calls=1,
                      native_profile='synthetic_complete_unlock_discovery_assumption')
        create(folder/'result.json', result)
        print(json.dumps(result, allow_nan=False), flush=True)
    except BaseException as error:
        create(folder/'worker_error.json', {'schema': 1, 'job': 'S05', 'status': 'error',
            'error': repr(error), 'elapsed_seconds': time.perf_counter()-started,
            'qualification': False, 'no_retry': True})
        raise

if __name__ == '__main__':
    main()
