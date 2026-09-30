"""Exact combined418 verification and candidate-only navigation; no deployment."""
from pathlib import Path
from datetime import datetime,timezone
import difflib,json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def now():return datetime.now(timezone.utc).isoformat()
def write(p,s):
 with p.open('x',encoding='utf-8') as f:f.write(s)
def save(p,v):write(p,json.dumps(v,indent=2,allow_nan=False)+'\n')
candidate=EVAL/'runs/repair418_candidate2'
freeze=json.loads((candidate/'freeze.json').read_text());gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text());base=json.loads((EVAL/'SESSION_RESET_416.json').read_text());installed=Path(base['installed'])
assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']
assert policy_hashes(installed.parent)==base['policy_files']==pre['installed_runtime_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
assert {p.name:file_digest(p) for p in installed.glob('*.dll')}==pre['native_files']
assert file_digest(HERE/'SCOPE.md')==freeze['scope_sha256']
for rel,sha in pre['prior_files'].items():assert file_digest(ROOT/rel)==sha,rel
allowed=set(freeze['changed_runtime_files'])|{'tests/advisor_runtime.lua'}
for rel,sha in pre['before_files'].items():
 assert file_digest(HERE/'before'/rel)==sha,rel
 if rel not in allowed:assert file_digest(ROOT/rel)==sha,rel
m=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text());assert m and m[1]==m[2]
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
counts={'lua_fixtures':int(m[1]),'python_tests':py};assert counts=={'lua_fixtures':285,'python_tests':458}
assert '1/1 fixtures passed' in (HERE/'baseline_regressions2.log').read_text()
folder=HERE/'captures/001';summary=json.loads((folder/'summary.json').read_text());manifest=json.loads((folder/'manifest.json').read_text())
assert not summary['errors'] and summary['events']==19921
for item in manifest['segments']:
 p=folder/'logs'/item['name'];assert file_digest(p)==item['sha256'] and p.stat().st_size==item['bytes']
assert file_digest(folder/'events.sqlite3')==summary['database_sha256']
trace=json.loads((folder/'discard_trace.json').read_text());assert trace['database_sha256']==summary['database_sha256']
clears=[v for v in trace['flags'] if v['physically_clear']]
assert len(clears)==trace['physically_clear_count']==39
assert sum(v['discards']>=3 for v in clears)==14
for v in clears:assert v['action']==v['advice_action'] and v['callback']['callback_returned']
r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(r.stdout) if r.stdout.strip() else []
digest=freeze['candidate_policy_digest']
record={'created_utc':now(),'revision':418,'version':'2.202.0-alpha','status':'frozen_validated_not_installed',
 'candidate':'tools/advisor_eval/runs/repair418_candidate2','supersedes_uninstalled_candidate':417,
 'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],'runtime_file_count':len(freeze['candidate_policy_files']),
 'changed_runtime_files':freeze['changed_runtime_files'],'test_files':freeze['test_files'],
 'test_file_count':len(freeze['test_files']),'validation_counts':counts,
 'installed_checkpoint':416,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installed_runtime_unchanged':True,'normal_exit_confirmed_for_current_session':False,'passive_processes':processes,
 'public_session':summary['session'],'public_capture':'tools/advisor_eval/development418/captures/001',
 'public_events':summary['events'],'public_starts':len(summary['starts']),'public_outcomes':summary['outcomes'],
 'public_unended':summary['unended_run_ids'],'public_segments':len(manifest['segments']),
 'public_bytes':sum(x['bytes'] for x in manifest['segments']),'latest_loaded_label':'2.200.0-alpha',
 'actual_clears_with_unused_discards':39,'actual_clears_with_three_plus_discards':14,
 'all_unused_discard_cases_fixed':False,'final_ten_run_audit_complete':False,
 'monitor_status':'prior_heartbeat_PAUSED_not_restarted','game_control':False,'save_profile_access':False,
 'captured_policy_replay':False,'original_game_execution':False,'native_or_config_changes':False,
 'loaded_candidate_win_rate_evidence':False,'review_cycle_exhausted':True,
 'post_review_change':'Narrow Red Seal admission to win-first teacher; restore existing nonteacher regression contract.'}
