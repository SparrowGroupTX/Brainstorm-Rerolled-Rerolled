from pathlib import Path
import sys,json,re,difflib
H=Path(__file__).resolve().parent;sys.path.insert(0,str(H/'install'))
from release import ROOT,EVAL,CANDIDATE,exact,journals,read,save,now,processes
from benchmark import file_digest
from validate_checkpoint import test_manifest,provenance
def write(p,s):
 with p.open('x',encoding='utf-8')as f:f.write(s)
B,I,F,P=exact(sealed=False);capture,manifest,summary=journals(True)
for rel,h in read(H/'unqualified_candidate1.json')['files'].items():assert file_digest(ROOT/rel)==h
assert len(summary['starts'])==len(summary['endings'])==10 and not summary['errors']and not summary['unended_run_ids']
assert summary['events']==33136 and summary['outcomes']=={'win':8,'loss':2}
gate=read(CANDIDATE/'validation/report.json')
match=re.search(r'(\d+)/(\d+) fixtures passed',(CANDIDATE/'validation/lua.log').read_text());assert match and match[1]==match[2]=='328'
py=sum(int(re.search(r'Ran (\d+) tests',(CANDIDATE/'validation'/n).read_text())[1])for n in('python.log','python_1.log','python_2.log'));assert py==494
assert '23712 manufactured assertions passed'in(CANDIDATE/'validation/lua.log').read_text()
for name,digest in read(H/'review/COMPLETE.json')['files'].items():assert file_digest(H/'review'/name)==digest
metrics=read(H/'METRICS.json');status=processes();stamp=now()
checkpoint={'revision':449,'created_utc':stamp,'candidate_version':'2.224.0-alpha','candidate':str(CANDIDATE),
 'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],
 'full_candidate_gate_passed':True,'lua_fixtures':328,'python_tests':494,'new_manufactured_assertions':23712,
 'baseline_checks':6,'runtime_files':110,'test_files':381,'installed_release':446,'installed_version':'2.221.0-alpha',
 'installed_unchanged':True,'installation_performed':False,'passive_processes':status,
 'candidate1_qualified':False,'candidate2_qualified':True,'review_exhausted':True,
 'reviewer_visibility_correction':'Applied and primary-tested; no further reviewer inspection',
 'prior_files_preserved':len(P['prior_files']),'config_preserved':True,'native_files_preserved':7,
 'public_capture':capture.relative_to(ROOT).as_posix(),'public_events':33136,'public_outcomes':summary['outcomes'],
 'public_starts':10,'public_endings':10,'public_unended_runs':0,'public_archive_errors':[],
 'public_segments':30,'public_bytes':88237163,'loaded_version':'2.221.0-alpha',
 'discard_metrics':{k:v for k,v in metrics.items()if k not in('rounds','excluded_without_closing_join','zero_discard_rounds')},
 'all_discard_cases_fixed':False,'loaded_2224_efficacy':'Unconfirmed','captured_policy_executions':0,
 'game_control':False,'historical_experiments':'CLOSED'}
