"""Seal the exact candidate and immutable public audit without installing."""
from pathlib import Path
from datetime import datetime,timezone
import difflib,json,re,subprocess,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
def save(p,x):
    with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,x):
    with p.open('x',encoding='utf-8')as f:f.write(x)
P=read(H/'prework.json');B=P['installed'];C=E/'runs/repair447_candidate1'
F=read(C/'freeze.json');G=read(C/'validation/report.json')
assert all(G[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']==G['policy_files']
assert test_manifest()==F['test_files']==G['test_files']
assert provenance()==P['provenance']==F['validation_provenance']==G['validation_provenance']
assert file_digest(H/'SCOPE.md')==F['scope_sha256']
installed=Path(B['installed']);assert policy_hashes(installed.parent)==B['policy_files']
assert file_digest(installed/'config.lua')==P['config_sha256']
for root in (R/'Brainstorm',installed):
    assert {p.name:file_digest(p)for p in root.glob('*.dll')}==P['native_files']
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
for rel,h in P['before_files'].items():assert file_digest(H/'before'/rel)==h,rel
for rel,h in F['test_files'].items():assert file_digest(C/'tests_source'/rel)==h,rel
for rel,h in F['evaluation_helpers'].items():assert file_digest(R/rel)==file_digest(C/'helpers'/rel)==h,rel
match=re.search(r'(\d+)/(\d+) fixtures passed',(C/'validation/lua.log').read_text());assert match and match[1]==match[2]=='326'
py=sum(int(re.search(r'Ran (\d+) tests',(C/'validation'/n).read_text())[1])for n in ('python.log','python_1.log','python_2.log'));assert py==494
capture=E/'development446/install/captures/001';summary=read(capture/'summary.json');manifest=read(capture/'manifest.json')
assert not summary['errors']and file_digest(capture/'events.sqlite3')==summary['database_sha256']
for segment in manifest['segments']:
    assert segment['source_prefix_still_matched']and file_digest(capture/'logs'/segment['name'])==segment['sha256']
for name,h in read(H/'review/COMPLETE.json')['files'].items():assert file_digest(H/'review'/name)==h,name
ps=subprocess.run(['pwsh','-NoProfile','-Command',
 '@(Get-Process -ErrorAction Stop | Where-Object {$_.ProcessName -ieq "Balatro"} | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],
 capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else[]
branch=subprocess.run(['git','branch','--show-current'],cwd=R,capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW).stdout.strip()
assert branch=='codex/exact-search-speedups'
stamp=datetime.now(timezone.utc).isoformat();metrics=read(H/'METRICS.json')
checkpoint={'created_utc':stamp,'revision':447,'candidate_version':'2.222.0-alpha',
 'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],
 'candidate_freeze':C.relative_to(R).as_posix()+'/freeze.json','full_candidate_gate_passed':True,
 'lua_fixtures':326,'python_tests':494,'new_manufactured_assertions':379,'baseline_negative_assertions':6,
 'runtime_file_count':110,'test_file_count':379,'changed_runtime_files':F['changed_from_installed446'],
 'installed_release':446,'installed_version':'2.221.0-alpha','installed_unchanged':True,
 'installation_performed':False,'passive_processes':processes,
 'installation_status':'Deferred while Balatro is running'if processes else'Candidate ready; deployment not performed',
 'config_preserved':True,'native_files_preserved':7,'prior446_files_preserved':len(P['prior_files']),
 'prework_files_preserved':len(P['before_files']),
 'loaded_2219_archive':{'capture':capture.relative_to(R).as_posix(),'events':summary['events'],
  'versions':summary['versions'],'outcomes':summary['outcomes'],'unended_run_ids':summary['unended_run_ids'],
  'archive_errors':summary['errors'],'complete_marathon':True},
 'confirmed_discards':521,'confirmed_cards_discarded':2315,'qualified_clears':176,
 'unused_discard_clears':10,'unused_discards':31,'round_average_cards':metrics['average_cards'],
 'round_average_denominator':175,'three_discard_average_cards':12.75,'four_discard_average_cards':14.6,
 'four_discard_target_met':False,'flagged_decisions':152,'flags_without_structural_packet':40,
 'captured_policy_executions':0,'game_control':False,'historical_experiments':'CLOSED',
 'review_exhausted':True,'all_discard_cases_fixed':False,'loaded_2222_efficacy':'No evidence',
 'new_session_loaded_version':'Unconfirmed; live journals not read in447'}
save(E/'CANDIDATE_CHECKPOINT_447.json',checkpoint);save(E/'SESSION_RESET_447.json',checkpoint)
write(E/'CANDIDATE_CHECKPOINT_447.md',f'''# Candidate447 / 2.222.0-alpha

Exact candidate1 passes326 Lua fixtures/494 Python tests;110 runtime dependencies,
379 frozen test files. New manufactured fixture has379 assertions; old2.221
negative control has six. Digest `{F['candidate_policy_digest']}`.

Only growth.lua and two version stamps differ from installed446. Canonical
Astronomer becomes arithmetically inert for retained-discard proof; Photograph
uses the strict small-order visible gate. All hidden Joker aliases are rejected.
Complete comparisons,12 growth calls and resource/visibility safeguards remain.
See development447/REPORT.md, REVIEW.md, METRICS.json, UNUSED_CLEAR_TRACE.json,
ALL_FLAGS.json and FINAL_VERIFICATION.json. No captured evaluation was performed.

NOT INSTALLED. Installed446/2.221 remains exact. Passive processes: `{processes}`.
The complete prior loaded2.219 cohort has7wins/2losses/1abandoned stall.175
qualified positive-discard rounds average12.91 cards:three-discard rounds12.75,
four-discard rounds14.6 versus16 target. Ten clears leave31 discards. New proof
coverage does not establish that all historical actions or any full run improve.

Run10 pack-before-visible-Blueprint exposes a future-value admission lead while
Yorick isx1/Perkeo empty; no supported shop repair is included447. See priorities.
Historical experiments and447 review are CLOSED. INSTALLATION_POLICY.md governs
release after fresh successful passive absence and newest public-log preservation.
No normal-exit confirmation required. Loaded2.222 efficacy is untested.
''')
write(E/'SESSION_RESET_447.md','''# Resume447

Read CANDIDATE_CHECKPOINT_447.md/.json, NEXT_PRIORITIES_447.md,
ARCHITECTURE_MAP_447.md and development447/REPORT.md, REVIEW.md, METRICS.json,
UNUSED_CLEAR_TRACE.json, ALL_FLAGS.json and FINAL_VERIFICATION.json.

Candidate1 /2.222 passes326Lua/494Python. Installed446 /2.221 is unchanged.
The entire prior2.219 ten-run archive is preserved in development446/install/
captures/001 and fully analyzed here. New live journals were not read; activation
of installed2.221 in the new session is unconfirmed. No game control occurred.

Canonical Astronomer/Photograph retained-discard eligibility is repaired without
larger budgets or weakened visibility/resources. All hidden/unknown Joker aliases
are rejected. The reviewer found this visibility correction; primary tests and
the full gate qualify the final bytes, with no further reviewer inspection.

Do not claim all discard issues or the four-discard benchmark are solved.
Historical simulations/captured evaluations and447 review are CLOSED. Any future
slice needs prospective scope and exact combined qualification. Release requires
fresh passive absence/newest-log preservation, backed explicit-file deployment and
exact-installed full qualification per INSTALLATION_POLICY.md. No closure question.
''')
write(E/'NEXT_PRIORITIES_447.md','''# Priorities447

1. Install qualified repair447_candidate1 /2.222 only after fresh passive Balatro
   absence and newest public-log preservation; back explicit deployed files and
   qualify the exact installed freeze. Active game must remain untouched.
2. Follow run10 request25106's visible10-dollar Blueprint versus4-dollar Buffoon:
   Yorickx1 and Perkeo empty disable useful_copy_target and focused protection.
   Establish a manufactured future-value acquisition route that still proves
   survival, rental reserve, perishable lifetime and opportunity cost. Do not infer
   optimality from price or eventual victory.447 contains no shop repair.
3. Four-discard rounds average14.6 versus16 target; ten clears leave31 discards.
   Group exact blockers in UNUSED_CLEAR_TRACE.json. Astronomer12438 and Photo16320
   motivate new visible coverage, but all-hidden7430 and Pair-restricted11998 are
   not resolved by eligibility alone. Acorn order-family cost and Psychic sorting
   need complete bounded proofs. Preserve12-call cap, resources and visibility.
4. Improve qualified evidence for ordering, nonclearing plays, consumables and
   open-pack transitions. Forty flags lack structural packets under the fixed128
   cap; all152 compact raw flags are retained. Suspect flags are not regret proof.
5. Independently check the two early losses, Invisible replacement, Burnt/Greedy
   pack and Death timing before changing their valuation. A full-game causal/win
   claim needs evidence beyond these descriptive joins and manufactured tests.

Historical experiment budgets and447 review are exhausted. No fresh experiment
authorization, optimal-strategy claim or population win-rate assertion is created.
''')
write(E/'ARCHITECTURE_MAP_447.md','''# Visible retained-discard proof447

Growth.visible_retained first rejects every supported hidden/unknown Joker alias.
Canonical Astronomer passes ordinary_additive_joker as an inert effect; canonical
Photograph passes only small_order_joker and is never classified as additive.
Ordinary ability/edition validation rejects modified or unknown coefficients.

Visible selected anchors are scored through the existing retained-family route.
Photograph depends on the first selected scoring face, so hidden held identities
cannot supply its bonus. Downstream complete scoring-card orders still bound the
adverse score, Glass use and resources. Known copy rows use the same exact scorer;
unknown copied identities are not inferred. Admission does not bypass these checks.

Candidate population, protected slots, hidden callback/reward resources, cash,
inventory and ordering guards remain. Growth uses at most12 calls; ordinary,
shop, consumable and actual fast-clear caps remain140000/50000/25000/70. Fresh
decisions after actual discard transitions are required. New tests check retained
finish before any replacement draw and hidden-assignment invariance.

Offline audit joins settled public actions from immutable446/install/captures/001.
It never calls policy/scorer on captured states. Round averages require qualified
closing joins or terminal loss; missing joins are not treated as unfinished runs.
The128-packet cap leaves40 flags without alternatives; ALL_FLAGS.json retains all
152 suspects. Raw sequence audits expose shop cases outside current packet coverage.
''')
diff=[]
for rel in F['changed_from_installed446']:
    diff.extend(difflib.unified_diff((H/'before'/rel).read_text().splitlines(True),(R/rel).read_text().splitlines(True),
      fromfile='installed446/'+rel,tofile='candidate447/'+rel))
write(H/'final_changes.diff',''.join(diff))
decisions=read(H/'analysis/decisions.json');offers=read(H/'analysis/copy_opportunities.json')
save(H/'BLUEPRINT_TRACE.json',{'scope':'Descriptive copied public records; no policy/scorer execution',
 'decisions':[d for d in decisions if d['sequence']in(25106,25116,25129)],
 'offer':[o for o in offers if o['run']==10 and o['card']['id']=='card:2741'],
 'source_gate':'strategy.lua useful_copy_target: Yorick x_mult>1 or Perkeo with consumables or supported compatible scoring target',
 'conclusion':'Focused acquisition/protection did not engage; survival-qualified future-value alternative remains open'})
prefix=f'''VALIDATED CANDIDATE447 /2.222.0-alpha —{stamp[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_447.md/.json, SESSION_RESET_447.md/.json,
NEXT_PRIORITIES_447.md, ARCHITECTURE_MAP_447.md and development447/REPORT.md,
REVIEW.md, METRICS.json, UNUSED_CLEAR_TRACE.json, BLUEPRINT_TRACE.json,
ALL_FLAGS.json and FINAL_VERIFICATION.json.326Lua/494Python;110runtime/379tests.
Digest {F['candidate_policy_digest']}.
Canonical Astronomer/Photograph visible retained-discard proof coverage; hidden
Joker aliases rejected; existing complete comparisons/resources/budgets preserved.
NOT INSTALLED:446/2.221 remains exact while live game runs. Full prior2.219 cohort
audited:7wins/2losses/1stall;175qualified rounds12.91cards average. Four-discard
cohort14.6vs16 target;10clears leave31discards. New Blueprint future-value lead open.
No all-fixed or population win-rate claim. Historical experiments/review447 CLOSED.
No captured executions or game control. INSTALLATION_POLICY.md governs release
after fresh passive absence/newest-log preservation. Earlier records are history.

'''
nav={}
for rel in P['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'):continue
    path=R/rel;old=path.read_bytes();assert file_digest(path)==P['before_files'][rel]
    path.write_bytes(prefix.encode('utf-8')+old);assert path.read_bytes().endswith(old);nav[rel]=file_digest(path)
paths=[E/(name+'_447'+ext)for name in ('CANDIDATE_CHECKPOINT','SESSION_RESET')for ext in('.json','.md')]
paths += [E/'NEXT_PRIORITIES_447.md',E/'ARCHITECTURE_MAP_447.md',C/'freeze.json',C/'validation/report.json',
 capture/'manifest.json',capture/'summary.json']
paths += [p for p in H.rglob('*')if p.is_file()and'before'not in p.relative_to(H).parts and'__pycache__'not in p.parts]
save(H/'FINAL_VERIFICATION.json',{'verified_utc':stamp,**checkpoint,'navigation_hashes':nav,
 'artifact_hashes':{p.relative_to(R).as_posix():file_digest(p)for p in paths}})
print(json.dumps({k:checkpoint[k]for k in ('candidate_version','candidate_policy_digest','lua_fixtures','python_tests',
 'installation_status','passive_processes','prior446_files_preserved')}))
