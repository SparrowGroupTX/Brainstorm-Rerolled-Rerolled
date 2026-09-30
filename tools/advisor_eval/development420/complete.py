"""Verify the exact combined420 candidate, preserved inputs and public copies."""
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
candidate=EVAL/'runs/repair420_candidate4'
freeze=json.loads((candidate/'freeze.json').read_text());gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text());base=json.loads((EVAL/'SESSION_RESET_419.json').read_text());installed=Path(base['installed'])
assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']==pre['provenance']
assert policy_hashes(installed.parent)==base['policy_files']==pre['installed_runtime_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
for root in (installed,ROOT/'Brainstorm'):assert {p.name:file_digest(p) for p in root.glob('*.dll')}==pre['native_files']
assert file_digest(HERE/'SCOPE.md')==freeze['scope_sha256']
for rel,sha in pre['prior_files'].items():assert file_digest(ROOT/rel)==sha,rel
changed_tests={'tests/'+x for x in ('advisor_burnt_value420.lua','advisor_burnt_setup420.lua','advisor_death_discard420.lua','advisor_death_progression420.lua','advisor_win_first384.lua','advisor_shop_alignment419.lua')}
assert {p for p,h in freeze['test_files'].items() if pre['test_files'].get(p)!=h}==changed_tests
allowed=set(freeze['changed_runtime_files'])|changed_tests
for rel,sha in pre['before_files'].items():
 assert file_digest(HERE/'before'/rel)==sha,rel
 if rel not in allowed:assert file_digest(ROOT/rel)==sha,rel
for rel,sha in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==sha
m=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text());assert m and m[1]==m[2]
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
counts={'lua_fixtures':int(m[1]),'python_tests':py};assert counts=={'lua_fixtures':291,'python_tests':458}
assert '1/1 fixtures passed' in (HERE/'baseline_regressions.log').read_text()
assert '7/7 fixtures passed' in (HERE/'targeted9.log').read_text()
for name in ('001','002','003'):
 folder=HERE/'captures'/name;summary=json.loads((folder/'summary.json').read_text());manifest=json.loads((folder/'manifest.json').read_text())
 assert not summary['errors']
 for row in manifest['segments']:
  p=folder/'logs'/row['name'];assert file_digest(p)==row['sha256'] and p.stat().st_size==row['bytes']
 assert file_digest(folder/'events.sqlite3')==summary['database_sha256']
trace=json.loads((folder/'discard_trace.json').read_text());assert trace['database_sha256']==summary['database_sha256']
clears=[v for v in trace['flags'] if v['physically_clear']];assert len(clears)==59
assert summary['events']==21524 and len(summary['starts'])==10 and not summary['unended_run_ids']
assert summary['outcomes']=={'win':5,'loss':4,'unsupported':1}
r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(r.stdout) if r.stdout.strip() else []
digest=freeze['candidate_policy_digest']
record={'created_utc':now(),'revision':420,'version':'2.204.0-alpha','status':'frozen_validated_not_installed',
 'candidate':candidate.relative_to(ROOT).as_posix(),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'runtime_file_count':109,'changed_runtime_files':freeze['changed_runtime_files'],'test_files':freeze['test_files'],
 'test_file_count':339,'changed_test_files':sorted(changed_tests),'validation_counts':counts,
 'installed_checkpoint':419,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installed_runtime_unchanged':True,'installation_authority':'tools/advisor_eval/INSTALLATION_POLICY.md','normal_exit_confirmation_required':False,
 'passive_processes':processes,'normal_exit_inferred':False,
 'public_session':summary['session'],'public_capture':folder.relative_to(ROOT).as_posix(),
 'public_events':21524,'public_starts':10,'public_outcomes':summary['outcomes'],'public_unended':[],
 'public_segments':26,'public_bytes':52621858,'latest_loaded_label':'2.203.0-alpha',
 'actual_clears_with_unused_discards':59,'all_unused_discard_cases_fixed':False,'final_ten_run_deep_audit_complete':False,
 'monitor_status':'prior_heartbeat_PAUSED_not_restarted','game_control':False,'save_profile_access':False,
 'captured_policy_replay':False,'original_game_execution':False,'native_or_config_changes':False,
 'loaded_candidate_win_rate_evidence':False,'review_cycle_exhausted':True,'late_user_additions_independently_reviewed':False}