save(EVAL/'CANDIDATE_CHECKPOINT_418.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_418.md',f'''# Combined candidate418 —2.202.0-alpha, not installed

Candidate2 digest `{digest}`. Full gate passes285 Lua fixtures/458 Python tests;
109 runtime dependencies,333 declared tests, four changed runtime paths. Exact
runtime/test/helper hashes match. Supersedes uninstalled417; installed stays4162.200.

Read development418/REPORT.md, REVIEW.md and FINAL_VERIFICATION.json,
NEXT_PRIORITIES_418.md, ARCHITECTURE_MAP_418.md and the full root resume boundaries.
Adds qualified additive effect families, complete first-scorer Chad minima and
identity-independent hidden-spare discards. Acorn product-family guard added.
Candidate1's failed nonteacher Red gate and all old histories are preserved.
Candidate2 restores the existing nonteacher boundary; no old test was weakened.

Latest preserved2.200 prefix:19921 events,25 segments/48,654,105 bytes,
ten starts/three wins/six losses/one unended at cutoff.39 actual clearing plays
left discards;14 left three or more. More row qualifications and Bell/Acorn remain;
no all-fixed,50% win rate, below1% unused-discard or loaded-candidate benefit claim.

No installation while playing. This session's normal-exit confirmation is pending.
Release requires fresh passive absence/log preservation, exact preflight, backed
explicit install_slice deployment, installed freeze and full gate. Settings/seven
DLLs unchanged. Review cycle exhausted. No new experiment, game control or replay.
''')
write(EVAL/'NEXT_PRIORITIES_418.md','''# Next priorities after candidate418

1. Read the latest39 public clear flags in development418/captures/001/discard_trace.json.
   Current repair covers the separately tested417 mechanism families, not every
   latest row. New evidence includes Abstract, Campfire, Fibonacci, Loyalty/Baseball,
   Juggler/Green. Trace actual source fields and final rejection before claiming
   avoidability. Prefer a shared canonical effect-contract table over scattered
   name lists; distinguish discard callbacks, per-card/main/held stages and order.
2. Cerulean Bell requires discarding the forced card. A valid plan must include
   its loss and every relevant future forced-card possibility; do not keep the
   forced singleton illegally. Combined Acorn × Chad proof remains unqualified
   until every public Joker/first-scorer world fits the existing12-call budget.
3. Historical417 wording about Wild/Smeared was too strong: vanilla Flower Pot
   order sensitivity was not demonstrated. Their exclusion means unqualified
   coverage, not a proven unsafe permutation. Preserve that distinction.
4. Candidate2.202 includes417 and418 but is not deployed. Wait for current-session
   normal-exit confirmation and passive absence, preserve newer logs, back up and
   install exact files, then freeze/full-validate exact installed bytes. Neither
   candidate is loaded evidence; old2.200 logs cannot demonstrate their success.

Selected418 delivery/review complete. Further runtime changes need a new coherent
scope and combined freeze. No implied heartbeat, game control, experiment, saved-
game replay, complete simulated attempt or win-rate target claim. All original
preservation/execution/release boundaries remain.
''')
write(EVAL/'ARCHITECTURE_MAP_418.md','''# Architecture delta418

- growth.lua: canonical per-Joker ability and neutral Negative qualification;
  Flower Pot/card-stage additive additions, fixed main-stage support, Gold and
  teacher-only Red cards. Existing pair proof keeps its seal boundary.
- growth.lua accept(): qualified complete selected-card rotations certify every
  possible first scorer for Chad; minimum and every score share existing12 cap.
- growth.lua visible_retained(): same public row qualification; hidden spares
  become discardable only with canonical identity-independent callbacks and no
  possible hidden discard/held-resource rewards. Hidden cards never become anchors.
- acorn_discard.lua: explicitly rejects first-scorer certificates that later
  public Joker worlds cannot prove with their existing single-order check.
- tests/fixtures/retained418.lua, advisor_retained_families418.lua and runtime
  append: exhaustive order oracle, call accounting, hidden independence, negatives,
  physical adapter/draw/fresh-observation progression. Prior fixtures untouched.
- development418: before/prework preservation, original-source TEXT excerpts,
  immutable passive prefix, descriptive trace, review, failed/successful candidates.

Installed checkpoint416 remains deployed truth. Candidate418 supersedes candidate417
with combined uninstalled bytes. Source text is never executed; no policy/scorer
reads public captures. Bell, search/scorer/executor implementation and budgets unchanged.
''')
prefix=f'''FROZEN COMBINED CANDIDATE418 — 2026-09-26
2.202.0-alpha is frozen/full-validated, NOT installed; supersedes uninstalled417.
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_418.md/.json, NEXT_PRIORITIES_418.md,
ARCHITECTURE_MAP_418.md, development418/REPORT.md, REVIEW.md, FINAL_VERIFICATION.json.
Digest {digest};109 dependencies,333 test files,
four changed runtime paths;285 Lua/458 Python tests pass. Candidate1 failed the
nonteacher Red contract; candidate2 narrows that new admission and preserves tests.
Adds canonical additive rows, complete Chad first-scorer floor, safe public hidden-
spare discards and Acorn product-family refusal. No Bell or search-budget change.
Installed remains exact4162.200; config/seven DLLs and all prior history preserved.
Latest public prefix:19921 events,25 segments/48,654,105 bytes, ten starts/three wins/
six losses/one unended at cutoff.39 actual clears left discards;14 left three-plus.
More row coverage, Bell and Acorn remain; no claim every case is fixed,50% win rate,
below1% unused-discard rate or loaded2.202 benefit. Wild/Smeared remains unqualified;
historical417 wording did not demonstrate vanilla Flower Pot order sensitivity.
Current-session normal-exit confirmation still pending. No install during play;
release requires fresh absence/log preservation, backed deployment and installed gate.
One substantive review/one focused recheck exhausted. Post-review Red correction
narrows admission only. Selected delivery complete; later edits need a new freeze.
No game control, saves/profiles, captured replay, original execution or experiment.
Heartbeat remains PAUSED; passive manual capture only. Earlier history follows.

'''
nav=pre['navigation']+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;old=path.read_bytes();backup=HERE/'navigation_before'/rel;backup.parent.mkdir(parents=True,exist_ok=True)
 with backup.open('xb') as f:f.write(old)
 path.write_bytes(prefix.encode()+old);assert path.read_bytes().endswith(old)
