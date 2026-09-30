"""Fresh 2026-09-14 development authority and immutable one-use worker receipts.

No historical allowance is read or renewed. A job runs only its frozen command
under its full prospective timeout, with an atomic spent marker before launch.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
EXPIRY = '2026-09-14T22:40:00+00:00'
CAPS = {**{f'S{i:02}': 30 for i in range(1, 13)},
        **{f'M{i:02}': 30 for i in range(1, 25)},
        **{f'C{i:02}': 180 for i in range(1, 25)}}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def create(path, value):
    with Path(path).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write('\n')

def init():
    BASE.mkdir(exist_ok=False)
    create(BASE / 'authority.json', {
        'schema': 1, 'kind': 'gold299_prospective_authority', 'status': 'APPROVED',
        'approved_by': 'user', 'created_at_utc': datetime.now(timezone.utc).isoformat(),
        'approval_reference': 'Current 2026-09-14 user request: Run simulations on Red Deck Gold Stake with Yorick/Perkeo Starting Charm, Brainstorm/Burnt by Ante5, no perishable targets, maximum native CPU; implement and test autonomous collection system continuously before 6PM. Proceed immediately without waiting for response.',
        'expires_at_utc': EXPIRY, 'per_job_caps': CAPS,
        'reserved_worker_seconds': sum(CAPS.values()), 'replacements': 0,
        'old_authorities': 'all_closed_no_carry_forward', 'serial_experiment_workers': True,
        'mechanical_scope': 'M01..M24: bounded original-source initialization/transition/adapter, native single-candidate correctness, or detached captured-state comparisons; never relabel a complete attempt as mechanical.',
        'search_scope': 'S01..S12: bounded native normal-deck seed discovery, maximum CPU requested, outer30s inclusive; record filter, range, found seeds and every timeout.',
        'attempt_scope': 'C01..C24: autonomous selected development source attempts,500 actions and180s maximum each. Freeze exact policy/adapter/profile/source/runtime/selection before launch. Red Deck Gold initial fixed filter; later declared deck or copy-equivalent/collection experiments may vary only with fresh job preregistration.',
        'hypotheses': ['Phase-specific copy ordering and repeated safe Yorick/Burnt investment improve retained scaling.',
            'Cash reservations and exact visible endpoint comparisons can acquire/retain needed Jokers without sacrificing supported survival.',
            'Complete autonomous source runs expose integration failures that local fixtures miss.'],
        'metrics': ['terminal outcome', 'blinds cleared', 'Ante/round/score at failure', 'actual acquisitions and retained final row',
            'original-source selected-action legality', 'exact scores versus floors/random gaps', 'cash/inventory history',
            'computation/search/action/attempt seconds and counts'],
        'inference': 'Selected synthetic all_unlocked_discovered_v1 development only. No representative win odds, unseen holdout or player achievement inference. Errors/timeouts/unsupported/censored remain explicit.',
        'restrictions': {'launch_balatro': False, 'control_running_game': False, 'actual_save_or_profile_access_by_tools': False,
            'source_mode': 'executable ZIP and isolated lua51.dll only', 'source_retry_context': 'disabled_clean',
            'automations': False, 'training': False},
        'product_authority': 'Implement explicit user-started auto-run/search, passive public action/advice/checkpoint logging and verified user-keyed save/load. Product behavior after user activation is distinct from forbidden tool control of the running game.',
        'closure': 'Close all unused slots when work stops or at expiry; no replacing failures, resetting directories or extending limits.'})
    print(BASE)

def register(job, files, command, metadata, external=None):
    """files maps contained frozen relative name to source path; command uses {job}."""
    authority = BASE / 'authority.json'
    a = read(authority)
    assert a['status'] == 'APPROVED' and a['per_job_caps'] == CAPS and job in CAPS
    assert not (BASE / 'CLOSED.json').exists(), 'Cycle is closed'
    assert time.time() + CAPS[job] <= datetime.fromisoformat(EXPIRY).timestamp(), 'Full cap must fit deadline'
    folder = BASE / job
    create(BASE / (job + '_reservation.json'), {'job': job, 'timeout_seconds': CAPS[job], 'one_use': True,
        'authority_sha256': sha(authority), 'created_at_utc': datetime.now(timezone.utc).isoformat()})
    folder.mkdir(exist_ok=False)
    hashes = {}
    for relative, source in files.items():
        target = (folder / relative).resolve()
        target.relative_to(folder.resolve())
        assert relative and not Path(relative).is_absolute()
        target.parent.mkdir(parents=True, exist_ok=True)
        expected = sha(source)
        shutil.copyfile(source, target)
        assert sha(target) == expected
        hashes[relative] = expected
    executable = str(Path(command[0]).resolve())
    assert executable.lower() != str(Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe')).lower()
    assert executable == str(Path(sys.executable).resolve()), 'Workers launch frozen Python adapters only'
    argv = [part.replace('{job}', str(folder.resolve())) for part in command]
    scripts = [Path(part).resolve() for part in argv[1:] if part.endswith('.py')]
    assert scripts and all(p.is_relative_to(folder.resolve()) for p in scripts)
    external_hashes = {str(Path(p).resolve()): sha(p) for p in external or []}
    r = {'schema': 1, 'kind': 'gold299_registered_job', 'job': job,
        'authority_sha256': sha(authority), 'reservation_sha256': sha(BASE / (job + '_reservation.json')),
        'timeout_seconds': CAPS[job], 'command': argv, 'files': hashes, 'external_files': external_hashes,
        'metadata': metadata, 'created_at_utc': datetime.now(timezone.utc).isoformat()}
    create(folder / 'registration.json', r)
    return folder

def run(job):
    folder = BASE / job
    r = read(folder / 'registration.json')
    a = read(BASE / 'authority.json')
    assert not (BASE / 'CLOSED.json').exists()
    assert a['status'] == 'APPROVED' and r['timeout_seconds'] == CAPS[job]
    assert r['authority_sha256'] == sha(BASE / 'authority.json')
    assert r['reservation_sha256'] == sha(BASE / (job + '_reservation.json'))
    for relative, expected in r['files'].items():
        assert sha(folder / relative) == expected, 'Frozen job input changed: ' + relative
    for path, expected in r['external_files'].items():
        assert sha(path) == expected, 'Bound external input changed: ' + path
    assert time.time() + CAPS[job] <= datetime.fromisoformat(EXPIRY).timestamp()
    for other in BASE.glob('*/spent.json'):
        assert (other.parent / 'record.json').exists(), 'Another experiment worker is active or unaccounted'
    create(folder / 'spent.json', {'job': job, 'registration_sha256': sha(folder / 'registration.json'),
        'started_at_utc': datetime.now(timezone.utc).isoformat(), 'one_use': True})
    started = time.monotonic()
    with (folder / 'trace.log').open('x', encoding='utf-8') as stream:
        try:
            result = subprocess.run(r['command'], cwd=folder, stdout=stream, stderr=subprocess.STDOUT,
                timeout=CAPS[job], creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            status, code = ('complete' if result.returncode == 0 else 'error'), result.returncode
        except subprocess.TimeoutExpired:
            status, code = 'timeout', None
        except Exception as error:
            stream.write('\nWORKER_LAUNCH_ERROR ' + repr(error) + '\n')
            status, code = 'error', None
    record = {'job': job, 'status': status, 'exit_code': code, 'elapsed_seconds': time.monotonic() - started,
        'timeout_seconds': CAPS[job], 'registration_sha256': sha(folder / 'registration.json'),
        'trace_sha256': sha(folder / 'trace.log'), 'one_use_spent': True,
        'frozen_files_unchanged': all(sha(folder / p) == h for p, h in r['files'].items()),
        'external_files_unchanged': all(sha(p) == h for p, h in r['external_files'].items()),
        'outcome': 'pending_trace_audit', 'qualification': False}
    create(folder / 'record.json', record)
    print(json.dumps(record))

if __name__ == '__main__':
    if sys.argv[1:] == ['init']:
        init()
    elif len(sys.argv) == 3 and sys.argv[1] == 'run':
        run(sys.argv[2])
    else:
        raise SystemExit('Use init or run JOB; preregister through register() first.')
