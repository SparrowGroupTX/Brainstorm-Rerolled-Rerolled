"""Verify exact417 candidate and histories; publish candidate-only navigation."""
from pathlib import Path
from datetime import datetime,timezone
import difflib,json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def now():return datetime.now(timezone.utc).isoformat()
def write(path,value):
 with path.open('x',encoding='utf-8') as f:f.write(value)
def save(path,value):write(path,json.dumps(value,indent=2,allow_nan=False)+'\n')
candidate=EVAL/'runs/repair417_candidate1'
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
counts={'lua_fixtures':int(m[1]),'python_tests':py};assert counts=={'lua_fixtures':284,'python_tests':458}
assert '0/2 fixtures passed' in (HERE/'baseline_discrimination.log').read_text()
captures={}
for name in ('001','002'):
 folder=HERE/'captures'/name
 summary=json.loads((folder/'summary.json').read_text());manifest=json.loads((folder/'manifest.json').read_text())
 assert not summary['errors']
 for item in manifest['segments']:
  p=folder/'logs'/item['name'];assert file_digest(p)==item['sha256'] and p.stat().st_size==item['bytes']
 assert file_digest(folder/'events.sqlite3')==summary['database_sha256']
 trace=json.loads((folder/'discard_trace.json').read_text());assert trace['database_sha256']==summary['database_sha256']
 clear=[v for v in trace['flags'] if v['physically_clear']]
 assert len(clear)==trace['physically_clear_count']
 for v in clear:
  assert v['action']==v['advice_action'] and v['callback']['callback_returned']
 captures[name]={'events':summary['events'],'segments':len(manifest['segments']),
  'bytes':sum(x['bytes'] for x in manifest['segments']),'starts':len(summary['starts']),
  'outcomes':summary['outcomes'],'unended':summary['unended_run_ids'],
  'summary_sha256':file_digest(folder/'summary.json'),'manifest_sha256':file_digest(folder/'manifest.json'),
  'trace_sha256':file_digest(folder/'discard_trace.json'),'clear_with_unused_discards':len(clear),
  'clear_with_three_or_more_discards':sum(v['discards']>=3 for v in clear)}
assert captures['001']['clear_with_unused_discards']==5
assert captures['002']['clear_with_unused_discards']==17 and captures['002']['clear_with_three_or_more_discards']==8
r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(r.stdout) if r.stdout.strip() else []
runtime_digest=freeze['candidate_policy_digest']
record={'created_utc':now(),'version':'2.201.0-alpha','revision':417,'status':'frozen_validated_not_installed',
 'candidate':'tools/advisor_eval/runs/repair417_candidate1','policy_digest':runtime_digest,'policy_files':freeze['candidate_policy_files'],
 'changed_runtime_files':freeze['changed_runtime_files'],'runtime_file_count':len(freeze['candidate_policy_files']),
 'test_files':freeze['test_files'],'test_file_count':len(freeze['test_files']),'validation_counts':counts,
 'installed_checkpoint':416,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'normal_exit_confirmed_for_current_session':False,'passive_processes':processes,'installed_runtime_unchanged':True,
 'public_session':summary['session'],'public_captures':captures,'latest_loaded_label':'2.200.0-alpha',
 'monitor_status':'prior_heartbeat_PAUSED_not_restarted','all_unused_discard_cases_fixed':False,
 'remaining_public_clear_families':['Flower Pot with card-trigger additions','Hanging Chad scoring-trigger order','concealed public held-floor admission','Cerulean Bell forced selection'],
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,'original_game_execution':False,
 'native_or_config_changes':False,'loaded_candidate_win_rate_evidence':False}