paths=set(freeze['changed_runtime_files'])|{'tests/advisor_runtime.lua','tests/advisor_retained_families418.lua','tests/fixtures/retained418.lua'}
diff=[]
for rel in sorted(paths):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before417/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
write(HERE/'git_status_after.txt',status)
final={**record,'verified_utc':now(),'candidate_gate_passed':True,'installed_gate_pending':True,'counts':counts,
 'config_preserved':True,'native_files_preserved':len(pre['native_files']),
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'navigation_history_preserved':nav,'remaining_review_blockers':False,
 'validation_report_sha256':file_digest(candidate/'validation/report.json'),'freeze_sha256':file_digest(candidate/'freeze.json'),
 'review_sha256':file_digest(HERE/'REVIEW.md'),'report_sha256':file_digest(HERE/'REPORT.md'),
 'final_diff_sha256':file_digest(HERE/'final_changes.diff'),'trace_sha256':file_digest(folder/'discard_trace.json'),
 'manifest_sha256':file_digest(folder/'manifest.json'),'source_text_excerpt_sha256':file_digest(HERE/'source_effects.txt')}
save(HERE/'FINAL_VERIFICATION.json',final)
print(json.dumps({'digest':digest,'counts':counts,'installed':False,'prior_files_preserved':len(pre['prior_files']),
 'public_events':summary['events'],'actual_unused_discard_clears':39,'processes':processes}))
