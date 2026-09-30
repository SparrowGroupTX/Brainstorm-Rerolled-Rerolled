"""Close new experiment and update navigation without changing runtime/history."""
from pathlib import Path
from datetime import datetime,timezone
import json,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
import run
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,t):
 with p.open('x',encoding='utf-8')as f:f.write(t)
pre=read(HERE/'prework.json');base=read(EVAL/'INSTALLED_CHECKPOINT_437.json');installed=Path(base['installed'])
candidate=EVAL/'runs/repair438_candidate1';freeze=read(candidate/'freeze.json');gate=read(candidate/'validation/report.json')
assert gate['passed'] and policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files'] and provenance()==gate['validation_provenance']
assert policy_hashes(installed.parent)==base['policy_files']
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h,rel
for rel,h in freeze['evaluation_helpers'].items():assert file_digest(ROOT/rel)==file_digest(candidate/'helpers'/rel)==h,rel
assert file_digest(installed/'config.lua')==pre['config_sha256']
for root in (ROOT/'Brainstorm',installed):assert {p.name:file_digest(p)for p in root.glob('*.dll')}==pre['native_files']
m=run.verify()
for path,h in m['source_files'].items():assert file_digest(Path(path))==h,path
closed=read(HERE/'CLOSED.json');jobs=read(HERE/'jobs.json');r=read(HERE/'RESULTS.json');actual=read(HERE/'ARCHIVED_METRICS.json')
assert closed['registered']==closed['received']==len(jobs)==20 and closed['remaining_authority']==closed['retries']==0 and closed['error'] is None
assert not closed['resumption_permitted'];assert len(list((HERE/'ledger').glob('*.started.json')))==len(list((HERE/'ledger').glob('*.worker.json')))==20
seconds=0
for key in jobs:
 row=read(HERE/'results'/f'{key}.json');assert row['status']=='complete' and row['exit_code']==0
 assert file_digest(HERE/'results'/f'{key}.jsonl')==row['output_sha256'];seconds+=row['seconds']
for capture in (HERE/'captures/001',HERE/'reported_round/captures/001'):
 cm=read(capture/'manifest.json');summary=read(capture/'summary.json')
 assert not summary['errors'] and file_digest(capture/'events.sqlite3')==summary['database_sha256']
 for part in cm['segments']:assert file_digest(capture/'logs'/part['name'])==part['sha256']
assert r['registered']==20 and r['completed_rounds']==17 and r['censored_rounds']==3
ps=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq "Balatro" } | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else[]
branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip();assert branch=='codex/exact-search-speedups'
now=datetime.now(timezone.utc).isoformat();c=r['completed'];prefix=r['censored_prefixes']
receipt={'created_utc':now,'revision':439,'type':'closed_targeted_experiment','branch':branch,
 'candidate':'2.217.0-alpha','candidate_policy_digest':freeze['candidate_policy_digest'],'candidate_installed':False,
 'installed_version':base['version'],'installed_release':437,'installed_policy_digest':base['policy_digest'],'installed_unchanged':True,
 'runtime_dependencies':110,'frozen_test_files':370,'reused_candidate_gate':{'lua_fixtures':319,'python_tests':458,'unchanged':True},
 'runner_controls':6,'analysis_controls':5,'invented_preflights':1,'registered_jobs':20,'completed_rounds':17,'censored_rounds':3,
 'completed':c,'censored_prefixes':prefix,'all_twenty_benchmark_verified':False,'registered_target_cards':252,
 'all_attempt_prefix_cards':c['cards_discarded']+prefix['cards_discarded'],'all_attempt_prefix_discards':c['discards_used']+prefix['discards_used'],
 'elapsed_seconds':closed['elapsed_seconds'],'summed_child_seconds':seconds,'reserved_child_seconds':800,'remaining_authority':0,
 'workers_max':4,'job_seconds_max':40,'overall_seconds_max':600,'actions_per_job_max':16,'retries':0,'resumption_permitted':False,
 'review_exhausted':True,'policy_tuning_after_results':False,'loaded_candidate_evidence':False,'config_unchanged':True,
 'preserved_native_files':7,'preserved_prior_files':len(pre['prior_files']),'passive_processes':processes,'normal_exit_inferred':False,
 'game_control':False,'save_profile_access':False,'original_journals_modified':False,'runtime_modified':False,
 'manifest_sha256':file_digest(HERE/'manifest.json'),'capture_cutoff_sequence':13678,'reported_round_cutoff_sequence':17252,
 'reported_zero_discard_round':{'run':6,'round':12,'ante':5,'observation':16439,'advice':16441,'settled_observation':16449,'remains_unfixed':True},
 'archived_metrics':{k:v for k,v in actual.items()if k!='rows'}}
