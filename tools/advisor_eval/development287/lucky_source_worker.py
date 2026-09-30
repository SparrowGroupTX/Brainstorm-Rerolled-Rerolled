"""Execute one externally admitted immutable B1/B2 source-method job.

The coordinator owns the 30s subprocess wall cap and serial global admission.
This worker requires a prospective287 authority, immutable parent registration,
an unexpired coordinator start marker, and an exclusive consumed marker before
reading the executable ZIP or loading the isolated Lua library. It cannot run a
complete game, seed search, or save operation.
"""
from __future__ import annotations

import argparse
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import time
import zipfile


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked(item: dict) -> Path:
    path = Path(item['path']).resolve()
    if not path.is_file() or sha(path) != item['sha256']:
        raise ValueError(f'Frozen input differs: {path}')
    return path


def validate_manifest(manifest: dict, now: float, authority: dict, started: dict) -> None:
    job_id = manifest.get('job_id')
    if manifest.get('kind') != 'lucky_source_truth287' or job_id not in ('B1', 'B2'):
        raise ValueError('Only registered Lucky source jobs B1/B2 are supported')
    if manifest.get('mode') != ('ordinary' if job_id == 'B1' else 'red') or manifest.get('cap_seconds') != 30:
        raise ValueError('The registered four/sixteen-case 30s cap cannot change')
    if authority.get('kind') != 'prospective287_authority' or authority.get('status') != 'APPROVED':
        raise ValueError('Fresh approved287 authority is required')
    if authority.get('approved_by') != 'user' or authority.get('replacements') != 0 or authority.get('serial_only') is not True:
        raise ValueError('Require user authorization, no replacements, and serial admission')
    if job_id not in authority.get('allowed_job_ids', []) or authority.get('per_job_caps', {}).get(job_id) != 30:
        raise ValueError('Job or cap absent from fresh authority')
    expires = authority.get('expires_at_utc')
    if not isinstance(expires, str) or datetime.fromisoformat(expires).timestamp() <= now:
        raise ValueError('Fresh authority expired')
    if (started.get('job_id') != job_id or type(started.get('coordinator_pid')) is not int
            or started['coordinator_pid'] != os.getppid()):
        raise ValueError('Missing coordinator admission marker')
    deadline = started.get('deadline_unix')
    if (not isinstance(deadline, (int, float)) or not now < deadline <= now + 31
            or deadline > datetime.fromisoformat(expires).timestamp()):
        raise ValueError('Missing, expired or excessive job deadline')
    if Path(manifest['rules']['path']).name.lower() != 'balatro.exe':
        raise ValueError('Expected ZIP rules file')
    if Path(manifest['runtime']['path']).name.lower() != 'lua51.dll':
        raise ValueError('Only isolated Lua 5.1 library is supported')
    if set(manifest['sources']) != {'card.lua', 'functions/common_events.lua'}:
        raise ValueError('Only the two declared Lucky component sources are permitted')


def execute_lua(runtime: Path, code: bytes) -> None:
    library = ctypes.CDLL(str(runtime))
    library.luaL_newstate.restype = ctypes.c_void_p
    library.luaL_openlibs.argtypes = [ctypes.c_void_p]
    library.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    library.luaL_loadbuffer.restype = ctypes.c_int
    library.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    library.lua_pcall.restype = ctypes.c_int
    library.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    library.lua_tolstring.restype = ctypes.c_void_p
    library.lua_close.argtypes = [ctypes.c_void_p]
    state = library.luaL_newstate()
    if not state:
        raise RuntimeError('Lua allocation failed')
    try:
        library.luaL_openlibs(state)
        status = library.luaL_loadbuffer(state, code, len(code), b'@registered_lucky_source_truth287.lua')
        if status == 0:
            status = library.lua_pcall(state, 0, 0, 0)
        if status != 0:
            length = ctypes.c_size_t()
            pointer = library.lua_tolstring(state, -1, ctypes.byref(length))
            message = ctypes.string_at(pointer, length.value).decode('utf-8', 'replace') if pointer else 'Lua error'
            raise RuntimeError(message)
    finally:
        library.lua_close(state)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--registration', type=Path, required=True)
    args = parser.parse_args()
    started = time.perf_counter()
    registration_path = args.registration.resolve()
    registration_raw = registration_path.read_bytes()
    registration_digest = hashlib.sha256(registration_raw).hexdigest()
    registration = json.loads(registration_raw)
    if (registration.get('kind') != 'prospective287_job' or registration.get('status') != 'REGISTERED'
            or registration.get('timeout_seconds') != 30):
        raise ValueError('Require the immutable parent 30s registration')
    authority_path = checked({'path': registration['authority_path'], 'sha256': registration['authority_sha256']})
    authority = json.loads(authority_path.read_text(encoding='utf-8'))
    path = checked({'path': registration['job_manifest_path'], 'sha256': registration['job_manifest_sha256']})
    raw = path.read_bytes()
    manifest_digest = hashlib.sha256(raw).hexdigest()
    manifest = json.loads(raw)
    if registration.get('job_id') != manifest.get('job_id'):
        raise ValueError('Registration and manifest job differ')
    admission_path = Path(registration['started_path']).resolve()
    admission_raw = admission_path.read_bytes()
    admission = json.loads(admission_raw)
    if admission.get('registration_sha256') != registration_digest:
        raise ValueError('Coordinator marker does not bind exact parent registration')
    validate_manifest(manifest, time.time(), authority, admission)
    marker = path.with_name(path.name + '.worker_consumed.json')
    with marker.open('x', encoding='utf-8') as stream:
        json.dump({'job_id': manifest['job_id'], 'manifest_sha256': manifest_digest,
                   'consumed_at_utc': datetime.now(timezone.utc).isoformat()}, stream)
    inputs = {name: checked(manifest[name]) for name in ('rules', 'runtime', 'probe', 'worker', 'builder', 'harness')}
    if inputs['worker'] != Path(__file__).resolve():
        raise ValueError('Run the exact registered worker')
    policies = {name: checked(item) for name, item in manifest['policy_files'].items()}
    sources = {name: checked(item) for name, item in manifest['sources'].items()}
    with zipfile.ZipFile(inputs['rules']) as archive:
        for name in sources:
            if hashlib.sha256(archive.read(name)).hexdigest() != manifest['sources'][name]['sha256']:
                raise ValueError(f'Frozen source differs from current rules ZIP: {name}')
    if time.time() >= admission['deadline_unix']:
        raise TimeoutError('Deadline spent on source/provenance verification')
    print(json.dumps({'type': 'lucky_source_job_started', 'job_id': manifest['job_id'],
                      'manifest_sha256': manifest_digest, 'qualification': False}), flush=True)
    execute_lua(inputs['runtime'], inputs['probe'].read_bytes())
    for name in inputs:
        checked(manifest[name])
    for item in list(manifest['sources'].values()) + list(manifest['policy_files'].values()):
        checked(item)
    if (path.read_bytes() != raw or registration_path.read_bytes() != registration_raw
            or admission_path.read_bytes() != admission_raw):
        raise ValueError('Job admission changed during execution')
    checked({'path': registration['authority_path'], 'sha256': registration['authority_sha256']})
    if time.time() >= admission['deadline_unix']:
        raise TimeoutError('Job deadline exceeded')
    print(json.dumps({'type': 'lucky_source_job_complete', 'job_id': manifest['job_id'],
                      'elapsed_seconds': time.perf_counter() - started, 'qualification': False,
                      'source_phase_qualified': False}), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
