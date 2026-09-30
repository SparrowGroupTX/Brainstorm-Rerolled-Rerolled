"""Verify exact installed414 and preserve historical navigation/evidence."""
from pathlib import Path
from datetime import datetime
import difflib,json,re,subprocess
from release import HERE,EVAL,ROOT,CANDIDATE,FINAL,exact,journals,save,now,processes
from benchmark import file_digest,policy_hashes
def write(path,value):
    with path.open('x',encoding='utf-8') as f:f.write(value)
base,installed,frozen,pre=exact(True)
observed=processes()
# A user may reopen after the backed installation while detached regression
# validation is finishing. Verify no process overlapped deployment; do not treat
# the independent test report timestamp as an installation/launch boundary.
installed_record=json.loads((FINAL/'record.json').read_text())
for p in observed if isinstance(observed,list) else [observed]:
    assert datetime.fromisoformat(p['StartTime']).timestamp()>datetime.fromisoformat(installed_record['created_utc']).timestamp()
manifest=journals(False);public=json.loads((HERE/'public_classification.json').read_text())
audit=json.loads((HERE/'closed_perkeo_audit.json').read_text())
counts=[]
for directory in (CANDIDATE,FINAL):
    gate=json.loads((directory/'validation/report.json').read_text())
    assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
    assert gate['policy_files']==frozen['candidate_policy_files'] and gate['test_files']==frozen['test_files']
    assert gate['validation_provenance']==frozen['validation_provenance']
    m=re.search(r'(\d+)/(\d+) fixtures passed',(directory/'validation/lua.log').read_text());assert m and m[1]==m[2]
    py=sum(int(re.search(r'Ran (\d+) tests',(directory/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
    counts.append({'lua_fixtures':int(m[1]),'python_tests':py})
assert counts==[{'lua_fixtures':278,'python_tests':458}]*2
record=json.loads((FINAL/'record.json').read_text());backup=Path(record['installation']['backup'])
assert policy_hashes(FINAL/'policy')==frozen['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
deployed={};changed=[]
for row in deployment['files']:
    rel=row['path'].replace('\\','/')
    assert file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel]
    assert file_digest(installed/rel)==row['after'].lower()==frozen['candidate_policy_files']['Brainstorm/'+rel]
    deployed[rel]=row['after'].lower()
    if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==93 and set(changed)==set(frozen['changed_runtime_files'])
allowed=set(changed)|{'tests/advisor_runtime.lua'}
for rel,sha in pre['before_files'].items():
    assert file_digest(HERE/'before'/rel)==sha
    if rel not in allowed:assert file_digest(ROOT/rel)==sha,rel
paths=sorted(set(changed)|{'tests/advisor_runtime.lua','tests/advisor_perkeo_exit414.lua'})
diff=[]
for rel in paths:
    old=HERE/'before'/rel
    diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before412/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
digest=frozen['candidate_policy_digest']
checkpoint={'version':'2.199.0-alpha','revision':414,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':frozen['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':109,'deployment_file_count':93,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':324,
 'latest_public_loaded_label':'2.198.0-alpha','latest_public_profile':'perkeo_yorick_win_v1',
 'latest_public_session':manifest['session'],'latest_public_capture_last_sequence':public['events'],
 'latest_public_capture_complete_batch':False,'latest_public_starts':4,'latest_public_recorded_outcomes':public['outcomes'],
 'latest_public_censored_runs':1,'latest_public_deep_audit_complete':False,
 'latest_public_manifest_sha256':file_digest(HERE/'capture/manifest.json'),
 'normal_exit_confirmation_sha256':file_digest(HERE/'normal_exit_confirmation.json'),
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':observed,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False}
save(EVAL/'SESSION_RESET_414.json',checkpoint)
report=f'''# Installed414 — Perkeo exit setup,2.199.0-alpha

Installed exact candidate `runs/repair414_candidate2`; installed freeze
`runs/repair414_installed`. Digest `{digest}`. Both full gates pass278 Lua
fixtures/458 Python tests, with identical runtime/tests/helper provenance.
109 dependencies,324 declared test files,5 changed runtime paths,93 verified
deployment/backup paths. Settings and all7 DLLs are unchanged. Backup: `{backup}`.
All prior412/413 work and histories remain preserved. Candidate1 was never installed.

The user's concern is supported in the closed2.198 session: ten shop exits on
run1, requests1409 through2588, left Brainstorm copying Yorick while Perkeo had
held Uranus/Venus. The subsequent public observations retain the original cards
and show only one new Negative consumable per exit. A separate actual Perkeo
reorder at1091 physically settled at1093 and was followed by exit1102. Thus the
path existed, but did not consistently select Perkeo. Other runs in this copied
session lacked a copying Joker at their shop exits. No exact user timestamp was
provided, so the audit establishes the session's behavior, not which event the
user watched. See closed_perkeo_audit.json for immutable physical/action anchors.

Source-supported explanation: teacher stock capacity treats off-plan Planets as
saturated after one copy; phase_copy required strictly positive incremental
inventory utility. A preferred High Card history and the two retained off-plan
Planets explain a zero-value tie. Old logs do not contain this internal phase
receipt, so this is source-based diagnosis with manufactured confirmation, not
captured-state policy replay. Candidate2 now prefers more free copies on an exact
nondecreasing-value tie in win-first mode. It still rejects lower utility, and
generic profiles retain strict positive-gain admission. More free options are a
policy preference; they are not a quantified survival/win improvement.

Two additional source bugs, absent from this capture, are also repaired: more
than8 distinct consumable groups made valuation approximate and blocked setup;
more than4 immediate copy events rejected the entire best arrangement. The
phase-only valuation now uses an exact marginal Polya-urn distribution for up
to8 events across the full held pool. Newly created Negative copies enter later
draws. It sums capped stock expectations plus aggregate matching-Planet
Observatory expectation without enumerating all joint inventories. Ordinary
strategic valuation keeps its existing four-event/eight-group rules. This is
exact expectation of the existing bounded utility, not exact future scoring.

The same full inventory and cash are retained. Existing row visibility, movement,
pinned/Dagger, purchase priority, collection-retention proof and retry boundaries
remain. The order shortlist is unchanged and bounded; global optimality is not
claimed. Every reorder requires fresh advice before exit. Public phase_copy_review
now records event counts, utility gain/tie, selected action or rejection reason.

Validation:66 new independently invented policy checks cover both copies,
off-plan saturated stock, nine types, five-to-eight events, independent exhaustive
small-pool comparisons, stock/Observatory cap crossings, final-shop horizon,
nonteacher and lower-value controls, empty/hidden/pinned/moving/debuffed rows,
actual Decision.run→reorder→fresh leave, retention and public serialization.
The runtime fixture reaches868 checks, including38 added capture/presentation/
actual mock execution-adapter checks for positive and tied inventory values.
No captured public state was passed to a policy, scorer or original-game engine.
Raw expected failures and both candidate freezes are preserved. One substantive
review and focused recheck were completed; the final teacher tie adjustment was
primary-verified after the allowed review cycle, as disclosed in REVIEW.md.

Preservation:9 public BRJ2 segments/15,035,884 bytes, copied only from the closed
prefix of departed process47196 after a newer process was observed; no active
prefix was read. All source/copy hashes matched and6372 events form a verified
chain. Public label2.198; four starts, two terminal losses, one nonterminal
unsupported retirement and one run censored at exit. This is not a completed
ten-run batch. The later current own-close statement authorizes installation;
it does not turn the censored game into a normal terminal result. All available
source journals matched the archive again before installation.

Release follows the user's current own-close statement and explicit request,
passive absence, backed explicit five-file installation and separate installed
gate. No game control, save/profile access, experiment, automation or cap change.
The user reopened after deployment completed and before the detached installed
gate finished. The gate passed unchanged; no runtime edits or active-log reads
followed that launch. A bookkeeping check originally required launch after the
test-report timestamp; it was corrected to the actual completed-install record,
with the initial assertion retained in completion_before.log.
Installation is not activation; no loaded2.199 gain,50% population win rate or
below1% unused-discard rate is established. Stop this coherent delivery. Broader
ordinary sale fallback/continuation issues from413 remain separate open work.
'''
write(HERE/'REPORT.md',report);write(EVAL/'SESSION_RESET_414.md',report)
write(EVAL/'NEXT_PRIORITIES_414.md','''# Priorities after installed414

1.2.199 is installed and both gates passed. User may start new play; do not read
  active journals or reinstall. Current full checkpoint is SESSION_RESET_414.
2. After a completed session and normal exit, preserve logs before Clear. Audit
  phase_copy_review against actual Joker order, copies created and later use;
  measure unused-discard clears and adjudicate exceptions. No loaded2.199 gain.
3. Older2.198 copy is in development414/logs1: two losses, one nonterminal retirement,
  one censored run. Only Perkeo exits received this narrow audit. Do not label it
  a completed marathon or assume censored/unsupported runs ended normally.
4. Read-only413 identified Brainstorm sale→different purchase and a score-budget
  fallback abandoning rejection evidence; ordinary sale commitments remain open.
  Its rental-reserve funding hypothesis also needs an independent fixture.
5. Existing order shortlist and long-horizon stock/sale values remain bounded
  heuristics. Complete older412 marathon adjudication remains pending.

414 review allowance and this delivery are complete. No new experiment, captured
policy replay, game control or score-cap expansion is authorized.
''')
write(EVAL/'ARCHITECTURE_MAP_414.md','''# Installed414 navigation

- Brainstorm/Advisor/strategy.lua inventory_value: immediate_exit option computes
  exact marginal urn stock/Observatory utility for up to8 immediate callbacks.
  Ordinary callers retain old limits and approximation behavior.
- Brainstorm/Advisor/phase_copy.lua shop: exact immediate comparison; teacher-only
  nondecreasing utility ties prefer extra copy events; existing row guards remain.
- Brainstorm/Advisor/player_journal.lua compact_phase_copy_review: bounded public
  event/value/tie/action/rejection receipt on current advice.
- tests/advisor_perkeo_exit414.lua:66 independently invented checks.
  tests/advisor_runtime.lua:868 total, including real mock adapter reorder→exit.
- development414/:437-file before backup,1070 prior-file hashes, failures, bounded
  review, closed public copy/index/Perkeo joins, release helpers and verification.
- runs/repair414_candidate2 and repair414_installed: authoritative exact bytes and
  full gates. Candidate1 is preserved but never installed.
- SESSION_RESET_414.json authoritative installed checkpoint. Older412/413 evidence
  remains immutable, including the separate completed2.196 ten-run capture.
''')
header=f'''INSTALLED REVISION414 — 2026-09-26
2.199.0-alpha is installed. Read tools/advisor_eval/SESSION_RESET_414.md/.json,
NEXT_PRIORITIES_414.md, ARCHITECTURE_MAP_414.md and development414/REPORT.md,
REVIEW.md and FINAL_VERIFICATION.json. Exact digest {digest}.
Both full gates278 Lua/458 Python pass;109 dependencies,324 tests,5 changed paths,
93 deployment/backup paths. Settings and7 DLLs preserved. Candidate1 never installed.
Perkeo shop setup now handles exact whole-pool immediate utility through8 effects;
teacher ties favor more free copies. Ordinary strategic limits/retention/legality
and fresh-advice execution guards remain. No globally optimal/win guarantee.
Closed2.198 archive:9 segments/15,035,884 bytes/6372 events, four starts, two losses,
one nonterminal retirement, one censored run. Ten nonmaximal Perkeo exits confirmed;
this is not a completed ten-run batch. No captured-policy replay or active-log read.
Current own-close statement authorized release, with passive absence and backed
explicit install. Installation is not activation. New play is user-started only;
do not inspect active journals or reinstall during play. No loaded2.199 gain,
50% population win rate or below1% unused-discard rate is established. All prior
preservation/execution/experiment boundaries below remain.414 review cycle and
coherent delivery are complete; no automatic next repair.413 fallback issues remain.

'''
for rel in pre['navigation']:
    path=ROOT/rel;old=path.read_bytes();path.write_bytes(header.encode()+old)
    assert path.read_bytes().endswith((HERE/'before'/rel).read_bytes())
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
before_paths={line[3:] for line in (HERE/'git_status_before.txt').read_text().splitlines() if line}
assert before_paths<={line[3:] for line in status.splitlines() if line}
write(HERE/'git_status_after.txt',status)
paths=[p for p in HERE.glob('*') if p.is_file()]+[HERE/'capture/manifest.json',HERE/'capture/verification.json',
 CANDIDATE/'freeze.json',CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json']
paths.extend(ROOT/rel for rel in pre['navigation'])
paths.extend(EVAL/n for n in ('SESSION_RESET_414.json','SESSION_RESET_414.md','NEXT_PRIORITIES_414.md','ARCHITECTURE_MAP_414.md'))
exact(True)
save(HERE/'FINAL_VERIFICATION.json',{'verified_utc':now(),'version':'2.199.0-alpha','revision':414,'digest':digest,
 'candidate_and_installed_gates_passed':True,'counts':counts[0],'installed_runtime_exact':True,
 'config_preserved':True,'native_files_preserved':7,'deployed_and_backed_paths':93,'prior_files_preserved':len(pre['prior_files']),
 'before_files_preserved':len(pre['before_files']),'public_segments_preserved':9,'public_bytes_preserved':manifest['total_bytes'],
 'normal_exit_confirmed':True,'passive_processes':observed,'activation_confirmed':False,
 'deep_public_audit_complete':False,'game_control':False,'save_profile_access':False,'captured_policy_replay':False,
 'final_tie_rule_primary_verified_after_focused_review':True,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in paths}})
print(json.dumps({'installed':'2.199.0-alpha','revision':414,'digest':digest,'gates':counts[0],'public_segments_saved':9,'backup':str(backup)}))
