"""Record independent code review and already completed manufactured checks."""
import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def item(path):return {'path':path,'sha256':sha(ROOT/path)}

auto=ROOT/'tools/advisor_eval/development323/auto_observation'
snapshot=ROOT/'tools/advisor_eval/development323/snapshot_idle'
auto_manifest=json.loads((auto/'integration_manifest.json').read_text())
assert sha(auto/'integration_manifest.json')=='7d17b69ed9c00ac7b015867625f2a212b6218c38d14f2153ce37786292100578'
for f,h in auto_manifest['files'].items():assert sha(auto/f)==h,f
snapshot_manifest=json.loads((snapshot/'manifest.json').read_text())
assert sha(snapshot/'manifest.json')=='b9b7a230226e006ec1dba3d71dad5a04479c8848f0cd139e9f2670fab0b2c42a'
for f in snapshot_manifest['package_files']:assert sha(snapshot/f['path'])==f['sha256'],f
for f in snapshot_manifest['dependencies']:assert sha(ROOT/f['path'])==f['sha256'],f
source=snapshot_manifest['preserved_source']
assert sha(ROOT/source['path'])==source['sha256']
assert sha(ROOT/'Brainstorm/Advisor/snapshot.lua')==snapshot_manifest['integration'][0]['sha256']
record={
 'schema':1,'status':'accepted_no_blocking_finding','reviewer':'checkpoint_logging299',
 'created_at_utc':datetime.now(timezone.utc).isoformat(),
 'scope':'Independent read-only review of drag coalescing, HUD-only snapshot omission and revision2 auto-observation readiness gating. Ordinary manufactured fixtures only; no source execution, captured replay, search, game control, player files, staging or installation.',
 'files':[item(p) for p in [
  'Brainstorm/Advisor/runtime.lua','Brainstorm/Advisor/snapshot.lua','tests/advisor_runtime.lua',
  'Brainstorm/Advisor/auto_run.lua','Brainstorm/Advisor/player_journal.lua','Brainstorm/Advisor/player_log_archive.lua',
  'tools/advisor_eval/development323/snapshot_idle/manifest.json',
  'tools/advisor_eval/development323/auto_observation/integration_manifest.json',
  'tools/advisor_eval/development323/auto_observation/auto_run_product.lua',
  'tools/advisor_eval/development323/auto_observation/advisor_auto_observation.lua',
  'tools/advisor_eval/runs/pace322_installed/policy/Brainstorm/Advisor/runtime.lua',
  'tools/advisor_eval/runs/pace322_installed/policy/Brainstorm/Advisor/snapshot.lua',
  'tools/advisor_eval/runs/pace322_installed/policy/Brainstorm/Core/auto_run_product.lua',
  source['path']]],
 'package_integrity':'Every declared auto revision2 file and every declared snapshot package/dependency file rehashed successfully. Snapshot preserved-source hash and staged snapshot exact candidate hash also matched.',
 'findings':[],
 'accepted_invariants':[
  'Drag coalescing occurs after active/ready cancellation checks. A drag prevents captures, fingerprints, new decisions and worker resumes. Pending release blocks Select and Execute until a complete fresh capture/fingerprint/retry check; same final input reuses detached work, changed final input replaces it before resumption.',
  'A missing or unsupported release capture invalidates stale work and leaves the pending execution gate set. Recovery requires another full check. Gameplay locks, settings generations and actual game-instance changes retain their guards; execution recapture and abandoned-worker publication gates are unchanged.',
  'Preserved common_events.lua update_hand_text at lines495-578 writes the current_round.current_hand display aggregate. No production Brainstorm consumer reads that aggregate. Only that copied field is removed; real chips, levels, hand/discard resources, cash, population, order, owned inventory, Gold metadata and all other round fields remain fingerprinted.',
  'Auto revision2 distinguishes snapshot_needed from action_ready. Existing ready conditions still permit a fresh no-action/unsupported endpoint fingerprint, so a pending prior action is acknowledged before the unsupported watchdog begins. Blocked/search/terminal observations omit unused public action data without caching a prior observation.',
  'Both exact auto matches recaptures are unchanged. Profile identity, generations, terminal receipt and current Gold metadata still run on active ticks. Progress fingerprint changes cannot renew a pending-action watchdog; original terminal precedence, stop/drain and one-attempt consumption remain.',
  'Journal idle update does not capture, fingerprint, encode, compress or write. It does bounded callback-identity checks and returns unless a callback scheduled a settled observation. Expensive archive work is event-driven. Two detached lower-value event-time sketches remain untested and inactive, excluded from this release review.'
 ],
 'validation':[
  {'command':'python tests/run_lua_tests.py tests/advisor_runtime.lua','exit_code':0,'checks':573,'coverage':'Actual integrated runtime,120 drag frames in each hand/shop/blind phase, unchanged/changed release, worker pause/resume, HUD churn, true resource invalidation, missing/unsupported release, settings and gameplay locks.'},
  {'command':'python tests/run_lua_tests.py tools/advisor_eval/development323/snapshot_idle/run_candidate.lua tools/advisor_eval/development323/snapshot_idle/run_existing.lua','exit_code':0,'checks':588,'breakdown':{'new_snapshot':52,'existing_snapshot':110,'gold':316,'perkeo_inventory':110}},
  {'command':'python tests/run_lua_tests.py tools/advisor_eval/development323/auto_observation/detached_test.lua tools/advisor_eval/development323/auto_observation/existing_fixtures.lua','exit_code':0,'checks':831,'breakdown':{'new_observation':317,'existing_product':202,'controller':312}}
 ],
 'total_independent_checks':1992,
 'limits':[
  'Tests count manufactured avoided work; no live CPU percentage, idle frequency, elapsed-time benefit or full-run improvement was measured.',
  'Removing display data intentionally changes deterministic snapshot/sample keys. Earlier frozen policies and traces are preserved; this review does not claim action equivalence across that key change.',
  'Ready active auto frames still capture public state; active ticks still rebuild Gold metadata. The new code does not eliminate all computation.',
  'The superseded auto revision1 acknowledgment regression and earlier passing evidence remain preserved by its author. Only revision2 was independently accepted here.',
  'This review does not grant any experiment allowance. Full coordinated candidate and exact-installed regression/hash verification remain the parent responsibility.'
 ]
}
path=HERE/'review_cpu323.json'
with path.open('x',encoding='utf-8',newline='\n') as f:json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path),'checks':1992}))
