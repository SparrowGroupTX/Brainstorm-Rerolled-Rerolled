"""Close the expired original cycle; never registers, launches or alters a job."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def inspect():
    authority = read(BASE / 'authority.json')
    now = datetime.now(timezone.utc)
    assert now >= datetime.fromisoformat(authority['expires_at_utc']), 'Original window has not expired'
    assert authority['status'] == 'APPROVED'
    caps = authority['per_job_caps']
    assert sum(caps.values()) == authority['reserved_worker_seconds'] == 5400
    assert not (BASE / 'C09').exists() and not (BASE / 'C09_reservation.json').exists()
    jobs = []
    for reservation_path in sorted(BASE.glob('*_reservation.json')):
        reservation = read(reservation_path); job = reservation['job']; folder = BASE / job
        assert reservation_path.name == job + '_reservation.json' and job in caps
        registration = read(folder / 'registration.json')
        spent = read(folder / 'spent.json'); record = read(folder / 'record.json')
        assert reservation['authority_sha256'] == registration['authority_sha256'] == sha(BASE / 'authority.json')
        assert registration['reservation_sha256'] == sha(reservation_path)
        assert registration['job'] == spent['job'] == record['job'] == job
        assert registration['timeout_seconds'] == record['timeout_seconds'] == caps[job]
        assert spent['one_use'] and record['one_use_spent']
        assert spent['registration_sha256'] == record['registration_sha256'] == sha(folder / 'registration.json')
        assert record['status'] in ('complete', 'error', 'timeout')
        assert record['frozen_files_unchanged'] and record['external_files_unchanged']
        assert record['trace_sha256'] == sha(folder / 'trace.log')
        for relative, expected in registration['files'].items():
            path = (folder / relative).resolve(); path.relative_to(folder.resolve())
            assert sha(path) == expected, (job, relative)
        for path, expected in registration['external_files'].items():
            assert sha(path) == expected, (job, path)
        jobs.append({'job': job, 'record_sha256': sha(folder / 'record.json'),
                     'registration_sha256': sha(folder / 'registration.json'),
                     'reserved_seconds': caps[job], 'actual_seconds': record['elapsed_seconds']})
    used = {j['job'] for j in jobs}
    assert used == {f'S{i:02}' for i in range(1, 7)} | {f'M{i:02}' for i in range(1, 25)} | {f'C{i:02}' for i in range(1, 9)}
    assert {p.parent.name for p in BASE.glob('*/spent.json')} == used
    assert {p.parent.name for p in BASE.glob('*/registration.json') if read(p).get('job') in caps} == used
    return {'schema': 1, 'kind': 'gold299_cycle_closure', 'status': 'CLOSED',
            'closed_at_utc': now.isoformat(), 'reason': 'Original authorization expired; work stopped without extending it.',
            'authority_sha256': sha(BASE / 'authority.json'), 'expires_at_utc': authority['expires_at_utc'],
            'reserved_total_seconds': 5400, 'spent_reserved_seconds': sum(j['reserved_seconds'] for j in jobs),
            'actual_worker_seconds': sum(j['actual_seconds'] for j in jobs),
            'completed_job_records': jobs, 'closed_unused_slots': [j for j in caps if j not in used],
            'unused_capacity': 'closed', 'replacements': 0, 'active_workers': 0,
            'C09': 'Prepared only; never registered, reserved, spent or run. No result.',
            'verification': 'Every reservation has its hash-matched registration, spent marker and reaped subprocess record; traces, frozen inputs and external provenance rehashed.',
            'closing_tool_sha256': sha(__file__)}

if __name__ == '__main__':
    assert sys.argv[1:] in (['--check'], ['--close'])
    assert not (BASE / 'CLOSED.json').exists(), 'Preserve existing closure'
    result = inspect()
    if sys.argv[1:] == ['--close']:
        with (BASE / 'CLOSED.json').open('x', encoding='utf-8') as stream:
            json.dump(result, stream, indent=2, allow_nan=False); stream.write('\n')
    print(json.dumps({k: result[k] for k in ('status', 'spent_reserved_seconds', 'actual_worker_seconds', 'closed_unused_slots', 'C09')}))
