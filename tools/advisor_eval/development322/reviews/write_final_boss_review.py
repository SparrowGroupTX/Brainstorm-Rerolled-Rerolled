"""Record the independent read-only review; never stage or run policy work."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PACKAGE = ROOT / 'tools/advisor_eval/development322/bell_routing'
BASE = ROOT / 'tools/advisor_eval/runs/pair321_installed/policy'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest_path = PACKAGE / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
package_checks = []
for row in manifest['package_files']:
    p = PACKAGE / row['path']
    actual = sha(p)
    assert actual == row['sha256'], ('Detached package changed', str(p))
    package_checks.append({'path': p.relative_to(ROOT).as_posix(), 'sha256': actual})
dependencies = []
for row in manifest['dependencies']:
    actual = sha(ROOT / row['path'])
    dependencies.append({**row, 'reviewed_current_sha256': actual, 'matches_package': actual == row['sha256']})
    if actual != row['sha256']:
        assert row['path'] == 'Brainstorm/Advisor/shop_scoring.lua', ('Unexpected dependency drift', row['path'])
files = [
    'Brainstorm/Advisor/gold_planet_policy.lua', 'Brainstorm/Advisor/shop_scoring.lua',
    'Brainstorm/Advisor/gold_goal.lua', 'Brainstorm/Advisor/perkeo_inventory.lua',
    'Brainstorm/Advisor/bell_opening.lua', 'Brainstorm/Advisor/decision.lua',
    'tests/advisor_gold_planet_policy.lua', 'tests/advisor_shop_scoring.lua',
]
reviewed = [{'path': f, 'sha256': sha(ROOT / f)} for f in files]
baselines = []
for f in files[:2]:
    # Frozen policy uses paths relative to repository root.
    p = BASE / f
    assert p.is_file(), p
    baselines.append({'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p)})
record = {
    'schema': 1, 'status': 'accepted_no_blocking_finding',
    'reviewer': 'checkpoint_logging299', 'created_at_utc': datetime.now(timezone.utc).isoformat(),
    'scope': 'Read-only code/diff review plus four manufactured Lua fixtures. No captured input, source execution, search, game/player-file access, staging, installation or runtime edits.',
    'reviewed_files': reviewed, 'baseline_files': baselines,
    'bell_manifest': {'path': manifest_path.relative_to(ROOT).as_posix(), 'sha256': sha(manifest_path)},
    'bell_package_hashes_verified': package_checks, 'bell_dependency_checks': dependencies,
    'findings': [],
    'integration_note': 'The Bell package declares frozen321 shop_scoring, while this review and the independent fixture run use the new root shop_scoring hash recorded above. Bind that reviewed dependency in final release evidence; the package itself remains unchanged.',
    'reasoning': [
        'The Planet fast path is reached only after the existing final supported boss, complete eligible Gold metadata, visible stable retained Joker and whole homogeneous ordinary/Negative Planet inventory guards.',
        'The probe evaluates every legal-size subset in each of four deterministic common composition worlds with the current physical row. Bell requires every possible forced physical identity, and both endpoints retain the same whole inventory. No free reorder, consumed Planet, temporal last-hand/discard credit or startup generation is used.',
        'The default false/nil option preserves existing prepare/layout/equivalence/temporal/finishing behavior. Per-context profile caches prevent cross-mode reuse; family_key explicitly distinguishes the option. Within the new mode, full physical row keys remain distinct and the row-equivalence shortcut is disabled.',
        'Complete pair cost is checked before scoring. A failed or insufficient probe spends its actual calls from the same maximum50000 allowance, and the complete family fallback receives only the remainder. Partial coverage cannot select an action.',
        'Bell routing completes the collector rather than exiting after the first strong play. The unchanged5000 route cap includes intermediate after_play score calls; incomplete, uncertain, missing-dependency and weak-forced-card families decline. Small-to-Big-to-Bell retains both supported single-Glass intermediate outcomes.',
        'Bell routing reconciles physical distinct held missing Gold keys with complete metadata before forgoing the final shop. The current row is fixed, and existing rental, cash, inventory-copying and growth opportunity heuristics remain charged.',
    ],
    'validation': {
        'command': 'python tests/run_lua_tests.py tests/advisor_gold_planet_policy.lua tests/advisor_shop_scoring.lua tools/advisor_eval/development322/bell_routing/run_candidate.lua tools/advisor_eval/development322/bell_routing/run_existing.lua',
        'exit_code': 0, 'fixtures_passed': 4,
        'checks': {'gold_planet_policy': 181, 'shop_scoring': 60, 'bell_routing': 236, 'existing_blind_routing': 55},
        'total_checks': 532,
        'manufactured_local_comparison': {'current_row_hold_score_calls': 12, 'current_row_hold_preparation_actions': 0, 'complete_use_family_score_calls': 72, 'complete_use_family_consumable_actions': 1},
        'includes': 'Bell exhaustive actual-forced-flag oracle32branches, late uncertain subset rejection, exact/insufficient caps, weak off-rank trap, physical copy-row separation, startup rejection, no continuation call with loaded finishing dependency, unchanged source fingerprints.'
    },
    'limits': [
        'Four fixed composition worlds do not enumerate future draws and do not establish a win probability, guaranteed clear, calibrated speed benefit or superiority over a human.',
        'The2x sufficiency choice intentionally favors fewer setup actions over maximal modeled opening score; it is a declared local heuristic, not a complete proof that holding dominates every future policy.',
        'The route opportunity-cost model is inherited and uncalibrated. It does not predict future acquisitions, generated copy identities or actual Gold-sticker awards.',
        'Only ordinary manufactured validation ran; no new source/captured/complete-attempt authority was used. Full coordinated candidate/installed regression and final hash verification remain the parent responsibility.'
    ]
}
output = HERE / 'review_final_boss322.json'
with output.open('x', encoding='utf-8', newline='\n') as f:
    json.dump(record, f, indent=2)
    f.write('\n')
note = HERE / 'review_final_boss322.md'
with note.open('x', encoding='utf-8', newline='\n') as f:
    f.write('Independent final-boss322 review: accepted, no blocking implementation finding.\n\n')
    f.write('Reviewed the root Planet sufficiency/shop-scoring changes against frozen321 and the detached Bell routing code, fixture and package hashes. The new mode retains the actual row and whole inventory, requires complete four-world opening evidence (including every Bell forced identity), rejects startup/temporal/continuation credit, and charges its probe against the existing50000 fallback allowance. Default mode remains unchanged. Bell routing completes all forced branches under its existing5000 cap and retains intermediate Glass/resource checks.\n\n')
    f.write('Independent validation passed4/4 manufactured fixtures,532 checks. One manufactured strong opening required12 score calls and no preparation action, versus72 calls and one Planet use for the full family. These are local counts, not a runtime benchmark or full-run improvement.\n\n')
    f.write('The detached Bell manifest still names frozen321 shop_scoring. This review binds the actual new root dependency and validates it jointly; bind that hash in final release evidence. No detached or runtime files were changed by this review.\n\n')
    f.write('The2x threshold and route opportunity costs remain uncalibrated heuristics. Four composition samples do not establish future draws, win odds or a Gold-sticker award. No source worker, captured replay, search, game control, player-file access or installation was performed. Full coordinated release validation remains pending.\n\n')
    f.write('Exact hashes, coverage and limitations: review_final_boss322.json.\n')
print(json.dumps({'record': output.relative_to(ROOT).as_posix(), 'sha256': sha(output), 'note': note.relative_to(ROOT).as_posix(), 'note_sha256': sha(note)}))
