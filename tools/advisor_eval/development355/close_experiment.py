"""Close existing learning355 receipts; never launches a worker or game."""
import datetime as dt
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main():
    manifest = json.loads((HERE / 'EXPERIMENT_355.json').read_text())
    jobs = {}
    for name, spec in manifest['jobs'].items():
        receipt = HERE / 'jobs' / name / 'receipt.json'
        if receipt.exists():
            row = json.loads(receipt.read_text())
            if row['status'] not in ('completed', 'error', 'timeout'):
                raise RuntimeError(f'Job {name} not stopped')
            jobs[name] = {
                'status': row['status'], 'reserved_seconds': spec['seconds'],
                'actual_coordinator_seconds': row['elapsed_seconds'],
                'receipt_sha256': hashlib.sha256(receipt.read_bytes()).hexdigest(),
                'frozen_sha256': row.get('frozen_sha256')}
        else:
            if (HERE / 'jobs' / name).exists():
                raise RuntimeError(f'Unresolved job directory {name}')
            jobs[name] = {'status': 'closed_unused', 'reserved_seconds': spec['seconds'],
                          'actual_coordinator_seconds': 0}
    files = [p for p in HERE.rglob('*') if p.is_file()]
    size = sum(p.stat().st_size for p in files)
    if size > manifest['limits']['artifact_gib'] * 2**30:
        raise RuntimeError('Artifact cap exceeded')
    record = {
        'schema': 'learning355-closed-v1', 'status': 'CLOSED',
        'closed_utc': dt.datetime.now(dt.timezone.utc).isoformat(), 'jobs': jobs,
        'reserved_coordinator_seconds': sum(j['reserved_seconds'] for j in jobs.values()),
        'consumed_job_reservations_seconds': sum(j['reserved_seconds'] for j in jobs.values()
                                               if j['status'] != 'closed_unused'),
        'closed_unused_seconds': sum(j['reserved_seconds'] for j in jobs.values()
                                    if j['status'] == 'closed_unused'),
        'actual_coordinator_seconds': sum(j['actual_coordinator_seconds'] for j in jobs.values()),
        'parallelism_limit': 8, 'summed_cpu_time_measured': False,
        'artifact_bytes_at_closure': size,
        'reason': 'Specialized policy rejected on development evidence; final evaluation complete. '
                  'Unused T03 closed: more identical sparse-reward training is not justified.',
        'no_remaining_workers_or_continuations': True,
        'source_executable_workers': 0, 'seed_search': 0, 'live_game_control': 0,
        'saves_or_player_profiles_read': 0, 'runtime_installations': 0,
        'actual_player_awards': 0,
        'continuation_rule': 'All leases and unused capacity are closed. No reuse, replacement, '
                             'renaming, new directory reset or automatic continuation.'}
    with (HERE / 'CLOSED.json').open('x', encoding='utf-8') as handle:
        json.dump(record, handle, indent=2, allow_nan=False)
        handle.write('\n')
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
