"""Verify the exact combined candidate, preserve histories, and publish navigation."""
from pathlib import Path
from datetime import datetime,timezone
import difflib,json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes,digest
from validate_checkpoint import test_manifest,provenance
def now():return datetime.now(timezone.utc).isoformat()
def write(path,value):
 with path.open('x',encoding='utf-8') as f:f.write(value)
def save(path,value):write(path,json.dumps(value,indent=2,allow_nan=False)+'\n')
candidate=EVAL/'runs/repair416_candidate2'
freeze=json.loads((candidate/'freeze.json').read_text());gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text());base=json.loads((EVAL/'SESSION_RESET_414.json').read_text());installed=Path(base['installed'])
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
counts={'lua_fixtures':int(m[1]),'python_tests':py};assert counts=={'lua_fixtures':283,'python_tests':458}
summary=json.loads((HERE/'captures/001/summary.json').read_text());manifest=json.loads((HERE/'captures/001/manifest.json').read_text())
assert not summary['errors'] and summary['events']==19086 and not summary['unended_run_ids']
for item in manifest['segments']:
 p=HERE/'captures/001/logs'/item['name'];assert file_digest(p)==item['sha256'] and p.stat().st_size==item['bytes']
assert file_digest(HERE/'captures/001/events.sqlite3')==summary['database_sha256']
r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(r.stdout) if r.stdout.strip() else []
runtime_digest=freeze['candidate_policy_digest']
record={'created_utc':now(),'version':'2.200.0-alpha','revision':416,'status':'frozen_validated_not_installed',
 'candidate':'tools/advisor_eval/runs/repair416_candidate2','policy_digest':runtime_digest,'policy_files':freeze['candidate_policy_files'],
 'changed_runtime_files':freeze['changed_runtime_files'],'runtime_file_count':len(freeze['candidate_policy_files']),
 'test_files':freeze['test_files'],'test_file_count':len(freeze['test_files']),'validation_counts':counts,
 'installed_checkpoint':414,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'normal_exit_confirmed_for_current_session':False,'passive_processes':processes,'installed_runtime_unchanged':True,
 'public_session':summary['session'],'public_capture':'tools/advisor_eval/development416/captures/001',
 'public_events':summary['events'],'public_starts':len(summary['starts']),'public_outcomes':summary['outcomes'],
 'public_unended':summary['unended_run_ids'],'public_segments':len(manifest['segments']),
 'public_bytes':sum(x['bytes'] for x in manifest['segments']),'latest_loaded_label':'2.199.0-alpha',
 'monitor_status':'PAUSED_session_completed','deep_final_ten_run_audit_complete':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,'original_game_execution':False,
 'native_or_config_changes':False,'loaded_candidate_win_rate_evidence':False}
