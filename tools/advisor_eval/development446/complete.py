"""Seal exact candidate2 and the fixed public analysis; leave installation alone."""
from pathlib import Path
from datetime import datetime, timezone
import difflib,json,re,subprocess,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
def save(p,x):
    with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,x):
    with p.open('x',encoding='utf-8')as f:f.write(x)
P=read(H/'prework.json');Q=read(H/'repair_prework.json');B=P['installed']
C=E/'runs/repair446_candidate2';F=read(C/'freeze.json');G=read(C/'validation/report.json')
assert all(G[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']==G['policy_files']
assert test_manifest()==F['test_files']==G['test_files']
assert provenance()==Q['provenance']==F['validation_provenance']==G['validation_provenance']
assert file_digest(H/'SCOPE.md')==F['scope_sha256']
installed=Path(B['installed']);assert policy_hashes(installed.parent)==B['policy_files']
assert file_digest(installed/'config.lua')==P['config_sha256']
for root in (R/'Brainstorm',installed):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
for rel,h in Q['prior_files'].items():assert file_digest(R/rel)==h,rel
for rel,h in Q['before_files'].items():assert file_digest(H/'before_runtime'/rel)==h,rel
for rel,h in P['before_files'].items():assert file_digest(H/'before'/rel)==h,rel
for rel,h in F['test_files'].items():assert file_digest(C/'tests_source'/rel)==h,rel
for rel,h in F['evaluation_helpers'].items():assert file_digest(R/rel)==file_digest(C/'helpers'/rel)==h,rel
match=re.search(r'(\d+)/(\d+) fixtures passed',(C/'validation/lua.log').read_text());assert match and match[1]==match[2]=='325'
py=sum(int(re.search(r'Ran (\d+) tests',(C/'validation'/n).read_text())[1])for n in ('python.log','python_1.log','python_2.log'));assert py==494
capture=H/'log_copy/captures/001';summary=read(capture/'summary.json');manifest=read(capture/'manifest.json')
assert not summary['errors']and file_digest(capture/'events.sqlite3')==summary['database_sha256']
for segment in manifest['segments']:
    assert segment['source_prefix_still_matched']and file_digest(capture/'logs'/segment['name'])==segment['sha256']
ps=subprocess.run(['pwsh','-NoProfile','-Command',
 '@(Get-Process -ErrorAction Stop | Where-Object {$_.ProcessName -ieq "Balatro"} | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],
 capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else[]
branch=subprocess.run(['git','branch','--show-current'],cwd=R,capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW).stdout.strip()
assert branch=='codex/exact-search-speedups'
stamp=datetime.now(timezone.utc).isoformat();metrics=read(H/'METRICS.json')
checkpoint={'created_utc':stamp,'revision':446,'candidate_version':'2.221.0-alpha',
 'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],
 'candidate_freeze':C.relative_to(R).as_posix()+'/freeze.json','full_candidate_gate_passed':True,
 'lua_fixtures':325,'python_tests':494,'new_manufactured_assertions':65,'runtime_file_count':110,'test_file_count':378,
 'changed_runtime_files':F['changed_from_installed444'],'installed_release':444,'installed_version':'2.219.0-alpha',
 'installed_unchanged':True,'installation_performed':False,'passive_processes':processes,
 'installation_status':'Deferred while Balatro is running'if processes else'Candidate ready; deployment not performed',
 'config_preserved':True,'native_files_preserved':7,'prior445_files_preserved':len(Q['prior_files']),
 'pre_repair_runtime_and_test_files_preserved':len(Q['before_files']),
 'loaded_2219_prefix':{'capture':capture.relative_to(R).as_posix(),'events':summary['events'],
  'versions':summary['versions'],'outcomes':summary['outcomes'],'unended_run_ids':summary['unended_run_ids'],
  'archive_errors':summary['errors'],'complete_marathon':False},
 'confirmed_discards':225,'confirmed_cards_discarded':1038,'qualified_clears':81,'unused_discard_clears':6,
 'round_average_cards':metrics['positive_discard_average_cards'],'round_average_denominator':80,
 'round_average_scope':'qualified completed rounds with positive initial discards; see ACCOUNTING.md',
 'captured_policy_executions':0,'game_control':False,'historical_experiments':'CLOSED',
 'review_exhausted':True,'all_discard_cases_fixed':False,'loaded_2221_efficacy':'No evidence',
 'candidate1_qualified':False,'candidate1_failure':'Existing nonwinning Burnt setup regression; preserved and corrected in candidate2'}
save(E/'CANDIDATE_CHECKPOINT_446.json',checkpoint);save(E/'SESSION_RESET_446.json',checkpoint)
write(E/'CANDIDATE_CHECKPOINT_446.md',f'''# Candidate446 /2.221.0-alpha

Exact candidate2 passes325 Lua fixtures/494 Python tests;110 runtime dependencies,
378 frozen test files. Digest `{F['candidate_policy_digest']}`.
Eight files differ from installed444, including445's two Acorn modules, four446
runtime modules and two version stamps. See development446/REPORT.md, TRACE.json,
METRICS.json, ACCOUNTING.md, REVIEW.md and FINAL_VERIFICATION.json.

Repairs: shared-budget Burnt/Yorick order stall; reserve-ineligible vacant-slot
copy-funding sale; failed phase work receipts. Retains445 Acorn hand-size and
canonical identity continuity fixes. No bigger score budgets or removed guards.

NOT INSTALLED: installed444/2.219 is exact. Passive processes: `{processes}`.
Copied active2.219 prefix:13,111 events,2wins/1loss/1stalled retirement and1unfinished
game.225 confirmed discards/1,038 cards;6 clears leave18 discards. Qualified80-round
average12.79 cards exceeds12, but14 rounds fall below target. See accounting
exclusions; no population win-rate claim or claim that every discard is fixed.

Candidate1 failure is preserved. Candidate2 is the only qualified446 freeze.
Historical experiments/review446 are CLOSED; no captured execution or game control.
Installation follows INSTALLATION_POLICY.md after fresh passive absence and newest
public-log preservation, then backed deployment and exact-installed qualification.
No normal-exit confirmation is required. Loaded2.221 efficacy is untested.
''')
write(E/'SESSION_RESET_446.md','''# Resume446

Read CANDIDATE_CHECKPOINT_446.md/.json and development446/REPORT.md, TRACE.json,
METRICS.json, ACCOUNTING.md, REVIEW.md and FINAL_VERIFICATION.json. Candidate2 /2.221
passes325Lua/494Python; installed444/2.219 unchanged. Candidate1 is unqualified.
All445 frozen/prior work and all pre446 runtime/tests are preserved.

This slice analyzed one fixed active-session cutoff,13,111events, with one unfinished
game. Do not infer later completion or normal exit. It repairs the supported
Burnt budget loop and inconsistent copy-funding sale. Six unused-discard clears
and other strategy questions are still open; heuristic flags are not regret proof.
No captured policy/scorer, original-game code, simulation, saves/profiles or game
control occurred. Prior experiment budgets and446 review are exhausted. A future
slice needs prospective scope and exact combined qualification. Installation follows
INSTALLATION_POLICY.md, including newest-log preservation and a fresh passive
absence check; user confirmation is not required.
''')
write(E/'NEXT_PRIORITIES_446.md','''# Priorities446

1. Once Balatro is absent, preserve newest public logs and install qualified
   repair446_candidate2 /2.221 using the backed release procedure. Fully qualify
   exact installed bytes. Do not deploy candidate1 or superseded445 alone.
2. In a later user-started loaded2.221 session, look for the former seventeen-order
   Burnt/Yorick loop and confirm actual first-discard effects. Missing exposure
   is not evidence of effectiveness. Check new phase work receipts.
3. Resolve the six unused-discard clears by exact blocker: canonical public held
   floors (including the Astronomer lead and dynamic Raised Fist), retained-clear
   failures, and Acorn complete-family cost. Prove safe alternatives; do not simply
   increase budgets or force a score/resource-unsafe discard.
4. Extend offline settlement coverage to reorder stalls, sale-followup failures
   and consumables. The current screener misses ordering and can suppress a
   reserve-invalid sale plan; raw sequence auditing exposed both supported bugs.
5. Assess pack/Invisible/Death timing hypotheses with qualified endpoint witnesses.
   Prefer bounded independently checked alternatives over scalar merit conflicts.

No experiment authorization is created. All past budgets and446 review are closed.
No all-fixed, optimal-strategy or population win-rate claim.
''')
write(E/'ARCHITECTURE_MAP_446.md','''# Budget and funding flow446

Decision derives one requested ordinary aggregate, reserves<=18 phase calls when
a first-discard visible Burnt/copy comparison and an incumbent pass can fit, then
carries the pre-phase ceiling through Search and every specialist. Consumable
search reservation remains separate. An actual fast-clear result retains70;
requesting the shortcut alone does not reduce ordinary unsuccessful search.

The clear-shortcut branch gives the shared12-call growth comparison to eligible
phase copying before optional current-row development. Phase scores at most three
held subsets across two scoring orders, then uses12 minus earlier growth work.
Apply charges both aggregate and growth work even when no override is admitted.
Final discard arbitration sees only the residual allowance. Fresh advice and
complete exact resource/retained-clear proof remain required. Journal export
includes failed eligible Burnt scope and bounded work fields.

Strategy's vacant-slot one-sale copy-funding endpoints require projected raw cash
>=copy_cash_reserve(after), matching focused direct acquisition. A negative
bankruptcy floor only affects affordability, not cash reserve. Full-row replacement
comparisons, existing core guards and qualified funded fresh-buy routes remain.

New manufactured fixtures test saturation, exact/short budgets, prior growth,
actual/unsuccessful fast shortcuts, one-score incumbents, retries, necessary items,
funded/unfunded rentals and Credit Card. Existing420 checks nonwinning setup and
physical first-discard/restore transitions.445 Acorn fixes remain included.

Offline screen coverage remains limited; development446 supplements it with a
fixed raw public sequence audit. No captured policy/scorer execution was used.
''')
diff=[]
changed=[r for r,h in F['candidate_policy_files'].items()if h!=Q['before_files'].get(r)]
for rel in changed:
    diff.extend(difflib.unified_diff((H/'before_runtime'/rel).read_text().splitlines(True),(R/rel).read_text().splitlines(True),
      fromfile='before445/'+rel,tofile='candidate446/'+rel))
write(H/'final_changes.diff',''.join(diff))
prefix=f'''VALIDATED CANDIDATE446 /2.221.0-alpha —{stamp[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_446.md/.json, SESSION_RESET_446.md/.json,
NEXT_PRIORITIES_446.md, ARCHITECTURE_MAP_446.md and development446/REPORT.md,
TRACE.json, METRICS.json, ACCOUNTING.md, REVIEW.md, FINAL_VERIFICATION.json.
Candidate2 passes325Lua/494Python;110runtime/378tests; digest
{F['candidate_policy_digest']}.
Burnt shared-budget order-stall repair and consistent vacant-slot copy funding,
including445 Acorn repairs. NOT INSTALLED:444/2.219 remains exact.
Copied2.219 prefix13,111events:2wins/1loss/1stall/1unfinishedgame.225discards,
1,038cards;80qualified completed rounds average12.79, but6clears leave18discards.
No all-fixed or population win-rate claim. Review446/historical experiments CLOSED;
no captured executions or game control. INSTALLATION_POLICY.md governs deployment
after fresh passive absence/newest-log preservation. Earlier status is history.

'''
nav={}
for rel in P['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'):continue
    path=R/rel;old=path.read_bytes();assert file_digest(path)==P['before_files'][rel]
    path.write_bytes(prefix.encode('utf-8')+old);assert path.read_bytes().endswith(old);nav[rel]=file_digest(path)
paths=[E/(name+'_446'+ext)for name in ('CANDIDATE_CHECKPOINT','SESSION_RESET')for ext in ('.json','.md')]
paths += [E/'NEXT_PRIORITIES_446.md',E/'ARCHITECTURE_MAP_446.md',H/'REPORT.md',H/'REVIEW.md',H/'METRICS.json',
 H/'ACCOUNTING.md',H/'TRACE.json',H/'target2.log',H/'final_changes.diff',C/'freeze.json',C/'validation/report.json',
 capture/'manifest.json',capture/'summary.json']
save(H/'FINAL_VERIFICATION.json',{'verified_utc':stamp,**checkpoint,'navigation_hashes':nav,
 'artifact_hashes':{p.relative_to(R).as_posix():file_digest(p)for p in paths}})
print(json.dumps({k:checkpoint[k]for k in ('candidate_version','candidate_policy_digest','lua_fixtures','python_tests',
 'installation_status','passive_processes','prior445_files_preserved')}))