save(EVAL/'EXPERIMENT_CHECKPOINT_439.json',receipt);save(EVAL/'SESSION_RESET_439.json',receipt)
report=f'''# Closed experiment439: twenty targeted continuations

The discard benchmark is NOT met. Frozen candidate2.217 completed17 of20 modeled
rounds. These17 averaged2.8824 discard actions and11.1765 cards per round,
3.8776 cards per discard.190 cards against216 required;49/54 discards used.
Eleven of17 individual complete rounds reached their card-count target.

| Completed subset | Rounds | Discards/round | Cards/round | Required cards/round |
|---|---:|---:|---:|---:|
| Three available discards |14|2.9286|11.8571|12|
| Four available discards |3|2.6667|8|16|
| All complete rounds |17|2.8824|11.1765|12.7059|

Three additional attempts reached a supported clearing score floor after three
five-card discards each, but final Matador earnings/resource transitions were
unsupported. Their45 cards/9 discards remain separate censored-prefix evidence.
Across all20 attempts, known prefixes total235 cards/58 discards (11.75/2.90 per
attempt), not a validated20-complete-round average. Entire cohort target252 cards
(12.6 per round). No timeouts/errors/action-cap cases; no jobs replaced or retried.

Concrete findings from frozen receipts:

* Run3 round23, Cerulean Bell: zero of4 discards, then clear. Growth refused draw
  changes to finishing conditions. The adapter now models Bell's forced-card
  refill, but the runtime retained-clear policy still blocks this family.
* Run4 round23, Verdant Leaf:5+4 cards, then clear with1 discard. A scoring-card
  order guard stopped growth admission. This is a public-model gap.
* Run5 round16: all4 discards used but only3+2+1+2=8 cards. Larger candidates
  were present; risk admission rejected them on progress and, for five-card
  candidates, survival/margin criteria. Separate short-action valuation problem;
  simply counting remaining discards would miss it. No claim larger actions
  have been proved safe or that relaxing every guard would improve win-rate.
* Earlier round shortfalls9 and8 cards used all3 actions. Their sampled survival
  refusals need a different diagnosis from zero-discard automatic-clear blocks.

The user's subsequently reported zero-discard clear is independently confirmed
in the preserved later public prefix: run6 round12, Ante5 Small Blind,32,320/
25,000, one Flush, zero of3 discards. Observation16439 -> advice16441 -> request
16444 -> callback16445 -> settled round16449/link16451. Photograph/Hanging Chad
with a9-card hand and two Glass cards hit the scoring-trigger order guard. That
guard remains in2.217; the narrow Blue/Yorick two-play repair does not cover it.
See reported_round/REPORT.md, TRACE.json and source events. It was not inserted
into the experiment or evaluated as a21st case.

Passive archived comparison accounts for all20 actual source rounds through
request/callback/settled counter changes:57 discards/224 cards, averages2.85
actions and11.20 cards. These loaded2.216 source outcomes include19 round clears
and1 round loss. This is descriptive only: simulated2.217 worlds differ from the
actual draws; neither causal policy improvement nor full-game win rate follows.

Scope/provenance: user authorized20 new round continuations.85 eligible openings
from five available runs; balanced quotas2/5/5/4/4 and evenly spaced chronological
selection, before evaluation. One fixed SHA-derived hypothetical world per case.
Candidate digest `{freeze['candidate_policy_digest']}`; exact74 modules, helpers,
wiring, Lua runtime, Python, cases/jobs and scripts bound in manifest.json. No
original game-source execution or private live draw order. No selected Acorn or
Heart coverage. Round rewards, economy and future shops are not simulated.

Validation: reused unchanged438 full gate319 Lua/458 Python,110 runtime/370 tests;
six manufactured runner controls, five accounting/seed controls, one invented
preflight. Reviewer assessment and focused recheck exhausted. Exactly20 exclusive
parent/job/worker registrations consumed. Four low-priority workers;40seconds/job,
16actions/job,800 reserved child seconds/600 overall cap. Actual wall time
{closed['elapsed_seconds']:.2f}s; summed child wall time{seconds:.2f}s. CLOSED, remaining
authority0; no resumption. No policy tuning or runtime change after results.

Installed437/2.216 remains exact; candidate438/2.217 remains UNINSTALLED. Config,
seven DLLs, all{len(pre['prior_files'])} prior artifact hashes and before-copies verified.
Both public captures verified; game remains user-controlled. No normal exit was
inferred. Historical experiments remain closed. Next coherent repair should
address the proven sorting/Bell admission gap, then qualify targeted manufactured
cases; new captured experiments require fresh prospective authority and limits.
'''
write(HERE/'REPORT.md',report);write(EVAL/'EXPERIMENT_CHECKPOINT_439.md',report);write(EVAL/'SESSION_RESET_439.md',report)
write(EVAL/'NEXT_PRIORITIES_439.md','''# Priorities439

Benchmark unmet. Read development439/RESULTS.json and REPORT.md before further
discard claims.17 complete rounds average11.18 cards versus12.71 required;3
Matador final-resource gaps. Do not reopen439 or historical experiment budgets.

First concrete policy gaps: Bell retains all4 discards; card-order guards retain
1 in Leaf and all3 in the independently observed run6 Ante5 Photograph/Chad/Glass
Flush. Candidate438/2.217 does not fix these. Qualify a bounded retained-anchor
proof using actual canonical ordering/retrigger semantics, avoiding blanket
admission or unsupported win-rate claims. Keep12 growth/70fast and other budgets.

Distinct issue: run5 round16 uses3+2+1+2 cards despite4 actions. Risk candidates
include larger sizes but reject progress/survival/margin. Diagnose domination
criteria with manufactured cases before changing survival constraints. Matador
final earnings is a tooling gap, not evidence of a policy failure after15 cards.

Installed437/2.216 unchanged, user plays.438/2.217 candidate exact and uninstalled.
Any runtime edits need a new exact combined freeze/full gate. Installation needs
fresh passive absence, newest journals preserved and backed explicit slice;
never ask for the superseded normal-exit confirmation. No automatic installation.
''')
write(EVAL/'ARCHITECTURE_MAP_439.md','''# Architecture439: evaluation only

capture.py copies bounded public archive prefixes and verifies chained records
into a detached SQLite database. prepare_cases.py selects20 distinct untouched
round openings from capture001, balances run quotas and precommits world mappings.
freeze_experiment.py binds qualified438 policy/helpers and runtime wiring.
seal.py binds reviewed scripts/cases/worlds; run.py exclusive claims permit only
20 child jobs,4workers,40seconds/16actions per job. CLOSED permanently consumes all
remaining allowance. analyze.py uses adapter final_resources_supported plus
supported_clear/modeled_failure for full-round means; all other results remain
censored prefixes. Settled discard sizes reconcile with adapter counters.
archived_metrics.py only reads original public events and verifies action-counter
settlement for descriptive source metrics. reported_round/ holds a separate later
capture/trace; it does not affect selection or add a policy execution. No runtime
or helper changes; current code architecture remains438. Prior records preserved.
''')
prefix_text=f'''CLOSED EXPERIMENT439 —{now[:10]}
Read tools/advisor_eval/EXPERIMENT_CHECKPOINT_439.md/.json, SESSION_RESET_439.md/.json,
NEXT_PRIORITIES_439.md, ARCHITECTURE_MAP_439.md and development439/REPORT.md,
RESULTS.json, ARCHIVED_METRICS.json, CLOSED.json, FINAL_VERIFICATION.json.
20 fixed candidate2.217 attempts:17 complete,3 Matador resource-censored.
Complete averages2.88 discards/11.18 cards per round vs12.71-card target: NOT MET.
Bell/sorting guards still allow early clears. User's run6 Ante5 zero-discard
Flush confirmed separately; remains unfixed in2.217. All20 jobs consumed; no retries.
Installed437/2.216 exact, candidate438/2.217 uninstalled, no runtime edits.
319Lua/458Python gate reused unchanged;6runner/5accounting controls qualified.
User game/journals/settings/seven DLLs preserved; no exit inference or game control.
Review439 exhausted; all experiment leases CLOSED. Earlier records are history.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;assert file_digest(p)==pre['before_files'][rel],rel
 old=p.read_bytes();p.write_bytes(prefix_text.encode('utf-8')+old);assert p.read_bytes().endswith(old)
paths=[HERE/name for name in ('REPORT.md','EXPERIMENT_REPORT.md','RESULTS.json','ARCHIVED_METRICS.json','REVIEW.md','manifest.json','READY.json','EXECUTION_STARTED.json','CLOSED.json','reported_round/REPORT.md','reported_round/TRACE.json')]
paths += [EVAL/name for name in ('EXPERIMENT_CHECKPOINT_439.md','EXPERIMENT_CHECKPOINT_439.json','SESSION_RESET_439.md','SESSION_RESET_439.json','NEXT_PRIORITIES_439.md','ARCHITECTURE_MAP_439.md')]
receipt['artifact_hashes']={p.relative_to(ROOT).as_posix():file_digest(p)for p in paths};save(HERE/'FINAL_VERIFICATION.json',receipt)
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:receipt[k]for k in ('registered_jobs','completed_rounds','censored_rounds','elapsed_seconds','summed_child_seconds','installed_unchanged','preserved_prior_files','passive_processes')}))
