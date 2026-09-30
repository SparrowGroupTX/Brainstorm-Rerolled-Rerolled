"""Verify exact419 candidate and preserved history; publish candidate navigation."""
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
candidate=EVAL/'runs/repair419_candidate3'
freeze=json.loads((candidate/'freeze.json').read_text());gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text());base=json.loads((EVAL/'SESSION_RESET_418.json').read_text());installed=Path(base['installed'])
assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']==pre['provenance']
assert policy_hashes(installed.parent)==base['policy_files']==pre['installed_runtime_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
for root in (installed,ROOT/'Brainstorm'):assert {p.name:file_digest(p) for p in root.glob('*.dll')}==pre['native_files']
assert file_digest(HERE/'SCOPE.md')==freeze['scope_sha256']
for rel,sha in pre['prior_files'].items():assert file_digest(ROOT/rel)==sha,rel
changed_tests={'tests/'+x for x in ('advisor_death_selection400.lua','advisor_engine_retention381.lua','advisor_last_engine411.lua','advisor_pack_endpoint404.lua','advisor_proactive_reroll371.lua','advisor_runtime.lua','advisor_retained_hiker419.lua','advisor_shop_alignment419.lua')}
assert {p for p,h in freeze['test_files'].items() if pre['test_files'].get(p)!=h}==changed_tests
allowed=set(freeze['changed_runtime_files'])|changed_tests
for rel,sha in pre['before_files'].items():
 assert file_digest(HERE/'before'/rel)==sha,rel
 if rel not in allowed:assert file_digest(ROOT/rel)==sha,rel
for rel,sha in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==sha
m=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text());assert m and m[1]==m[2]
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
counts={'lua_fixtures':int(m[1]),'python_tests':py};assert counts=={'lua_fixtures':287,'python_tests':458}
assert '1/1 fixtures passed' in (HERE/'baseline_regressions.log').read_text()
for name in ('001','002','003'):
 folder=HERE/'captures'/name;summary=json.loads((folder/'summary.json').read_text());manifest=json.loads((folder/'manifest.json').read_text())
 assert not summary['errors']
 for row in manifest['segments']:
  p=folder/'logs'/row['name'];assert file_digest(p)==row['sha256'] and p.stat().st_size==row['bytes']
 assert file_digest(folder/'events.sqlite3')==summary['database_sha256']
trace=json.loads((folder/'discard_trace.json').read_text());assert trace['database_sha256']==summary['database_sha256']
clears=[v for v in trace['flags'] if v['physically_clear']];assert len(clears)==28
for v in clears:assert v['action']==v['advice_action'] and v['callback']['callback_returned']
assert summary['events']==18475 and len(summary['starts'])==10 and not summary['unended_run_ids']
assert summary['outcomes']=={'win':3,'loss':6,'abandoned_stall':1}
r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(r.stdout) if r.stdout.strip() else []
digest=freeze['candidate_policy_digest']
record={'created_utc':now(),'revision':419,'version':'2.203.0-alpha','status':'frozen_validated_not_installed',
 'candidate':'tools/advisor_eval/runs/repair419_candidate3','policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'runtime_file_count':109,'changed_runtime_files':freeze['changed_runtime_files'],'test_files':freeze['test_files'],
 'test_file_count':335,'changed_test_files':sorted(changed_tests),'validation_counts':counts,
 'installed_checkpoint':418,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installed_runtime_unchanged':True,'normal_exit_confirmation_required_before_release':True,'passive_processes':processes,
 'public_session':summary['session'],'public_capture':'tools/advisor_eval/development419/captures/003',
 'public_events':18475,'public_starts':10,'public_outcomes':summary['outcomes'],'public_unended':[],
 'public_segments':25,'public_bytes':44832110,'latest_loaded_label':'2.202.0-alpha',
 'actual_clears_with_unused_discards':28,'all_unused_discard_cases_fixed':False,'final_ten_run_deep_audit_complete':False,
 'monitor_status':'prior_heartbeat_PAUSED_not_restarted','game_control':False,'save_profile_access':False,
 'captured_policy_replay':False,'original_game_execution':False,'native_or_config_changes':False,
 'loaded_candidate_win_rate_evidence':False,'review_cycle_exhausted':True}
