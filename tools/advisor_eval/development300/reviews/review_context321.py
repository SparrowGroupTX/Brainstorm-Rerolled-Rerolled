"""Verify immutable compact context against preserved records/audits only."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'tools/advisor_eval/runs/gold299_20260914'
FOLDER = BASE / 'release321final'
FIELDS = ('status', 'disposition', 'observed_wins', 'censored_timeouts',
          'qualification', 'passed', 'complete', 'issues', 'audit_issues')

def read(p):
    return json.loads(p.read_text(encoding='utf8'))

def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

context, outcomes, budget, limits = (read(FOLDER / f'{name}.json')
                                     for name in ('context', 'outcomes', 'budget', 'limits'))
authority = read(BASE / 'authority.json')
caps = authority['per_job_caps']
assert sum(caps.values()) == budget['reserved_total_seconds'] == 5400
assert budget['replacements'] == authority['replacements'] == 0
assert budget['expires_at_utc'] == authority['expires_at_utc']
for name, row in context['evidence'].items():
    assert sha(ROOT / row['path']) == row['sha256'], name
assert sha(ROOT / 'tools/advisor_eval/development299/checkpoint_context.py') == 'df5865cb536b51848228b6a7d999555e9ef2c067296061e58b0909ea562adf6e'
assert sha(ROOT / 'tools/advisor_eval/development299/checkpoint_context_v2.py') == limits['navigation_generator_sha256'] == '57e4aaf6762af00ab7d003dddca887a39912faebfdd52575ee553336313850d1'
assert sha(ROOT / 'tools/advisor_eval/development299/cycle.py') == limits['coordinator_sha256']

jobs = outcomes['jobs']
assert len({j['record']['job'] for j in jobs}) == len(jobs)
record_ids = {read(p)['job'] for p in BASE.glob('*/record.json') if 'job' in read(p)}
assert record_ids == {j['record']['job'] for j in jobs}
verified_records, verified_audits, selected = [], [], {}
dispositions = dict(win=0, loss=0, error=0, timeout=0, unsupported=0, censored=0, running=0, not_started=0)
for job in jobs:
    name = job['record']['job']
    folder = BASE / name
    path = folder / 'record.json'
    record = read(path)
    assert job['record'] == record and sha(path) == job['record_sha256']
    assert record['one_use_spent'] is True
    assert record['timeout_seconds'] == caps[name]
    assert (BASE / f'{name}_reservation.json').is_file()
    verified_records.append({'job': name, 'sha256': sha(path), 'status': record['status']})
    assert set(job['audits']) == {p.name for p in folder.glob('audit*.json')}
    for filename, row in job['audits'].items():
        path = folder / filename
        assert Path(filename).name == filename
        assert (ROOT / row['path']).resolve() == path.resolve()
        assert sha(path) == row['sha256']
        audit = read(path)
        actual_summary = {key: audit[key] for key in FIELDS if key in audit}
        assert row['value_is_summary'] is True and row['value'] == actual_summary
        verified_audits.append({'job': name, 'filename': filename, 'sha256': row['sha256'],
                                'audit_issue_count': len(audit.get('audit_issues', []))})
        del audit
    selection_path = folder / 'selected_audit.json'
    if selection_path.exists():
        selection = read(selection_path)
        assert sha(selection_path) == job['audit_selection']['sha256']
        assert selection == job['audit_selection']['value']
        assert selection['filename'] == job['selected_audit']
        assert selection['sha256'] == job['audits'][selection['filename']]['sha256']
        for prior in selection.get('supersedes', []):
            assert sha(folder / prior['filename']) == prior['sha256']
        selected[name] = selection
    if name.startswith('C'):
        audit = job['audits'][job.get('selected_audit', 'audit.json')]['value']
        disposition = audit.get('disposition')
        if audit.get('status') == 'audited_selected_synthetic_original_source_win' and audit.get('observed_wins') == 1:
            disposition = 'win'
        elif audit.get('status') == 'audited_selected_synthetic_timeout_censored' and audit.get('censored_timeouts') == 1:
            disposition = 'timeout'
        assert disposition in dispositions and disposition != 'not_started'
        dispositions[disposition] += 1

captured = record_ids & {'M09', 'M10', 'M19', 'M20', 'M21', 'M22'}
counts = {'source_components': len([k for k in record_ids if k.startswith('M') and k not in captured]),
          'captured_pair_jobs': len(captured),
          'captured_policy_evaluations': sum(len(list((BASE / name).glob('*_result.json'))) for name in captured),
          'search_workers': len([k for k in record_ids if k.startswith('S')]),
          'complete_attempts': len([k for k in record_ids if k.startswith('C')])}
dispositions['not_started'] = 24 - counts['complete_attempts']
assert counts == outcomes['counts'] == context['counts']
assert dispositions == outcomes['complete_attempt_outcomes'] == context['complete_attempt_outcomes']
spent = sum(caps[j['record']['job']] for j in jobs)
actual = sum(j['record']['elapsed_seconds'] for j in jobs)
assert spent == budget['spent_reserved_seconds']
assert actual == budget['actual_worker_seconds']
assert set(budget['remaining_slots']) == {k for k in caps if not (BASE / f'{k}_reservation.json').exists()}
assert context['verified_complete_win'] == (dispositions['win'] > 0)
assert selected['C08']['filename'] == 'audit_verified.json'
assert selected['C08']['sha256'] == '78210743258693ce0858f7f441e814ad13c417cfbda6b9835856f232d78a5814'
assert 'C08 exact320 S7PXV521 RedGold lost Ante1 Pillar592/600 after22 legal actions and6 exact plays' in context['outcome_summary']

receipt = {'schema': 1, 'kind': 'independent_compact_context321_review',
           'created_utc': datetime.now(timezone.utc).isoformat(),
           'conclusion': 'all_checked_counts_dispositions_references_and_totals_match',
           'context_path': (FOLDER / 'context.json').relative_to(ROOT).as_posix(),
           'context_sha256': sha(FOLDER / 'context.json'),
           'generator_sha256': limits['navigation_generator_sha256'],
           'original_context_preserved_sha256': sha(BASE / 'release321/context.json'),
           'verified_record_count': len(verified_records), 'verified_audit_count': len(verified_audits),
           'records': verified_records, 'audits': verified_audits,
           'counts': counts, 'complete_attempt_outcomes': dispositions,
           'spent_reserved_seconds': spent, 'actual_worker_seconds': actual,
           'remaining_slots': budget['remaining_slots'], 'c08_selected_audit': selected['C08'],
           'notes': ['V2 adds only audit_issues to compact summaries; original generator/context remain untouched.',
                     'All full audit hashes and complete explicit summary fields were independently verified.',
                     'C08 narrative matches selected loss audit and preserved C05 comparison: no changed action or terminal improvement.',
                     'The single verified win belongs to selected synthetic C01/frozen300, not current policy, player achievement or Jokerless.',
                     'This read-only review does not register, reserve, renew or execute experiments.']}
target = Path(__file__).with_suffix('.json')
with target.open('x', encoding='utf8') as stream:
    json.dump(receipt, stream, indent=2)
    stream.write('\n')
print(json.dumps({'receipt': target.relative_to(ROOT).as_posix(), 'sha256': sha(target),
                  'context_sha256': receipt['context_sha256'], 'records': len(verified_records),
                  'audits': len(verified_audits), 'counts': counts, 'outcomes': dispositions,
                  'spent_reserved_seconds': spent, 'actual_worker_seconds': actual}))
