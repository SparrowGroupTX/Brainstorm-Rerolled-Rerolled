"""Read-only exact-byte review receipt; no policy/source worker or staging."""
from pathlib import Path
import datetime
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
HERE = ROOT / 'tools/advisor_eval/development300/yorick_pair321'
EXPECTED = 'a58495db2ab8e0e471ad9b6e840d218e655f29146e07853acc8a684559aac466'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest_path = HERE / 'manifest.json'
assert sha(manifest_path) == EXPECTED
manifest = json.loads(manifest_path.read_text())
verified = []
for row in manifest['package_files']:
    path = HERE / row['path']
    assert sha(path) == row['sha256'], str(path)
    verified.append({'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)})
for row in manifest['dependencies']:
    path = ROOT / row['path']
    assert sha(path) == row['sha256'], str(path)
    verified.append({'path': row['path'], 'sha256': sha(path)})
source = manifest['preserved_source']
assert sha(ROOT / source['path']) == source['sha256']
for row in manifest['integration']:
    assert sha(HERE / row['source']) == row['sha256']
    target = ROOT / row['target']
    if row['base_sha256']:
        assert sha(target) == row['base_sha256']
    else:
        assert not target.exists(), 'Review expects root staging still pending'

receipt = {
    'schema': 1,
    'kind': 'independent_yorick_pair321_review',
    'reviewer': '/root/gold_search300',
    'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'conclusion': 'no_remaining_blocking_finding',
    'manifest_sha256': EXPECTED,
    'growth_sha256': manifest['integration'][0]['sha256'],
    'fixture_sha256': manifest['integration'][1]['sha256'],
    'verified_files': verified,
    'preserved_source': source,
    'independent_routine_test': {
        'command': ['python', '-B', 'tests/run_lua_tests.py',
                    'tools/advisor_eval/development300/yorick_pair321/run_candidate.lua',
                    'tools/advisor_eval/development300/yorick_pair321/run_existing.lua'],
        'exit_code': 0,
        'new_checks': 18630,
        'existing_checks': 2680,
        'total_checks': 21310,
        'draw_order_signatures': 720,
        'complete_count_families': 24,
        'selected_card_orders': 120,
        'scope': 'Manufactured pure Lua fixtures only; isolated lua51.dll test runtime.'
    },
    'reviewed_guarantees': [
        'Canonical selected unsealed Steel has played x_mult=1 and held h_x_mult=1.5; all prior selected-card additive bounds remain.',
        'Both counts fit actual discard limits and deck capacity; all unreserved population cards have identity held and draw effects.',
        'Whole hand/deck observations must match unique population IDs and all fields; no invented draw endpoint is constructed.',
        'All legal second counts are compared for each admitted first count; six existing shortlist scores and twelve total growth scores remain.',
        'Only a physical Yorick threshold missed by the first action receives pair credit; copying does not duplicate physical growth.',
        'Both action, paid cash, forgone discard reward and incremental interest costs are included.',
        'Only the first discard is returned; second action requires a fresh observation and a new decision.',
        'Burnt, bosses, unknown modifiers/vouchers, concealed cards and nonneutral spare/remaining population decline the pair proof.',
        'Complete owned inventory, including Negative Observatory cards, is retained without use or generated cards.',
        'Strict plain-input bounds apply to all growth paths; all five prior growth fixture suites pass unchanged.'
    ],
    'resolved_review_findings': [
        'Added exact positive playable-hand and hand-phase admission.',
        'Excluded physical Yorick expiring at this blind end.',
        'Corrected fixture draw helper to append in specified order and assert 720 distinct signatures.',
        'Documented global all-growth input bounds and added complete count-family, paid-cost and history coverage.'
    ],
    'limits': [
        'The neutral-pool proof and retained-score floor concern this blind, not future shuffle outcomes or global optimality.',
        'Development utility and action costs remain uncalibrated; fixture counts are not run win-rate evidence.',
        'No captured-state evaluation, original-source run, native search, player data access, runtime staging or installation was performed by this review.',
        'Root must complete normal full regression, installation and exact-installed validation before release.'
    ]
}
target = Path(__file__).with_suffix('.json')
with target.open('x', encoding='utf8') as stream:
    json.dump(receipt, stream, indent=2)
    stream.write('\n')
print(json.dumps({'path': target.relative_to(ROOT).as_posix(), 'sha256': sha(target),
                  'conclusion': receipt['conclusion'], 'verified_files': len(verified)}))