save(EVAL/'CANDIDATE_CHECKPOINT_419.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_419.md',f'''# Candidate419 —2.203.0-alpha

Frozen candidate3: `{digest}`.287 Lua/458 Python pass;109 runtime dependencies,
335 tests, six changed runtime paths. Read development419/REPORT.md, REVIEW.md,
FINAL_VERIFICATION.json, NEXT_PRIORITIES_419.md and ARCHITECTURE_MAP_419.md.
Prior failed candidates remain. Candidate status is not deployment: installed
checkpoint418 remains2.202 until SESSION_RESET_419 confirms a completed release.

Prioritizes safe five-card discard volume, smaller scored anchors, full-batch
variants within the existing proof cap, Hiker/Stencil qualification, aligned
Joker admission, initial Perkeo stock, safer copy exchanges and late surplus spend.
No universal discard fix, below1% exception or loaded win-rate claim.

Final loaded2.202 logs safely preserved:25 segments/44,832,110 bytes/18475 events,
ten starts/3 wins/6 losses/1 abandoned_stall, no unended identity.28 physical
clears left discards; not all are proven avoidable. Complete final deep audit is
separate. No experiment, replay, game control or heartbeat restart. Review closed.
Release requires normal-exit confirmation, passive absence, preserved latest logs,
explicit backed install_slice deployment and exact-installed full validation.
''')
write(EVAL/'NEXT_PRIORITIES_419.md','''# Next priorities419

1. Complete release of exact2.203 only under the existing normal-exit, passive
   absence, log preservation, backup and installed-validation boundaries. Consult
   SESSION_RESET_419 if it exists; candidate-only history is not installed status.
2. In a future authorized loaded-session audit, measure actual five-card batches,
   total discarded cards per round, and clearing plays with resources left. Join
   observation, candidates, admission, budget, final action and settled physical
   state. A rejected candidate or accepted callback alone is not an outcome.
3. Final419/captures/003 has28 actual clears with unused discards. Prioritize the
   remaining unsupported rows, Bell and concealment; distinguish missing coverage
   from demonstrated score/resource harm. Do not replay those captured states.
4. Shop follow-up should verify first-source retention after purchase, ordinary
   early economy, same-copy victim choice, and actual late spend receipts. Static
   preferences and manufactured correctness do not establish unseen-shop benefit.

Stop after this coherent delivery. Review allocation is exhausted. Further runtime
work needs a new evidence-backed scope and exact combined freeze/full validation.
No implicit monitor, game control, save/profile access, original source execution,
experimental budget, complete simulated attempts or claimed50% win rate.
''')
write(EVAL/'ARCHITECTURE_MAP_419.md','''# Architecture delta419

- growth.lua: select_clear inspects smaller scored anchors in teacher exhaust
  mode; canonical Hiker/Stencil qualify; held Blue/Gold remain reserved; candidate,
  shortlist and accepted action rank count before growth merit within12 calls.
- strategy.lua: shared teacher purchase admission, offered-only Trading discount,
  early cash reserve, whole-pool Perkeo activation/lifetime, initial-stock hurdle,
  same-copy Perkeo-preserving endpoint arbitration, fresh pack endpoint proof,
  and one-step late cash spending with an explicit25-plus-costs floor.
- decision.lua: late spend applies to final shop leave advice after ordinary
  strategy/retention. player_journal.lua records spend and initial-stock receipts.
- two new419 fixtures plus six documented input migrations; original snapshots
  and failed freezes preserved. Search, scorer, executor and budgets unchanged.
- development419 holds immutable public copies and descriptive joins. It never
  feeds captures into policy/scoring. Candidate3 and release are separately gated.
''')
prefix=f'''FROZEN CANDIDATE419 — 2026-09-27
2.203.0-alpha candidate3 passes287 Lua/458 Python;109 dependencies,335 tests.
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_419.md/.json, NEXT_PRIORITIES_419.md,
ARCHITECTURE_MAP_419.md and development419/REPORT.md, REVIEW.md, FINAL_VERIFICATION.json.
Digest {digest}; six runtime paths changed. Installed remains4182.202 unless a
newer SESSION_RESET_419 confirms release. Safe five-card volume is the leading
discard preference; coverage remains incomplete. No below1% or win-rate claim.
Latest2.202 session safely copied:18475 events,25 segments/44,832,110 bytes,
3 wins/6 losses/1 abandoned_stall, no unended identity;28 clears left discards.
Release requires confirmed normal current exit, passive absence, backup and exact
installed full gate. Settings/seven DLLs/history preserved; heartbeat stays PAUSED.
No game control, saves/profiles, captured replay or experiment. Review exhausted.
Earlier history follows.

'''
nav=pre['navigation']+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;old=path.read_bytes();backup=HERE/'navigation_before'/rel;backup.parent.mkdir(parents=True,exist_ok=True)
 with backup.open('xb') as f:f.write(old)
 path.write_bytes(prefix.encode()+old);assert path.read_bytes().endswith(old)
diff=[]
for rel in sorted(allowed):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before419/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
final={**record,'verified_utc':now(),'candidate_gate_passed':True,'installed_gate_pending':True,
 'counts':counts,'config_preserved':True,'native_files_preserved':7,'prior_files_preserved':len(pre['prior_files']),
 'before_files_preserved':447,'navigation_history_preserved':nav,'remaining_review_blockers':False,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in [candidate/'freeze.json',candidate/'validation/report.json',HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'source_text.json',folder/'manifest.json',folder/'discard_trace.json']},
 'final_diff_sha256':file_digest(HERE/'final_changes.diff')}
save(HERE/'FINAL_VERIFICATION.json',final)
print(json.dumps({'digest':digest,'counts':counts,'installed':False,'prior_files_preserved':len(pre['prior_files']),'public_events':18475,'processes':processes}))