save(EVAL/'CANDIDATE_CHECKPOINT_449.json',checkpoint);save(EVAL/'SESSION_RESET_449.json',checkpoint)
report=f'''# Candidate449 / 2.224.0-alpha

Corrected candidate2 passes328 Lua fixtures/494 Python tests;110 runtime files,
381 frozen test files. Digest `{F['candidate_policy_digest']}`.
Candidate1 remains unqualified history. New manufactured fixture23,712 assertions.

Extends the strict product-order floor to public canonical Idol factor2 while
retaining all budget/order/visibility/resource safeguards. Includes pending447
Astronomer/Photograph and448 expired Riff-raff shop repairs. Installed446/2.221
is unchanged at this candidate checkpoint; deployment is separately recorded.

The complete loaded2.221 ten-run archive is safely copied in development449/
captures/001:33,136 events,8wins/2losses, no unended runs or errors.201 qualified
positive-discard rounds average11.94 cards; three-discard11.51vs12 and four-discard
15.62vs16. Twenty clears leave47 discards. No all-fixed or population win-rate claim.
See development449/REPORT.md, METRICS.json, UNUSED_CLEAR_TRACE.json, ALL_FLAGS.json,
REVIEW.md, FINAL_VERIFICATION.json. Historical experiments and449 review CLOSED.
INSTALLATION_POLICY.md governs release; no new closure confirmation required.
'''
write(EVAL/'CANDIDATE_CHECKPOINT_449.md',report)
write(EVAL/'SESSION_RESET_449.md',report+'\nRead NEXT_PRIORITIES_449.md and ARCHITECTURE_MAP_449.md. Later installed records supersede this candidate status.\n')
write(EVAL/'NEXT_PRIORITIES_449.md','''# Priorities449

1. Deploy exact candidate2 /2.224 after passive absence and latest public-log
   preservation, then full installed qualification. Candidate1 is unqualified.
2. Establish loaded2.224 exposure in later user-started journals. New product proof
   is only for known canonical Idol multiplication. It is not a blanket remedy
   for all20 historical unused clears or either failed discard benchmark.
3. Investigate required-Steel spare ordering: the unchanged shortlist can miss
   the largest safe partial discard. Prove complete bounded alternatives while
   retaining the actual Steel/Blue/Gold assets and12-call ceiling.
4. Other gaps: Castle/hidden Idol held floors; conditional Blackboard; changing
   final-boss finishing conditions; Chad and mixed +Mult/fractional card order.
   Do not drop guards to force discards. Full trace is in UNUSED_CLEAR_TRACE.json.
5. Unsupported full-row replacement screening, Invisible future duplication and
   early Yorickx1 copy acquisition remain open. Use declared survival/reserve/
   horizon comparisons; raw outcome or heuristic merit is not strategic regret.

Historical experiments and449 review are closed. No captured-execution/simulation
budget or automation is created. A new slice needs prospective scope.
''')
write(EVAL/'ARCHITECTURE_MAP_449.md','''# Idol product certificate449

public_product_idol adds a strictly known canonical Idol to product_order_safe.
Every contributing Joker and public hand/deck identity is qualified. Deck backs
are allowed; hidden identity is not. Fixed target rank/suit and factor2 permit
algebraic permutation equivalence with Glass. Independent per-card retriggers
and chips preserve this equivalence; +Mult/fractional card effects/Chad remain
outside scope. Fixed Joker/held stages keep existing independent qualifications.

drawn_hazard skips only Idol's trigger-order refusal after product certification.
accept still applies real after_discard score, Glass, Arm, cash, inventory and
population checks. No candidate, hidden-anchor, Acorn or12-call expansion.
Manufactured exhaustive orders/refills and fresh physical transitions validate
this family. Original module refuses. Combined release retains447 and448 fixes.
''')
diff=[]
for rel in ('Brainstorm/Advisor/growth.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua'):
 diff.extend(difflib.unified_diff((H/'before'/rel).read_text().splitlines(True),(ROOT/rel).read_text().splitlines(True),fromfile='candidate448/'+rel,tofile='candidate449/'+rel))
write(H/'final_changes.diff',''.join(diff))
prefix=f'''VALIDATED CANDIDATE449 /2.224.0-alpha —{stamp[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_449.md/.json, SESSION_RESET_449.md/.json,
NEXT_PRIORITIES_449.md, ARCHITECTURE_MAP_449.md and development449/REPORT.md,
METRICS.json, UNUSED_CLEAR_TRACE.json, ALL_FLAGS.json, REVIEW.md, FINAL_VERIFICATION.json.
Candidate2:328Lua/494Python;110runtime/381tests; digest {F['candidate_policy_digest']}.
Public canonical Idol product proof, including447/448 pending fixes. Installed446/
2.221 unchanged at candidate seal. Complete2.221 marathon preserved:33,136events,
8wins/2losses,0unended/0errors. Both discard benchmarks unmet;20clears leave47.
No all-fixed/win-rate claim.449review/historical experiments CLOSED. No captured
execution/game control. Installation follows INSTALLATION_POLICY.md. History follows.

'''
nav={}
for rel in P['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;old=p.read_bytes();assert file_digest(p)==P['before_files'][rel]
 p.write_bytes(prefix.encode('utf-8')+old);nav[rel]=file_digest(p)
paths=[EVAL/(name+'_449'+ext)for name in('CANDIDATE_CHECKPOINT','SESSION_RESET')for ext in('.json','.md')]
paths += [EVAL/'NEXT_PRIORITIES_449.md',EVAL/'ARCHITECTURE_MAP_449.md',CANDIDATE/'freeze.json',CANDIDATE/'validation/report.json']
paths += [p for p in H.rglob('*')if p.is_file()and'before'not in p.relative_to(H).parts and'__pycache__'not in p.parts]
save(H/'FINAL_VERIFICATION.json',{**checkpoint,'navigation_hashes':nav,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}})
print(json.dumps({'candidate':'2.224.0-alpha','digest':F['candidate_policy_digest'],'lua':328,'python':494,'processes':status}))
