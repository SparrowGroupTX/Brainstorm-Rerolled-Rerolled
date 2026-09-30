"""Seal revision2 without replacing earlier evidence."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[5]
revision = Path(__file__).resolve().parent
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
files = []
for relative in ('Brainstorm/Advisor/gold_acquisition.lua', 'tests/advisor_gold_acquisition.lua', 'tests/advisor_gold_acquisition_runtime.lua'):
    path = revision / relative
    files.append({'destination': relative, 'staged_path': str(path.relative_to(root)), 'sha256': digest(path)})
receipts = []
for path in sorted(revision.glob('validation_*.json')):
    record = json.loads(path.read_text(encoding='utf-8'))
    receipts.append({'path': str(path.relative_to(root)), 'sha256': digest(path), 'exit_code': record['exit_code'],
                     'expected_failure': record['expected_failure'], 'seconds': record['seconds'],
                     'inputs_unchanged': record['inputs_unchanged']})
record = {'schema': 1, 'release': 344, 'revision': 2, 'status': 'staged_review_ready',
          'files': files, 'validation': receipts, 'checks': {'main': 147, 'production_wired_coroutine': 25, 'total': 172},
          'score_floor_calls': {'main': 1690, 'production_wired_coroutine': 360}, 'cooperative_yields': 4,
          'supersedes': str((revision.parent / 'result.json').relative_to(root)),
          'change_from_revision1': 'Remove comparison-level pcall so the existing yielding Shop loop does not depend on yielding across protected C-call boundaries. Synchronous score-floor qualification retains pcall. Unexpected comparison errors propagate to existing worker error handling.',
          'baseline_result': 'The initial expectation of reproducing a Lua 5.1 pcall/yield failure was not confirmed: preserved revision1 also passed the full production-wired coroutine fixture against the installed lua51.dll, with25checks/360floorcalls/4yields. The before receipt preserves that successful result and its original expected-failure label.',
          'accounting': 'Explicit incomplete, unsupported, truncated or context-accounting mismatches still return all actual floor calls. An unexpected thrown comparison produces no returned suggestion and propagates to the normal worker error surface.',
          'unchanged_scope': 'Complete declared fixed-current-row/hold-all endpoint family, winning-Ante pre-Small/Big only, exact paid missing-Joker acquisition with preserved original inventory and1.25next-target sampled floor margin. No terminal benefit is established.',
          'promotion': ['Copy revision2 module to Brainstorm/Advisor/gold_acquisition.lua.',
                        'Main fixture: replace staged module load with production module; bind Support.Hold to production gold_tarot_hold if fixture_support remains the raw builder.',
                        'Runtime fixture: remove the ACQUISITION_TEST_MODULE override line or default it to the production module so runtime.lua wiring is authoritative.'],
          'production_paths_written_by_component': False,
          'experiment_jobs': {'source_components': 0, 'captured_policy_replays': 0, 'searches': 0, 'complete_attempts': 0},
          'live_game_control': False, 'save_profile_reads': False}
with (revision / 'result.json').open('x', encoding='utf-8') as stream:
    json.dump(record, stream, indent=2)
    stream.write('\n')
print(json.dumps({'files': files, 'result_sha256': digest(revision / 'result.json')}))
