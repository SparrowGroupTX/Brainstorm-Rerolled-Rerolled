"""Explicit root-only closure; importing/--describe never closes authority."""
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal
import argparse
import hashlib
import json
import os
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
AUTHORITY_SHA = '072acbbdbbe8698913ab474a17b0d36023550b4d2c0a54ae67ca2d6d101526bb'
CAPS = {**{f'S{i:02}': 30 for i in range(1, 13)}, **{f'M{i:02}': 30 for i in range(1, 25)},
        **{f'C{i:02}': 180 for i in range(1, 25)}}


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def encoded(value):
    return (json.dumps(value, indent=2, allow_nan=False) + '\n').encode()


def atomic_new(path, value):
    """An atomic hard-link publication cannot overwrite an existing receipt."""
    path = Path(path)
    prepared = path.with_name(path.name + '.prepared.' + uuid.uuid4().hex)
    with prepared.open('xb') as stream:
        stream.write(encoded(value)); stream.flush(); os.fsync(stream.fileno())
    os.link(prepared, path)  # fails if target exists; prepared evidence is retained


def scan(base=BASE, expected_authority=AUTHORITY_SHA):
    base = Path(base).resolve()
    authority_path = base / 'authority.json'
    assert sha(authority_path) == expected_authority, 'Authority changed'
    authority = read(authority_path)
    assert authority['status'] == 'APPROVED' and authority['per_job_caps'] == CAPS
    assert authority['reserved_worker_seconds'] == sum(CAPS.values()) and authority['replacements'] == 0
    assert not (base / 'C09').exists() and not (base / 'C09_reservation.json').exists(), 'C09 must remain unregistered/unrun'
    cache = {}
    def checked(path, expected):
        path = Path(path).resolve()
        if path not in cache: cache[path] = sha(path)
        assert cache[path] == expected, f'Changed bound input: {path}'
    reservations = {p.name.removesuffix('_reservation.json'): p for p in base.glob('*_reservation.json')}
    assert set(reservations) <= CAPS.keys(), 'Unknown reservation'
    job_dirs = {p.name for p in base.iterdir() if p.is_dir() and re.fullmatch(r'[CMS]\d+', p.name)}
    assert job_dirs == set(reservations), 'Unaccounted job directory or reservation'
    jobs = []; total = Decimal(0)
    for job, reservation_path in sorted(reservations.items()):
        folder = base / job
        reservation = read(reservation_path); reg = read(folder / 'registration.json')
        spent = read(folder / 'spent.json'); record = read(folder / 'record.json')
        assert reservation['job'] == reg['job'] == spent['job'] == record['job'] == job
        assert reservation['one_use'] is True and spent['one_use'] is True and record['one_use_spent'] is True
        assert reservation['timeout_seconds'] == reg['timeout_seconds'] == record['timeout_seconds'] == CAPS[job]
        assert reservation['authority_sha256'] == reg['authority_sha256'] == expected_authority
        assert reg['reservation_sha256'] == sha(reservation_path)
        assert spent['registration_sha256'] == record['registration_sha256'] == sha(folder / 'registration.json')
        assert record['status'] in ('complete', 'error', 'timeout')
        assert record['frozen_files_unchanged'] is True and record['external_files_unchanged'] is True
        checked(folder / 'trace.log', record['trace_sha256'])
        for relative, expected in reg['files'].items():
            target = (folder / relative).resolve()
            assert target.is_relative_to(folder.resolve()) and target != folder.resolve()
            checked(target, expected)
        for external, expected in reg.get('external_files', {}).items(): checked(external, expected)
        seconds = json.loads((folder / 'record.json').read_text(), parse_float=Decimal)['elapsed_seconds']
        seconds = Decimal(seconds); assert seconds.is_finite() and seconds >= 0
        total += seconds
        audits = {}
        for path in sorted(folder.glob('audit*.json')):
            value = read(path)
            audits[path.name] = {'sha256': sha(path), 'summary': {k: value[k] for k in
                ('status', 'disposition', 'observed_wins', 'censored_timeouts', 'qualification', 'passed',
                 'complete', 'issues', 'audit_issues') if k in value}}
        selected = 'audit.json'; selector = None
        if (folder / 'selected_audit.json').exists():
            selector = read(folder / 'selected_audit.json'); selected = selector['filename']
            assert Path(selected).name == selected and selected in audits
            assert selector['sha256'] == audits[selected]['sha256']
            for old in selector.get('supersedes', []):
                assert Path(old['filename']).name == old['filename'] and audits[old['filename']]['sha256'] == old['sha256']
        jobs.append({'job': job, 'status': record['status'], 'timeout_seconds': CAPS[job],
            'elapsed_seconds_decimal': str(seconds), 'reservation_sha256': sha(reservation_path),
            'registration_sha256': sha(folder / 'registration.json'), 'spent_sha256': sha(folder / 'spent.json'),
            'record_sha256': sha(folder / 'record.json'), 'trace_sha256': record['trace_sha256'], 'audits': audits,
            'selected_audit': selected if selected in audits else None,
            'audit_selector_sha256': sha(folder / 'selected_audit.json') if selector else None})
    unused = [job for job in CAPS if job not in reservations]
    budget = {'authorized_slots': len(CAPS), 'authorized_cap_seconds': sum(CAPS.values()),
        'spent_jobs': len(jobs), 'spent_reserved_seconds': sum(j['timeout_seconds'] for j in jobs),
        'actual_worker_seconds_decimal': str(total), 'actual_worker_seconds': float(total),
        'unused_slots': unused, 'unused_cap_seconds': sum(CAPS[j] for j in unused),
        'by_kind': {kind: {'spent_jobs': sum(j['job'].startswith(kind) for j in jobs),
            'spent_reserved_seconds': sum(j['timeout_seconds'] for j in jobs if j['job'].startswith(kind)),
            'actual_worker_seconds_decimal': str(sum((Decimal(j['elapsed_seconds_decimal']) for j in jobs if j['job'].startswith(kind)), Decimal(0))),
            'unused_slots': [j for j in unused if j.startswith(kind)]} for kind in 'SMC'}}
    payload = {'schema': 1, 'authority_sha256': expected_authority, 'expires_at_utc': authority['expires_at_utc'],
        'jobs': jobs, 'budget': budget, 'C09': 'never_registered_reserved_or_run', 'all_reserved_jobs_spent_and_recorded': True,
        'all_registered_frozen_external_and_trace_hashes_verified': True}
    payload['ledger_digest'] = hashlib.sha256(encoded(payload)).hexdigest()
    return payload