save(EVAL/'CANDIDATE_CHECKPOINT_417.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_417.md',f'''# Frozen candidate417 —2.201.0-alpha, not installed

Exact candidate `runs/repair417_candidate1`, digest `{runtime_digest}`.
Full gate:284 Lua fixtures/458 Python tests;109 runtime dependencies,331 test files,
three changed runtime paths (growth.lua and two version stamps). Runtime, tests
and validation provenance match. Installed/runtime remains exact4162.200.

Read `development417/REPORT.md`, `REVIEW.md`, `FINAL_VERIFICATION.json`,
`NEXT_PRIORITIES_417.md`, `ARCHITECTURE_MAP_417.md` and root resume requirements.
This is a partial supported repair: Cloud9/Popcorn additive proof admission and
safe already-scored alternate selection. Bell and further mechanism gaps remain.

Latest preserved public prefix:10177 events,11 segments/24,976,640 bytes,
four starts/two wins/one loss/one unended run, loaded2.200. Seventeen actual clears
left discards; eight left three or four. Do not claim this candidate fixes them
all, a causal win improvement,50% win rate or below1% unused-discard frequency.

No installation during play. Current session normal-exit confirmation is pending;
earlier confirmation applied to the previous session only. Release requires fresh
passive absence/preservation, exact preflight, backed explicit deployment, separate
installed freeze/full gate. Settings/seven DLLs and every prior history remain.
417's bounded review cycle is exhausted with no blocker within its selected scope.
No new game control, saved-game replay, original-source execution or experiment.
''')
write(EVAL/'NEXT_PRIORITIES_417.md','''# Priorities after candidate417

1. The insufficient-discard problem is only partially repaired. Read the17 linked
   physical clear cases in development417/captures/002/discard_trace.json and the
   REPORT.md grouping. Source-stage coverage is the main remaining issue: Flower
   Pot/card-trigger additions, Hanging Chad, concealed held floors and forced Bell.
   A later coherent repair needs its own explicit scope, independent manufactured
   invariants/negatives, bounded review and a new combined freeze. Do not append
   unreviewed runtime changes to417 or equate a mechanical flag with avoidability.
2. Qualify additive effect families using actual source-stage behavior, not Joker
   names alone. Flower Pot's Wild/debuff/suit allocation can be order sensitive;
   independently test those cases. Hanging Chad needs a lower bound across all
   possible first-scoring-card identities plus held/main-stage behavior. A bounded
   representative family is a hypothesis, not already proven by417.
3. Bell forces the selected card into a legal discard. Any workaround must include
   that loss and a supported retained alternate/future-hand plan. Do not retain the
   forced singleton illegally or assert an unseen draw is guaranteed.
4. Candidate417 can only be released after this session's normal-exit confirmation
   and passive absence, fresh logs, exact backed deployment and installed full gate.
   Current running2.200 installation, settings and DLLs must stay unchanged.

The selected417 repair/review is complete. No additional automatic slice, heartbeat,
experiment, seed search, full simulated attempt or saved-game replay is implied.
No50% win rate or below1% unused-discard target has been established.
''')
write(EVAL/'ARCHITECTURE_MAP_417.md','''# Architecture delta417

- growth.lua: exact per-key Cloud9/Popcorn ordinary ability checks extend the
  existing additive-order proof. select_clear qualifies the incumbent's hazard
  before returning; already-scored alternatives retain existing cost checks.
- No decision/search/scoring/draws/execution change. Bell and work caps unchanged.
- tests/advisor_retained_scope417.lua: invented Psychic/Flint/order-family,
  modified-mechanic, alternate-anchor and Bell legality regression coverage.
- tests/advisor_runtime.lua appended417: actual capture proof admission and full
  production advice/Execute across three physical mocked discard/draw settlements.
- development417/trace_discards.py: passive public observation/advice/request/
  callback/settlement join with original hashes. This tool never evaluates policy.
- development417: two immutable public captures, prework/backups, bounded review,
  failures, baseline discrimination, exact candidate and final preservation checks.

Installed checkpoint416 remains authoritative for deployed bytes. Candidate417
adds only growth.lua plus two version stamps. Reports explicitly retain unresolved
Flower Pot, card-trigger, concealed-floor, Hanging Chad and Bell evidence.
''')
prefix=f'''FROZEN PARTIAL REPAIR417 — 2026-09-26
2.201.0-alpha is frozen/full-validated, NOT installed. Read tools/advisor_eval/
CANDIDATE_CHECKPOINT_417.md/.json, NEXT_PRIORITIES_417.md, ARCHITECTURE_MAP_417.md
and development417/REPORT.md, REVIEW.md and FINAL_VERIFICATION.json.
Exact digest {runtime_digest};109 dependencies,
three changed runtime paths,331 test files;284 Lua/458 Python tests pass.
Fixes canonical Cloud9/Popcorn retained-clear admission and hazardous-incumbent
fallback to a safe already-scored alternative. Bell and broader coverage remain.
Installed stays exact4162.200; settings/seven DLLs and all prior work are preserved.
Current public session session-20260927T010446Z-1 has10177 archived verified events:
four starts/two wins/one loss/one unended run. Seventeen actual clears left discards,
eight left three or four. Further Flower Pot/card-trigger, Hanging Chad, concealed
floor and forced-Bell cases remain. No claim all cases are fixed or below1% achieved.
Prior heartbeat remains PAUSED; two manual passive captures did not restart it.
Current-session normal-exit confirmation is pending. No installation during play;
release needs fresh absence/log preservation, backed exact deployment and installed
full gate. Earlier normal-exit confirmation applied only to the previous session.
One substantive review/one focused recheck complete;417 review allocation exhausted.
No game control, saves/profiles, captured replay, original execution or experiment.
No loaded2.201 gain or50% win-rate claim. This selected delivery is complete; further
runtime changes require a new combined freeze. Earlier boundaries/history follow.

'''
nav=pre['navigation']+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;before=path.read_bytes();backup=HERE/'navigation_before'/rel
 backup.parent.mkdir(parents=True,exist_ok=True)
 with backup.open('xb') as f:f.write(before)
 path.write_bytes(prefix.encode()+before);assert path.read_bytes().endswith(before)
paths=set(freeze['changed_runtime_files'])|{'tests/advisor_runtime.lua','tests/advisor_retained_scope417.lua'}
changes=[]
for rel in sorted(paths):
 old=HERE/'before'/rel
 changes.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before416/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(changes))
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
write(HERE/'git_status_after.txt',status)
final={**record,'verified_utc':now(),'counts':counts,'candidate_gate_passed':True,'installed_gate_pending':True,
 'config_preserved':True,'native_files_preserved':len(pre['native_files']),
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'navigation_history_preserved':nav,'review_cycle_complete':True,'remaining_review_blockers':False,
 'validation_report_sha256':file_digest(candidate/'validation/report.json'),
 'freeze_sha256':file_digest(candidate/'freeze.json'),'review_sha256':file_digest(HERE/'REVIEW.md'),
 'report_sha256':file_digest(HERE/'REPORT.md'),'final_diff_sha256':file_digest(HERE/'final_changes.diff')}
save(HERE/'FINAL_VERIFICATION.json',final)
print(json.dumps({'digest':runtime_digest,'counts':counts,'installed':False,'prior_files_preserved':len(pre['prior_files']),
 'public_events':summary['events'],'unused_discard_clears':17,'all_cases_fixed':False,'processes':processes}))
