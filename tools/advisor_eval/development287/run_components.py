"""One-use serial coordinator for the already registered diagnostic287 A/B jobs."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[3]
CYCLE = ROOT / 'tools/advisor_eval/runs/diagnostic287_20260913_222344'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, indent=2)

def main():
    authority_path = CYCLE / 'authority.json'
    authority = json.loads(authority_path.read_text())
    if sha(authority_path) != '34a108eadec8654f4312e240672715ba287a10061d25ed7898f121d959b8ad4e':
        raise ValueError('Authority changed')
    expiry = datetime.fromisoformat(authority['expires_at_utc']).timestamp()
    write(CYCLE / 'components_coordinator_started.json', {'pid': os.getpid(), 'sha256': sha(Path(__file__)), 'at': datetime.now(timezone.utc).isoformat()})
    preparation = json.loads((CYCLE / 'b_preparation2/preparation.json').read_text())
    records = []
    for job in ['B1', 'B2', 'A1', 'A2', 'A3', 'A4']:
        cap = authority['per_job_caps'][job]
        if time.time() + cap > expiry:
            raise ValueError('Full job cap does not fit authority deadline')
        registration_path = CYCLE / (job + '_registration.json')
        if job.startswith('B'):
            manifest = preparation['manifest_files'][job]
            command = [sys.executable, '-B', '-u', str(CYCLE / 'b_preparation2/tools/lucky_source_worker.py'), '--registration', str(registration_path)]
            write(registration_path, {'schema': 1, 'kind': 'prospective287_job', 'status': 'REGISTERED', 'job_id': job,
                  'timeout_seconds': cap, 'authority_path': str(authority_path), 'authority_sha256': sha(authority_path),
                  'job_manifest_path': manifest['path'], 'job_manifest_sha256': manifest['sha256'],
                  'started_path': str(CYCLE / (job + '_started.json')), 'command': command})
        else:
            registration = json.loads(registration_path.read_text())
            if registration['timeout_seconds'] != cap or registration['authority_sha256'] != sha(authority_path):
                raise ValueError('A registration does not match authority')
            command = [sys.executable, '-B', '-u', str(CYCLE / (job + '_captured') / 'frozen/captured_snapshot_pair.py'), '--execute', str(CYCLE / (job + '_captured'))]
        start = time.perf_counter()
        deadline = time.time() + cap
        write(CYCLE / (job + '_started.json'), {'job_id': job, 'coordinator_pid': os.getpid(), 'deadline_unix': deadline,
                                               'registration_sha256': sha(registration_path)})
        timed_out = False
        with (CYCLE / (job + '_coordinator.log')).open('x', encoding='utf-8') as log:
            process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            try:
                process.wait(timeout=max(0.001, cap - (time.perf_counter() - start)))
            except subprocess.TimeoutExpired:
                timed_out = True
                process.kill()
                process.wait()
        record = {'job_id': job, 'reserved_seconds': cap, 'elapsed_seconds': time.perf_counter() - start,
                  'timed_out': timed_out, 'exit_code': process.returncode, 'command': command,
                  'registration_sha256': sha(registration_path), 'log_sha256': sha(CYCLE / (job + '_coordinator.log'))}
        write(CYCLE / (job + '_coordinator_record.json'), record)
        records.append(record)
        print(json.dumps(record), flush=True)
    write(CYCLE / 'components_coordinator_record.json', {'jobs': records, 'reserved_seconds': sum(r['reserved_seconds'] for r in records),
                                                       'elapsed_seconds': sum(r['elapsed_seconds'] for r in records), 'replacements': 0})

if __name__ == '__main__':
    main()