save(EVAL/'CANDIDATE_CHECKPOINT_416.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_416.md',f'''# Frozen416 candidate —2.200.0-alpha, not installed

Exact candidate `runs/repair416_candidate2`, digest `{runtime_digest}`.
Full gate passes283 Lua fixtures and458 Python tests.109 runtime dependencies,
10 changed runtime paths,330 frozen test files; runtime/test/helper hashes match.
Installed remains exact4142.199; settings and7 DLLs are unchanged.

Read `development416/REPORT.md`, `REVIEW.md`, `FINAL_VERIFICATION.json`,
`NEXT_PRIORITIES_416.md`, `ARCHITECTURE_MAP_416.md`, and root `ADVISOR_RESUME_PROMPT.md`.
Candidate1's failed gate and all earlier tracked/untracked history are preserved.
The one substantive review and one focused recheck are exhausted, with no remaining
review blocker. No new automatic repair slice or experiment is authorized here.

Current public session is safely copied:26 segments/46,795,804 bytes/19,086 verified
events, ten starts,2 wins/8 losses, no unended run. Loaded public label2.199.
Heartbeat is paused. No causal gain,50% population win rate or below1% unused-discard
rate is established. Final ten-run deep audit is not claimed by this repair.

Release remains pending current normal-exit confirmation, fresh passive absence,
exact preflight/log preservation, explicit backed install_slice deployment and
separate exact-installed freeze/full validation. Installation is not activation.
No game control, saved-game/profile access, captured policy/scorer replay or
original-game execution occurred. Existing preservation/execution limits remain.
''')
write(HERE/'REPORT.md',f'''# Repair416 result —2.200.0-alpha candidate

The five supported diagnosis415 families are repaired in one combined candidate,
frozen at `runs/repair416_candidate2`, digest `{runtime_digest}`. It is **not installed**.
Installed runtime remains exact revision4142.199. This is local correctness and
regression evidence; no loaded-game improvement is claimed.

## Changes and reasons

1. **Discard before clearing.** Teacher retained-clear proofs now qualify ordinary
   Smiley/Duo/Wily/Swashbuckler additive arithmetic and supported visible anchors
   under Mark/Wheel/Fish. A concealed-card branch uses public unordered composition,
   visible selected cards and protected synthetic hidden slots; it never substitutes
   unanimous samples for a guarantee. Held arithmetic is qualified, including
   canonical Baron/Moon factors; unsupported Blackboard/Raised Fist, forced hidden
   cards, unknown held arithmetic and all-hidden spare cards abstain. Acorn checks
   the same physical discard and anchor in every retained public Joker order,
   verifies exact growth against public advancement, and rejects even one bad order.
   New proof calls share the12-call allowance and branch budgets. Fresh settled
   observation is required after every draw. Runtime titles/status distinguish
   retained clearing floors from sampled redraw estimates.

2. **Earlier Acorn discards.** The existing complete common-draw/all-Joker-world
   comparison runs with multiple hands remaining. It only prefers an early discard
   when sampled immediate progress does not decline in any public order and mean
   progress increases by more than0.04. This is explicitly a bounded first-action
   estimate, not a projected complete-blind win or guaranteed retained clear.

3. **Mouth continuation and first lock.** Qualified blocked hands are legal zero-score
   transitions: spend a hand, update actual category/history fields, preserve the
   lock and cards, and skip before/scoring growth and Glass destruction. Matador,
   post-hand decay/custom callbacks remain unsupported. No-scoring rollout branches
   can cycle legal cards. With zero discards, an unlocked Mouth compares up to four
   distinct first categories over the same bounded private samples and up to four
   hands. A manufactured stronger immediate Two Pair loses while repeatable Pair
   clears; the new comparison selects Pair. Incomplete families do not change advice.

4. **Perkeo terminal generator rescue.** Win-first teacher can consume held generator
   stock on the last hand with no discards after a complete supported upper-bound
   certificate proves all current ordered plays lose. Existing survival exceptions,
   capacity, visibility and total25000 budget remain. Judgement reveals a real Joker
   and requires fresh advice; no generated identity, success chance or rescue score
   is invented. Nonteacher Perkeo inventory protection remains unchanged.

5. **Shop budget fallback.** Reserve up to12000 of the existing50000 shop scores for
   a complete incumbent/paid-miss comparison before optional families exhaust work.
   If all four declared finishing samples fail and the paid miss preserves their
   supported scoring, whole-decision fallback can release interest savings for a
   source-supported upgrade opportunity. It still retains actual survival costs
   plus$12 purchase capacity, charges the fee on a miss, protects core sale victims,
   and requires a funded catalog witness. Missing evidence, worse cash-scaling score,
   unsupported forecasts and insufficient cash refuse this exception. Revealed shops
   receive fresh purchase advice. Four samples are not a win probability.

## Verification

Candidate2 passes **283 Lua fixtures/458 Python tests** with109 runtime dependencies,
10 changed paths and330 test files frozen and unchanged during validation. Five new
independently manufactured fixtures cover positive paths, changed hidden assignments,
late adverse Acorn orders, capacity/uncertainty/budget negatives and fresh transitions.
The integrated runtime fixture exercises actual capture, decision, rendering and
execution adapter across three physical mocked discard/draw settlements; its total
is897 checks. Three discriminating new fixtures fail against exact414 and pass here.
No captured run was sent through policy/scorer or used to construct a fixture.

The sole reviewer completed one substantive review and one focused recheck. A
shrinking-Baron proof defect was fixed and rechecked; no remaining blocker reported.
Candidate1's three nonteacher metadata parity failures and all iterative failures
are preserved. No existing fixture was weakened. Budgets remain ordinary140000,
shop50000, consumable25000, fast-clear70, retained proof12 and concealed8000.

## Preserved session and limits

`captures/001` safely contains26 public segments,46,795,804 bytes and19,086 verified
events from session `session-20260926T235238Z-1`: ten starts,2 wins/8 losses, no
unended run, public loaded label2.199. No chain errors. Monitoring is paused because
the session completed and its process exited. Absence does not establish normal exit.
The earlier diagnosis415 anchors explain supported causes; this repair does not
claim a full new audit of the final runs or that alternate actions would have won.

The user's below1% unused-discard preference is not empirically demonstrated.
Unproved hidden/held mechanics, oversized Acorn world families, incomplete budgets,
retry constraints and real resource risks can still cause explicit exceptions.
The candidate adds qualified coverage; it does not force a discard without a proof.
Early Acorn and Mouth forecasts remain bounded heuristics. No global optimality,
50% win rate or causal loaded2.200 benefit is established.

Release requires current normal-exit confirmation, passive absence and exact backed
deployment followed by separate installed freeze/full gate. Existing DLLs, settings,
all tracked/untracked work and prior checkpoints remain preserved. No game control,
save/profile access, original-game execution, captured replay or new experiment.
''')
write(EVAL/'NEXT_PRIORITIES_416.md','''# Next priorities after candidate416

1. Release this exact candidate only after current normal-exit confirmation and
   passive absence: preserve newer public journals, verify installed414 and all
   config/DLL hashes, use explicit backed install_slice deployment, then freeze and
   run every full gate against exact installed bytes. Do not mix runtime edits into
   this validated candidate. Installation is not activation.
2. The final public ten-run archive is safe in development416/captures/001. It has
   two wins/eight losses on loaded-label2.199. A later authorized deep audit may
   adjudicate final runs and unresolved qualitative pack/Joker choices; do not claim
   repair416 proves their outcomes or re-evaluate captured states with a scorer.
3. Future user-started loaded2.200 evidence should check actual unused-discard
   settlements and exception rates, fresh retained anchors, early Acorn actions,
   Mouth first locks, generator reveals and charged reroll misses. No autonomous
   game starts, scheduled monitor restart, experiments or win-rate promises.

This coherent candidate and its bounded review are complete. Stop after delivery
unless current release authorization/confirmation arrives. Historical priorities
and all mandatory resume boundaries remain intact.
''')
write(EVAL/'ARCHITECTURE_MAP_416.md','''# Architecture delta416

- decision.lua: teacher concealed visible-floor preflight; public Acorn retained
  proof and early redraw integration; shared work accounting; independently completed
  shop shortfall evidence; final discard receipt and explicit strategy presentation.
- growth.lua: exact additive row qualification, supported boss/held-effect guards,
  protected indices, public-composition visible retained-floor certificate.
- acorn_discard.lua: same physical retained action across every public order; early
  sampled progress comparison remains distinct from the last-hand clear objective.
- scoring.lua: qualified legal zero-score Mouth after_play transition; detached
  counters/population remain actual and unsupported callbacks abstain.
- search.lua: legal Mouth cycles in continuation and bounded complete first-category
  comparison even when discards are exhausted.
- consumables.lua: teacher terminal stock waiver behind complete losing-ceiling proof.
- strategy.lua: independent complete paid-miss evidence and conservative source
  catalog opportunity fallback retaining survival and purchase dollars.
- runtime.lua: explicit retained-floor status for the new belief-branch actions.
- tests/fixtures/repair416.lua, five advisor_*416 fixtures, advisor_runtime.lua:
  invented observations, physical transitions and real adapter integration.
- development416: prework/before preservation, review, failed/successful freezes,
  manufactured regressions, complete public archive and final verification.

Prior architecture maps are historical reference. Installed checkpoint remains414;
candidate checkpoint416 records proposed combined bytes and release prerequisites.
''')
prefix=f'''FROZEN CANDIDATE416 — 2026-09-26
2.200.0-alpha is frozen/full-validated, NOT installed. Read tools/advisor_eval/
CANDIDATE_CHECKPOINT_416.md/.json, NEXT_PRIORITIES_416.md, ARCHITECTURE_MAP_416.md
and development416/REPORT.md, REVIEW.md and FINAL_VERIFICATION.json.
Exact digest {runtime_digest};109 dependencies,
10 changed runtime paths,330 frozen test files;283 Lua/458 Python tests pass.
Fixes: qualified visible/all-public-order discard proofs, earlier Acorn redraw
comparison, Mouth zero-score/first-lock planning, terminal Perkeo generator rescue,
and complete paid-miss evidence through shop fallback. Existing work limits remain.
Installed stays exact4142.199; settings/7 DLLs and all prior work are preserved.
Current session safely copied:26 segments/46,795,804 bytes/19,086 verified events,
ten starts,2 wins/8 losses, loaded-label2.199, no unended run. Heartbeat is PAUSED.
Process absence does not establish normal exit. Current confirmation is pending;
release needs fresh exact preflight, backed explicit install and full installed gate.
No game control, save/profile access, captured-policy/scorer replay or experiment.
No loaded2.200 gain,50% population win rate or below1% unused-discard claim.
416 bounded review/candidate delivery are complete; no automatic further repair.
User repair authorization superseded415's no-runtime-edit slice only. All earlier
preservation/execution/release boundaries remain. Historical checkpoints follow.

'''
nav=pre['navigation']+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;before=path.read_bytes();backup=HERE/'navigation_before'/rel
 backup.parent.mkdir(parents=True,exist_ok=True)
 with backup.open('xb') as f:f.write(before)
 path.write_bytes(prefix.encode()+before)
 assert path.read_bytes().endswith(before)
