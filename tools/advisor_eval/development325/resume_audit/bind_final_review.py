"""Hash-bind completed read-only325 lifecycle review; no product imports or tests."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
PRIMARY = {
    'Brainstorm/Advisor/auto_run.lua': '301303671238c4795ab960fcb74ec3d6fa33253517de8348f189a7c2cdb664ac',
    'Brainstorm/Core/auto_run_product.lua': '73741fd90326790142240041a7f40936f4caa3d2785250fc905f5f545af65996',
}
INTEGRATION = [
    'Brainstorm/Core/auto_terminal.lua', 'Brainstorm/Core/checkpoint_runtime.lua',
    'Brainstorm/Core/Brainstorm.lua', 'Brainstorm/Advisor/runtime.lua',
    'Brainstorm/UI/advisor.lua', 'Brainstorm/UI/collection_run.lua',
]

def sha(data):
    return hashlib.sha256(data).hexdigest()

def record(path):
    data = path.read_bytes()
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(data), 'bytes': len(data)}

primary = []
for relative, expected in PRIMARY.items():
    item = record(ROOT / relative)
    if item['sha256'] != expected:
        raise SystemExit('Reviewed primary bytes changed: ' + relative)
    primary.append(item)
frozen = ROOT / 'tools/advisor_eval/runs/timing324_installed/policy'
baselines = [record(frozen / relative) for relative in PRIMARY]
focused_path = ROOT / 'tools/advisor_eval/development325/resume_tests/focused_report.json'
focused_receipt = record(focused_path)
if focused_receipt['sha256'] != '8a2790c17fd8ae9a308f7082a127dbae304f7ccb4971d54d5b2f5431f8c648a8':
    raise SystemExit('Focused validation record changed')
focused = json.loads(focused_path.read_text())
if focused['status'] != 'passed' or focused['total_checks'] != 1320:
    raise SystemExit('Unexpected focused validation result')
for relative, expected in PRIMARY.items():
    if focused['file_hashes_recorded_after_run'][relative] != expected:
        raise SystemExit('Focused record does not bind reviewed bytes: ' + relative)
report = {
    'schema': 1,
    'status': 'no_remaining_blocking_dispatch_or_lifecycle_defect_found_in_reviewed_bytes',
    'scope': 'Independent read-only integrated325 controller/product review against exact frozen324',
    'primary_sources': primary,
    'frozen324_baselines': baselines,
    'integration_sources_at_binding': [record(ROOT / p) for p in INTEGRATION],
    'reviewed_terminal_comment_sha256': '985b9da3405506bfdd552d0d62b8eaaca1f3136c00452a872e8f90b7496fc230',
    'terminal_comment_correction': 'Read-only diff versus frozen324 confirmed comments only',
    'input_guard_addendum': 'Core fast-reroll hotkey now returns before replacing the run while auto is engaged; same existing ownership predicate as search hotkey',
    'resolved_findings': [
        'Nonresumable clock/observation failure while stopped clears the resume point and diagnostic',
        'Verified terminal receipt precedes hard limits and Resume complete/unknown goal rejection',
        'Already-finalized terminal cannot starve later search polling/deadlines',
        'Input/Stop exclusion clamps watchdog timestamp to present rather than granting future time',
        'Resume readiness clock rejects observed regression between wait frames',
        'Checkpoint eligibility wait retains hard session/run checks and bounded additional wait',
        'Staged ordinary-input paths preserve auto search ownership; explicit Stop is distinct',
        'Verified activated checkpoint notification enables explicit logged manual continuation',
    ],
    'confirmed_invariants': [
        'Resume does not reset session/run counters, immutable configuration or hard elapsed origins',
        'Playing, pending-action, accepted-found and accepted-starting Resume do not search',
        'Pending action is not replayed; exact settled unsupported publication can acknowledge it',
        'Owned cancelled search drains and late found is discarded',
        'Explicit Resume after cancelled search logs distinct new product-search authorization',
        'Original terminal binding survives explicit Stop; manual restoration starts only new future evidence',
        'Live fingerprint/action/generation/GAME validation remains at both Execute gates',
        'Profile identity, uncertain callbacks, logging and elapsed limits remain explicit',
    ],
    'search_semantics': {
        'after_explicit_stop_and_verified_drain': 'Explicit Resume authorizes a distinct new bounded product search',
        'prior_allocation': 'Cancelled and preserved; never refunded/reused',
        'preserved': ['session identity', 'configuration', 'counters', 'cursor', 'absolute session limit'],
        'not_claimed': 'One cumulative30-second native allowance across separate explicit Resume clicks',
        'tool_experiment_authority': 'None; all historical tool experiment budgets remain CLOSED',
    },
    'reviewer_execution_counts': {'fixtures': 0, 'policy': 0, 'source': 0, 'search': 0, 'captured': 0, 'gameplay': 0},
    'external_reads': {'player_logs': 0, 'saves': 0, 'profiles': 0, 'game_executable': 0},
    'validation': {'test_owner_receipt': focused_receipt, 'checks': focused['checks'],
                   'total_checks': focused['total_checks'], 'reviewer_executed': False,
                   'limit': 'Exact full regression and installation validation remain separate release records'},
    'earlier_design_evidence_preserved': [record(HERE / p) for p in ('AUDIT.md', 'report.json', 'manifest.json')],
    'review_note': record(HERE / 'FINAL_REVIEW.md'),
    'limits': ['No gameplay or performance result', 'No loaded activation confirmation',
               'No win-rate/cohort qualification', 'No claim that manual public-state changes identify hidden RNG'],
}
with (HERE / 'final_review.json').open('x', encoding='utf-8', newline='\n') as stream:
    json.dump(report, stream, indent=2)
    stream.write('\n')
manifest = {'schema': 1, 'files': [record(HERE / p) for p in ('FINAL_REVIEW.md', 'final_review.json', 'bind_final_review.py')]}
with (HERE / 'final_review_manifest.json').open('x', encoding='utf-8', newline='\n') as stream:
    json.dump(manifest, stream, indent=2)
    stream.write('\n')
print(json.dumps({'review_sha256': sha((HERE / 'final_review.json').read_bytes()),
                  'manifest_sha256': sha((HERE / 'final_review_manifest.json').read_bytes())}))