save(EVAL/'CANDIDATE_CHECKPOINT_420.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_420.md',f'''# Candidate420 —2.204.0-alpha

Frozen candidate4 `{digest}` passes291 Lua fixtures/458 Python tests.
109 runtime dependencies,339 test files,eight changed runtime paths. Read
development420/REPORT.md, REVIEW.md, FINAL_VERIFICATION.json, NEXT_PRIORITIES_420.md
and ARCHITECTURE_MAP_420.md. Candidate status is separate from deployment; consult
SESSION_RESET_420 when present. Installed419 remains2.203 until release completes.

Repairs useful Death acquisition/source progression, bounded Death-to-larger-discard
preparation, canonical Seltzer retained proof, missing Burnt growth valuation,
one safe opening play before a full Burnt discard, temporary reduced Yorick copies,
copied first Burnt discard and scoring restoration. Adds$40 Ante5–6 /$25 Ante7+
surplus targets with unavoidable reserves. Exact public evidence and manufactured
controls are documented; no captured input replay or whole-run experiment.

Latest2.203 public logs are preserved:21524 events/26 segments/52,621,858 bytes,
5 wins/4 losses/1 unsupported retirement.59 clears left discards; not all are
proved avoidable. No candidate loaded-game outcome or stable win-rate claim.
Release follows INSTALLATION_POLICY.md; fresh successful process absence permits
installation without another confirmation. Preserve logs, backup and exact-installed
full validation. Late spending/Burnt changes are outside the exhausted independent
review disposition; all changes share the full gate. Prior heartbeat stays paused.
''')
write(EVAL/'NEXT_PRIORITIES_420.md','''# Next priorities420

1. Check SESSION_RESET_420 for exact completed deployment; candidate-only status
   is not installed status. INSTALLATION_POLICY.md overrides all old normal-exit
   confirmation instructions. Never control the game or infer a normal exit.
2. Future authorized loaded analysis should join Burnt/Death/shop candidates,
   admission, budgets, phase arrangement, actual action and physical after-state.
   Track first-discard category and copied levels, total/full-batch discards,
   setup play score, and actual scoring restoration. A projected receipt alone
   is not a settled result or win probability.
3. Latest complete2.203 capture003 has59 physical clears with discards remaining.
   Raised Fist, concealed Mark, Idol/Scholar and other mixed-row order proofs
   remain major coverage gaps. The whole-cohort deep audit is still outstanding;
   do not replay captured states through policy/scoring or classify all flags as bugs.
4. The new Burnt setup is one opening single-card cycle, with a retained singleton
   clear, canonical core row and known neutral deck. Broader multi-card/multi-step
   setup requires a new supported scope. Death still needs actual legal held targets.

Stop after this coherent delivery. Review allowance is exhausted; late user-added
Burnt/spending work was manufactured-tested but not independently rereviewed.
Further runtime changes require a new scope and exact combined freeze/full gate.
No implicit monitor, experiment, original-game execution, saved-game/profile access,
complete simulated runs or all-fixed/below1%/stable50% win-rate claim.
''')
write(EVAL/'ARCHITECTURE_MAP_420.md','''# Architecture delta420

- strategy.lua: quality/recipient-aware Death inventory, complete visible Empress
  exchange, funded source exploration, explicit Burnt horizon and ante-specific
  surplus spending targets. Known sources are not predicted future draws.
- consumables.lua: exact legal Death copy can prepare a smaller scored anchor and
  bigger discard, preserving original held Gold/Blue, Glass, Arm and population.
- growth.lua: canonical Seltzer/Holo order proof; bounded one-card opening Burnt
  fishing with all identities compared descriptively and an independent retained
  finish. Discard count and full-batch deck capacity remain intact.
- phase_copy.lua: full-discard first-Burnt arrangements, actual reduced-row setup
  score, separate scoring restoration proof, and paired after-play resource check
  when restoring Yorick. Every physical phase is reobserved separately.
- decision.lua: budgeted Death preparation arbitration and first-Burnt phase
  comparison across a pending scoring reorder. player_journal.lua exposes bounded
  source, preparation and phase receipts. No scorer/executor/search-cap changes.
- candidate4 combines eight runtime paths and four new fixture files; prior
  candidates and failed logs remain. Public capture003 is data only, never replayed.
''')
prefix=f'''FROZEN CANDIDATE420 — 2026-09-27
2.204.0-alpha candidate4 passes291 Lua/458 Python;109 dependencies,339 tests.
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_420.md/.json, NEXT_PRIORITIES_420.md,
ARCHITECTURE_MAP_420.md and development420/REPORT.md, REVIEW.md, FINAL_VERIFICATION.json.
Digest {digest};eight runtime paths changed. Installed remains4192.203 unless
SESSION_RESET_420 confirms release. INSTALLATION_POLICY.md supersedes every older
normal-exit confirmation rule: fresh successful passive absence permits install.
Preserve latest logs, back up explicit install_slice files and validate exact installed
bytes. Never control the game or infer normal exit. Settings/seven DLLs preserved.
Death/source/discard, Seltzer, Burnt choice/setup/copies and$40 Ante5–6/$25 Ante7+
spending repaired in this slice; broader discard coverage remains incomplete.
Latest2.203 logs safe:21524 events,26 segments,5 wins/4 losses/1 unsupported retirement.
No loaded2.204 outcome or stable win-rate claim. Review exhausted; late Burnt/spending
additions are outside its disposition. Heartbeat stays PAUSED. Earlier history follows.

'''
nav=[p for p in pre['navigation'] if not p.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;old=path.read_bytes();backup=HERE/'navigation_before'/rel;backup.parent.mkdir(parents=True,exist_ok=True)
 with backup.open('xb') as f:f.write(old)
 path.write_bytes(prefix.encode()+old);assert path.read_bytes().endswith(old)
diff=[]
for rel in sorted(allowed):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before420/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
artifacts=[candidate/'freeze.json',candidate/'validation/report.json',HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'seltzer_source_text.json',HERE/'burnt_source_text.json',folder/'manifest.json',folder/'discard_trace.json',folder/'burnt_trace.json']
final={**record,'verified_utc':now(),'candidate_gate_passed':True,'installed_gate_pending':True,'counts':counts,
 'config_preserved':True,'native_files_preserved':7,'prior_files_preserved':len(pre['prior_files']),
 'before_files_preserved':len(pre['before_files']),'navigation_history_preserved':nav,'remaining_known_blockers':False,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in artifacts},'final_diff_sha256':file_digest(HERE/'final_changes.diff')}
save(HERE/'FINAL_VERIFICATION.json',final)
print(json.dumps({'digest':digest,'counts':counts,'installed':False,'prior_files_preserved':len(pre['prior_files']),'public_events':21524,'processes':processes}))