paths=set(freeze['changed_runtime_files'])|{'tests/advisor_runtime.lua','tests/fixtures/repair416.lua'}
paths|={f'tests/advisor_{n}416.lua' for n in ('acorn_discard','mouth_planning','shop_shortfall','teacher_rescue','visible_discard')}
changes=[]
for rel in sorted(paths):
 old=HERE/'before'/rel
 changes.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before414/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(changes))
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
write(HERE/'git_status_after.txt',status)
final={**record,'verified_utc':now(),'counts':counts,'candidate_gate_passed':True,'installed_gate_pending':True,
 'config_preserved':True,'native_files_preserved':len(pre['native_files']),
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'navigation_history_preserved':nav,'review_cycle_complete':True,'remaining_review_blockers':False,
 'validation_report_sha256':file_digest(candidate/'validation/report.json'),
 'freeze_sha256':file_digest(candidate/'freeze.json'),'review_sha256':file_digest(HERE/'REVIEW.md'),
 'final_diff_sha256':file_digest(HERE/'final_changes.diff')}
save(HERE/'FINAL_VERIFICATION.json',final)
print(json.dumps({'digest':runtime_digest,'counts':counts,'installed':False,'prior_files_preserved':len(pre['prior_files']),
 'public_events':summary['events'],'outcomes':summary['outcomes'],'processes':processes}))
