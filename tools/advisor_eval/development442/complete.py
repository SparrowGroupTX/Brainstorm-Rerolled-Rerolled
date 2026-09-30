"""Close442 with honest blocked full-gate status and preserved history."""
from pathlib import Path
from datetime import datetime,timezone
import json,re,subprocess,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,t):
 with p.open('x',encoding='utf-8')as f:f.write(t)
C=E/'runs/repair442_candidate2';F=read(C/'freeze.json');G=read(C/'validation/report.json');P=read(H/'prework.json');B=read(E/'INSTALLED_CHECKPOINT_440.json')
assert not G['passed'] and G['policy_unchanged'] and G['tests_unchanged'] and G['provenance_unchanged']
assert G['runs'][0]['status']=='timeout' and all(x['status']=='passed' for x in G['runs'][1:])
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']==G['policy_files']
assert test_manifest()==F['test_files']==G['test_files'] and provenance()==F['validation_provenance']==G['validation_provenance']
for rel,h in F['test_files'].items():assert file_digest(C/'tests_source'/rel)==h,rel
for rel,h in F['evaluation_helpers'].items():assert file_digest(R/rel)==file_digest(C/'helpers'/rel)==h,rel
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
for rel,h in P['before_files'].items():assert file_digest(H/'before'/rel)==h,rel
installed=Path(B['installed']);assert policy_hashes(installed.parent)==B['policy_files']
assert file_digest(installed/'config.lua')==P['config_sha256']
for root in(R/'Brainstorm',installed):assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
assert file_digest(H/'SCOPE.md')==F['scope_sha256']
phase=read(H/'phase_a/RESULTS.json');closed=read(H/'phase_a/CLOSED.json');assert closed['remaining_authority']==0
assert not(H/'phase_b').exists()
now=datetime.now(timezone.utc).isoformat()
save(H/'CLOSED.json',{'at':now,'phase_a_registered':20,'phase_a_received':20,'phase_a_reserved_child_seconds':800,'phase_a_elapsed_seconds':closed['elapsed_seconds'],'phase_b_executed':False,'phase_b_unused_jobs_permanently_closed':20,'remaining_authority':0,'retries':0,'resumption_permitted':False,'reason':'New candidate full Lua gate timed out; optional phase B qualification prerequisite unmet.'})
ps=subprocess.run(['pwsh','-NoProfile','-Command',"@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else[]
branch=subprocess.run(['git','branch','--show-current'],cwd=R,capture_output=True,text=True,check=True).stdout.strip();assert branch=='codex/exact-search-speedups'
lua=(C/'validation/lua.log').read_text();assert 'PASS tests' in lua and 'advisor_forecast_integrity442.lua' in lua
python=sum(int(re.search(r'Ran (\d+) tests',(C/'validation'/n).read_text())[1])for n in('python.log','python_1.log','python_2.log'));assert python==458
receipt={'created_utc':now,'revision':442,'candidate_version':'2.219.0-alpha','candidate':C.relative_to(R).as_posix(),'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],'candidate_installed':False,'release_ready':False,'blocker':'Full Lua regression gate exceeded existing60-second cap twice; candidate2 has no reported assertion failure before timeout. No retry or cap relaxation.','full_gate_passed':False,'python_tests_passed':458,'targeted_fixture_count':3,'targeted_assertions_before_final_fallback':4086,'runtime_dependencies':110,'test_files':373,'installed_release':440,'installed_version':B['version'],'installed':str(installed),'installed_policy_digest':B['policy_digest'],'installed_unchanged':True,'config_unchanged':True,'native_files_preserved':7,'preserved_prior_files':len(P['prior_files']),'review_exhausted':True,'experiment_closed':True,'counterfactual_phase_a':phase['completed'],'loaded_candidate_evidence':False,'loaded_win_rate_claim':False,'game_control':False,'save_profile_access':False,'original_journals_modified':False,'normal_exit_inferred':False,'passive_processes':processes,'branch':branch}
save(E/'CANDIDATE_CHECKPOINT_442.json',receipt);save(E/'SESSION_RESET_442.json',receipt)
report=f'''#442 forecast integrity audit and blocked2.219 candidate

Installed440/2.218 remains unchanged. Candidate2.219 is frozen at
`{F['candidate_policy_digest']}` but NOT release-ready: both full Lua attempts
hit the unchanged60-second timeout. Candidate1 additionally exposed an obsolete
five-card expectation; candidate2 corrected that fixture and two review defects.
Candidate2 has no reported assertion failure before timeout.458 Python tests pass;
target4's three fixtures pass932+355+2799=4086 assertions. The final candidate adds
one fallback assertion, and its forecast fixture reports PASS before timeout.
Do not claim322/322 full Lua success. No installation or candidate activation.

The meaningful repair is forecast integrity. Actual automatic rank/suit sorting
can move Mult/Glass order and turn a forecast clear into an actual failure. The
old forecast appended replacement cards. Public snapshots now copy configured
sort and deterministic physical tie metadata, and detached futures implement
the source-qualified sort. Invalid declared metadata is rejected; old snapshots
without metadata remain explicitly legacy/unverified. Death retains destination
physical identity and original-suit tie data; Strength/suit changes update nominal
fields. Bell's chosen physical card moves with sorting; Search must not force its
old slot again. Incomplete continuation adapters reject declared automatic sort.

Sampled clear admission also discarded already-computed Glass/population/Arm
costs when capping both outcomes at a clear. It now requires no worsening of
those known costs across every completed common world. No extra scorer calls or
larger production budgets. Public receipts expose resource rejections/sort scope.
The old small_order428 test's five-card expectation became inappropriate once a
safe zero-Glass Flush existed: it now permits a smaller discard only with explicit
five-card resource rejection, still forbidding premature Tarot/clear behavior.

Phase A used the same20 states/worlds as historical439, with frozen installed2.218
and unchanged qualified adapter/runner.20/20 modeled clears,0censored;63/63
discards used;256cards,12.8/round and4.06349/discard vs252required.16/20 individual
rounds meet their target. The17 three-discard rounds average13.11765cards, but the
three four-discard rounds average11 against16 required (17,8,8cards). This is a
real unresolved shortfall despite the aggregate pass. Historical439 had17 complete
and3Matador-censored outcomes; do not compare changed denominators as causal gain.
On the same17 complete cases, cards rise190to211 and actions49to54, but211 is below
216required. The formerly censored three cases now complete with15cards each.
This is a selected development cohort with one hypothetical world per opening,
not20full games, held-out evidence, actual draw reconstruction or a win-rate claim.
Legacy inputs cannot validate the newly captured sorting metadata. Optional Phase B
was not executed because full qualification failed; its20unused jobs are CLOSED.

Passive screening of the preserved complete loaded2.216 session produced250
hypotheses:199short-discard,50unused-discard-at-clear,1unstructured core sale.
These are not250confirmed errors. The Perkeo sale in run4Ante8round23 explicitly
disabled Verdant Leaf: advice11154, request11157, settlement11161/link11163;
public retained4OAK forecast624960vs400000 and laterwin11178. The flag lacks a
structured plan but the decision has a supported strategic reason. No sale patch.
The session's three actual losses were early:426/600 Ante1Big,1132/1500 Ante2Small,
1173/2000 Ante2Big. Opening economy/survival remains a high-value unresolved causal
question; terminal deficits do not establish which earlier purchase was wrong.

The complete29-segment2.216 ten-run archive stays in
development440/install/captures/001:27163events,7wins/3losses. The copied2.218
prefix in development441/log_copy/captures/001 confirms activation only:2starts,
1loss,1ongoing at capture. Do not describe either as this current completed marathon.
Live journals were not changed. All{len(P['prior_files'])} preserved artifact hashes,
before copies, installed runtime, settings and7DLLs verify unchanged. Review442 is
exhausted; all experiment authority is CLOSED. No saved games or game control.

Next discriminating step: diagnose the Lua wall-time overrun from preserved logs
and a bounded per-fixture timing plan before retrying; no speculative gate expansion
or release. Once exact full qualification is established, current journals need
fresh passive preservation before any future authorized install. Then prioritize
four-discard shortfalls and early shop/survival paths using complete public traces.
'''
write(H/'REPORT.md',report);write(E/'CANDIDATE_CHECKPOINT_442.md',report)
write(H/'REVIEW.md','''# Review442: exhausted

One substantive read-only assessment and one focused recheck by the same reviewer.
Assessment identified automatic sort fidelity and omitted already-computed
Glass/population/Arm costs. Primary implemented and manufactured-tested them.
Focused recheck found duplicate Bell forcing after sorted authoritative refill and
Death incorrectly copying source original-suit metadata. Both corrected with real
Search continuation and close-tie Death regressions. Declared-sort legacy fallback
now rejects incomplete adapters. Reviewer source recheck: no remaining blocker in
this focused scope; historical snapshots cannot establish exact sorting fidelity.
Reviewer ran no tests or policy evaluations. Review allocation is exhausted.
Full candidate qualification is independently BLOCKED by Lua60-second timeout;
passing source review/targeted tests do not substitute for full release validation.
''')
write(E/'SESSION_RESET_442.md','''# Resume442

Read CANDIDATE_CHECKPOINT_442.md/.json, development442/REPORT.md, REVIEW.md,
FINAL_VERIFICATION.json, CLOSED.json and phase_a/RESULTS.json. Root is frozen
candidate2.219, NOT qualified or installed. Installed440/2.218 remains exact.
Preserve all work/failures. Both full Lua gates timed out;458Python pass. Never
install unfinished work. Review442 exhausted; experiments all CLOSED. No Phase B
continuation or historical retry authority. Read root ADVISOR_RESUME_PROMPT.md
and INSTALLATION_POLICY.md. Passive process absence is sufficient only after
preservation and complete exact release gates; never infer normal exit.
''')
write(E/'NEXT_PRIORITIES_442.md','''# Priorities442

1. Resolve full Lua regression wall-time blocker with a concrete bounded timing
   diagnosis. Do not weaken tests/caps or repeatedly rerun unchanged whole gates.
2. Later loaded2.219 metadata must validate exact automatic sort in public traces;
   historical snapshots lack it. Candidate remains uninstalled/unqualified now.
3. Four-discard targeted rounds average11cards vs16target despite exhausting all
   actions. Distinguish retained resources, forced Bell card, feasible batch sizes,
   work-budget exclusions and arbitration; never trade known survival for counts.
4. Trace three early losses through opening purchases/interest, scoring support,
   discards and subsequent shops before assigning blame. Do not infer causal
   superiority from successful-run hindsight or a terminal score deficit.
5. Structured Leaf rescue sale receipt could reduce a false-positive heuristic.
   Actual run4 Perkeo sale was supported, so no strategy patch based on that flag.

These are priorities, not permission to reopen CLOSED experiments or start a
second slice automatically. Preserve current live journals and user-started play.
''')
write(E/'ARCHITECTURE_MAP_442.md','''# Forecast integrity442

snapshot.card/capture copy physical sort_tie and hand_sort. draws.sort_hand models
source nominal ordering on detached cards; fill chooses one Bell physical card
before sorting. Search.discard_state sorts sampled futures; multi-play authoritative
fill owns Bell selection. Legacy snapshots are labeled unverified, invalid declared
metadata fails closed. Death preserves destination first-suit/tie; transformed
bases refresh face/suit nominal. No original game methods or RNG are executed.

Search's existing best-play population_cost/glass_loss/arm_cost feed trial resource
preservation. Regressions commit only with entire completed paired sample families;
sampled clear qualification requires zero. player_journal emits bounded rejection
counts/sort scope. Existing score budgets and deterministic retained proofs remain.

candidate2 freeze binds110runtime dependencies/373testfiles and unchanged helper
provenance. Full Lua gate timed out, so release blocked. phase_a is one-use20jobs
with four below-normal workers; B never executed and is permanently closed.
''')
prefix=f'''FROZEN BUT UNQUALIFIED CANDIDATE442 /2.219.0-alpha —{now[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_442.md/.json, SESSION_RESET_442.md/.json,
NEXT_PRIORITIES_442.md, ARCHITECTURE_MAP_442.md and development442/REPORT.md,
REVIEW.md, CLOSED.json, FINAL_VERIFICATION.json. Installed440/2.218 unchanged.
Candidate2 full Lua gate TIMEOUT60s;458Python pass. No release/installation.
Digest {F['candidate_policy_digest']};110runtime/373testfiles.
Repairs source automatic sort and known finishing resource costs; Bell/Death
integration regressions covered. PhaseA2.218:20modeled clears,63/63discards,
256cards/20=12.8; four-discard subset11vs16target. No loaded win-rate claim.
PhaseB unexecuted/CLOSED; review442 exhausted; all historical budgets CLOSED.
Current2.218 prefix activation confirmed in441; current marathon is not audited.
Preserve all logs/work; never install unfinished candidate. Earlier records follow.

'''
for rel in P['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=R/rel;assert file_digest(p)==P['before_files'][rel],rel
 old=p.read_bytes();p.write_bytes(prefix.encode()+old);assert p.read_bytes().endswith(old)
paths=[H/n for n in('REPORT.md','REVIEW.md','SCOPE.md','PLAN.md','CLOSED.json','SORT_SOURCE_READ.json','DEATH_SOURCE_READ.json')]+[C/'freeze.json',C/'validation/report.json']
receipt['artifact_hashes']={p.relative_to(R).as_posix():file_digest(p)for p in paths}
save(H/'FINAL_VERIFICATION.json',receipt)
write(H/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=R,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:receipt[k]for k in('candidate_version','release_ready','installed_unchanged','preserved_prior_files','passive_processes')}))
