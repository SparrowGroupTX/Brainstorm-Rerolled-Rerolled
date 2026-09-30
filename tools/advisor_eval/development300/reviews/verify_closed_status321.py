"""Post-publication hash/navigation check only; no tests or experiments."""
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
ARCHIVE = ROOT / 'tools/advisor_eval/runs/status321_closed_final'
NAV = ('ADVISOR_START_HERE.md', 'ADVISOR_RESUME_PROMPT.md', 'ADVISOR_HANDOFF.md')

def read(path):
    return json.loads(path.read_text(encoding='utf8'))

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

before = read(Path(__file__).with_name('closure_navigation_before321.json'))['files']
publication = read(ARCHIVE / 'status_verification.json')
assert publication['runtime_changed'] is False and publication['status'] == 'published_closed_status_only'
for name, expected in before.items():
    if name in NAV:
        archived = ARCHIVE / 'previous_navigation' / name
        assert sha(archived) == expected == publication['old_navigation_archives'][name]
    else:
        assert sha(ROOT / name) == expected, 'Immutable release evidence changed: ' + name
for name, expected in publication['new_files'].items():
    assert sha(ROOT / name) == expected
status = read(ROOT / 'tools/advisor_eval/SESSION_STATUS_321_CLOSED.json')
context_path = ROOT / status['context']['path']
assert sha(context_path) == status['context']['sha256'] == publication['context_sha256']
context = read(context_path)
assert status['status'] == context['status'] == 'CLOSED'
assert status['policy_digest'] == context['policy_digest'] == 'fd5c42031000f79ecba48ceee72f000aa3d1b7a0c51ed54895d36cfab53e4da5'
assert context['remaining_authority_seconds'] == context['replacements'] == context['renewals'] == 0
closure_path = BASE / 'CLOSED.json'
assert sha(closure_path) == '3699b13e0dbe829c5bfd8486ab4f235118200f3ee3f20a7ac28614e12a7c0f91'
closure = read(closure_path)
assert status['evidence']['closed_cycle']['sha256'] == sha(closure_path)
assert not (BASE / 'C09').exists() and not (BASE / 'C09_reservation.json').exists()
assert context['C09'] == status['C09'] == 'never_registered_reserved_or_run'
assert len(context['jobs']) == len(closure['completed_job_records']) == 38
closed_records = {row['job']: row for row in closure['completed_job_records']}
total = Decimal(0)
for row in context['jobs']:
    job = row['job']
    path = BASE / job / 'record.json'
    assert row['record_sha256'] == closed_records[job]['record_sha256'] == sha(path)
    record = json.loads(path.read_text(), parse_float=Decimal)
    total += Decimal(record['elapsed_seconds'])
budget = context['budget']
assert budget == status['budget']
assert budget['spent_jobs'] == 38 and budget['spent_reserved_seconds'] == closure['spent_reserved_seconds'] == 2340
assert Decimal(budget['actual_worker_seconds_decimal']) == total
assert len(context['unused_slots_closed']) == len(closure['closed_unused_slots']) == 22
assert set(context['unused_slots_closed']) == set(budget['unused_slots']) == set(closure['closed_unused_slots'])
assert context['complete_attempt_outcomes'] == status['complete_attempt_outcomes'] == {
    'win': 1, 'loss': 3, 'error': 0, 'timeout': 4, 'unsupported': 0, 'censored': 0}
for name in NAV:
    text = (ROOT / name).read_text(encoding='utf8')
    assert 'SESSION_STATUS_321_CLOSED' in text
    assert 'C09' in text and 'CLOSED' in text
assert sha(ROOT / 'tools/advisor_eval/runs/pair321_final/final_verification.json') == '268fc4f65cdefb34b575876f3df778290ecc587e993ed11e7d076e86d107260d'

receipt = {'schema': 1, 'kind': 'independent_closed_status321_publication_review',
           'created_utc': datetime.now(timezone.utc).isoformat(),
           'conclusion': 'no_remaining_blocking_finding',
           'closure_sha256': sha(closure_path),
           'publication_receipt_sha256': sha(ARCHIVE / 'status_verification.json'),
           'context_sha256': sha(context_path),
           'new_files': publication['new_files'], 'archived_navigation': publication['old_navigation_archives'],
           'immutable_baseline_files_unchanged': [name for name in before if name not in NAV],
           'job_records_rechecked': 38, 'unused_slots_closed': 22,
           'spent_reserved_seconds': 2340, 'actual_worker_seconds_decimal': str(total),
           'outcomes': context['complete_attempt_outcomes'],
           'C09': 'Unregistered, unreserved, unrun; no result. Original authority expired and closed.',
           'scope': 'Publication hashes, archived prior navigation, immutable321 evidence and closed ledger only. No runtime writes, tests or source/policy/native/game execution.'}
target = Path(__file__).with_suffix('.json')
with target.open('x', encoding='utf8') as stream:
    json.dump(receipt, stream, indent=2)
    stream.write('\n')
print(json.dumps({'receipt': target.relative_to(ROOT).as_posix(), 'sha256': sha(target),
                  'context_sha256': receipt['context_sha256'], 'conclusion': receipt['conclusion']}))