def active_workers():
    # All registered experiment commands are Python adapters. Inspect only
    # Python processes; do not query/control the running game or its files.
    command = "@(Get-CimInstance Win32_Process -Filter \"Name LIKE 'python%'\" | Select-Object ProcessId,CommandLine) | ConvertTo-Json -Compress"
    result = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', command],
        capture_output=True, text=True, check=True, timeout=15, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    rows = json.loads(result.stdout or '[]'); rows = rows if isinstance(rows, list) else [rows]
    active = []
    for row in rows:
        if row['ProcessId'] == os.getpid(): continue
        line = row.get('CommandLine')
        if not line or 'advisor_eval' in line.lower() or 'gold299_20260914' in line.lower(): active.append(row)
    return active


def close(base, expected_authority, expected_ledger, workers=active_workers, now=None):
    base = Path(base); assert not (base / 'CLOSED.json').exists(), 'Already closed; never overwrite'
    current = now or datetime.now(timezone.utc)
    first = scan(base, expected_authority)
    assert first['ledger_digest'] == expected_ledger, 'Ledger changed since review'
    assert current >= datetime.fromisoformat(first['expires_at_utc']), 'This helper closes expired authority only'
    assert not workers(), 'Experiment/coordinator Python process is still active or unidentifiable'
    second = scan(base, expected_authority)
    assert second == first, 'Receipt set changed during closure verification'
    value = {**first, 'kind': 'gold299_expired_cycle_closure', 'status': 'CLOSED', 'reason': 'original_authority_expired',
        'closed_at_utc': current.isoformat(), 'unused_slots_closed': first['budget']['unused_slots'],
        'remaining_authority_seconds': 0, 'replacements': 0, 'renewals': 0,
        'worker_check': 'All reservations have spent+record and matching registered Python workers are absent.',
        'coordinator_rule': 'Root invoked explicit closure with no concurrent registration/dispatch; CLOSED prevents all later old-coordinator jobs.',
        'tool_sha256': sha(Path(__file__))}
    atomic_new(base / 'CLOSED.json', value)
    return value


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--describe', action='store_true'); mode.add_argument('--close', action='store_true')
    parser.add_argument('--expected-ledger-digest'); args = parser.parse_args()
    if args.describe:
        value = scan(); print(json.dumps({'ledger_digest': value['ledger_digest'], 'budget': value['budget'], 'C09': value['C09']})); return
    assert args.expected_ledger_digest, 'Review --describe first and supply its digest'
    value = close(BASE, AUTHORITY_SHA, args.expected_ledger_digest)
    print(json.dumps({'closed_sha256': sha(BASE / 'CLOSED.json'), 'budget': value['budget']}))


if __name__ == '__main__': main()
