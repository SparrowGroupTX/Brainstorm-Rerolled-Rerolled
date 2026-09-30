"""Seal candidate or installed evidence without rewriting prior histories."""
from pathlib import Path
import sys,json,re,difflib
H=Path(__file__).resolve().parent;sys.path.insert(0,str(H/'install'))
from release import ROOT,EVAL,CANDIDATE,FINAL,exact,journals,read,save,now,processes
from benchmark import file_digest,policy_hashes
def write(p,s):
 with p.open('x',encoding='utf-8')as f:f.write(s)
def counts(folder):
 g=read(folder/'validation/report.json');assert all(g[k]for k in('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
 m=re.search(r'(\d+)/(\d+) fixtures passed',(folder/'validation/lua.log').read_text());assert m and m[1]==m[2]=='329'
 py=sum(int(re.search(r'Ran (\d+) tests',(folder/'validation'/n).read_text())[1])for n in('python.log','python_1.log','python_2.log'));assert py==494
 assert '3143 manufactured assertions passed'in(folder/'validation/lua.log').read_text()
 return {'lua_fixtures':329,'python_tests':494}
mode=sys.argv[1];assert mode in('candidate','installed');installed_mode=mode=='installed'
B,I,F,P=exact(installed_mode,sealed=installed_mode);capture,manifest,summary=journals(not installed_mode)
assert counts(CANDIDATE)=={'lua_fixtures':329,'python_tests':494}
assert summary['events']==26655 and summary['outcomes']=={'win':7,'loss':3}
assert len(summary['starts'])==len(summary['endings'])==10 and not summary['errors']and not summary['unended_run_ids']
assert len(manifest['segments'])==28 and sum(r['bytes']for r in manifest['segments'])==71649259
for name,h in read(H/'review/COMPLETE.json')['files'].items():assert file_digest(H/'review'/name)==h
digest=F['candidate_policy_digest'];status=processes();stamp=now()
checkpoint={'revision':450,'created_utc':stamp,'version':'2.225.0-alpha','candidate_version':'2.225.0-alpha',
 'candidate':str(CANDIDATE),'candidate_policy_digest':digest,'candidate_policy_files':F['candidate_policy_files'],
 'full_candidate_gate_passed':True,'validation_counts':counts(CANDIDATE),'lua_fixtures':329,'python_tests':494,
 'new_manufactured_assertions':3143,'baseline_checks':10,'runtime_files':110,'test_files':382,
 'installed_release':450 if installed_mode else 449,'installed_version':'2.225.0-alpha'if installed_mode else'2.224.0-alpha',
 'installed_unchanged':not installed_mode,'installation_performed':installed_mode,'passive_processes':status,
 'candidate1_qualified':True,'review_exhausted':True,'prior_files_preserved':len(P['prior_files']),
 'config_preserved':True,'native_files_preserved':7,'public_capture':capture.relative_to(ROOT).as_posix(),
 'public_events':26655,'public_outcomes':summary['outcomes'],'public_starts':10,'public_endings':10,
 'public_unended_runs':0,'public_archive_errors':[],'public_segments':28,'public_bytes':71649259,
 'loaded_version':'2.224.0-alpha','all_discard_cases_fixed':False,'activation':'Unconfirmed; awaits user-started loading',
 'captured_policy_executions':0,'game_control':False,'historical_experiments':'CLOSED','normal_exit_inferred':False}
backup=None
if installed_mode:
 assert counts(FINAL)==counts(CANDIDATE)
 g=read(FINAL/'validation/report.json');record=read(FINAL/'record.json');backup=Path(record['installation']['backup'])
 assert g['policy_files']==F['candidate_policy_files']==policy_hashes(FINAL/'policy')==record['policy_files']
 assert g['test_files']==F['test_files'] and g['validation_provenance']==F['validation_provenance']
 deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
 deployed={};changed=[]
 for row in deployment['files']:
  rel=row['path'].replace('\\','/')
  assert row['before']and file_digest(backup/rel)==row['before'].lower()==B['deployment_files'][rel]
  assert file_digest(I/rel)==row['after'].lower()==F['candidate_policy_files']['Brainstorm/'+rel]
  deployed[rel]=row['after'].lower()
  if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
 assert len(deployed)==94 and len(changed)==3 and set(changed)==set(F['changed_from_installed449'])
 checkpoint.update({'installed_at':record['installation']['installedAt'],'installed':str(I),'backup':str(backup),
  'policy_digest':digest,'policy_files':F['candidate_policy_files'],'deployment_files':deployed,
  'config_sha256':read(H/'install/preinstall_verification.json')['config_sha256'],'native_files_preserved':P['native_files'],
  'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,'changed_runtime_files':changed,
  'frozen_test_file_count':382,'candidate_validation':str(CANDIDATE/'validation/report.json'),
  'installed_validation':str(FINAL/'validation/report.json'),'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md')})
label='INSTALLED'if installed_mode else'CANDIDATE'
name=f'{label}_CHECKPOINT_450';reset='SESSION_RESET_450'+('_INSTALLED'if installed_mode else'')
priorities='NEXT_PRIORITIES_450'+('_INSTALLED'if installed_mode else'')
save(EVAL/(name+'.json'),checkpoint);save(EVAL/(reset+'.json'),checkpoint)
description=f'''# {label.title()}450 /2.225.0-alpha

{'Installed successfully; candidate and exact-installed gates both pass.'if installed_mode else'Candidate1 fully validated; installed449/2.224 remains unchanged.'}
329 Lua fixtures/494 Python tests,110 runtime dependencies/382 frozen test files.
Digest `{digest}`. Three runtime changes: held-Steel discard shortlist and versions.
{'94 paths backed/deployed; settings and seven DLLs preserved. Backup: '+str(backup)if installed_mode else'Installation remains a separate backed operation under INSTALLATION_POLICY.md.'}

Full loaded2.224 session copied:28 segments/71,649,259 bytes/26,655 events,
10 starts/10 endings,7 wins/3 losses, no unended runs/archive errors. Three-discard
rounds average11.8354/12; four-discard17.6667/16.15clears leave41discards. All seven
observed copy offers acquired. No all-fixed or population win-rate claim.

The new manufactured fixture checks3,143 assertions; separate normal-mode archived
comparison3149. Retained-Steel prefixes improve the selected complete-subset
examples without bypassing actual score/resource proofs or raising budgets.
Global maximality and loaded2.225 effectiveness remain unconfirmed.
See development450/REPORT.md, FINDINGS.json, TERMINAL_TOTALS.json, TRACE.json,
METRICS.json, UNUSED_CLEAR_TRACE.json, ALL_FLAGS.json and REVIEW.md.
Historical experiments and runtime review450 CLOSED; no captured execution/game control.
'''
write(EVAL/(name+'.md'),description);write(EVAL/(reset+'.md'),description+f'\nRead {priorities}.md and ARCHITECTURE_MAP_450.md. Later installed status supersedes candidate history.\n')
priority_text='''# Priorities450

1. Qualify the run5 Flint last-Uranus lead: terminal1,998/2,000, request12152
   kept an additional Uranus before a702-chip Two Pair. Test a manufactured
   multi-hand tactical inventory comparison including Perkeo opportunity cost,
   Flint rounding and remaining draws. No historical rescue has been executed.
2. Qualify canonical Juggler/Bootstraps order/visible-floor coverage: their
   public known effects appear in five unused-clear gaps. Keep strict fields,
   hidden identity, order, population and retained resource safeguards.
3. Review run4 survival/reserve pack opportunity11141 ($4 Buffoon with$5),
   and run6 early unscaled Yorick survival. Unseen pack contents cannot establish
   regret; use bounded supported comparisons with prospective acceptance.
4. Other limits remain: conditional held bonuses, Ancient/Idol order, final-boss
   condition changes and full Acorn retained families. Steel prioritization does
   not promise a global maximum and does not fix every recorded unused clear.
5. Establish loaded2.225 exposure passively in a later user-started session;
   preserve journals before release and inspect actual discard behavior.

Historical experiments and review450 are closed. No new simulation, captured
execution, automation or review budget is created. One new coherent slice needs
prospective scope. Installation policy uses fresh passive absence, not a closure
confirmation or normal-exit inference. Preserve tracked/untracked work and DLLs.
'''
write(EVAL/(priorities+'.md'),priority_text)
if not installed_mode:
 write(EVAL/'ARCHITECTURE_MAP_450.md','''# Held-Steel shortlist450

growth.suggest keeps original index/rank/suit candidate families and adds up to
five public canonical Steel-preserving prefixes only in win-first exhaust mode.
Known nondebuffed Steel counts one held activation, Red two. Equal-size choices
prefer fewer lost Steel activations, then existing merit/indices. Six shortlist
slots and12 scored evaluations remain. Larger batches may remove Steel when the
real retained score/resources still qualify; no unconditional Steel protection.

All actual transition, visibility/order, Glass, population, Blue/Gold and cash
guards remain unchanged. New candidates may displace old shortlist entries, so
this is not globally maximal search. Normal non-exhaust mode remains unchanged.
Manufactured finite-subset/refill and independent arithmetic tests establish the
selected repaired families. No captured execution or historical rescue.
''')
 diff=[]
 for rel in F['changed_from_installed449']:
  diff.extend(difflib.unified_diff((H/'before'/rel).read_text().splitlines(True),(ROOT/rel).read_text().splitlines(True),fromfile='installed449/'+rel,tofile='candidate450/'+rel))
 write(H/'final_changes.diff',''.join(diff))
prefix=f'''{label} REVISION450 /2.225.0-alpha —{stamp[:10]}
Read tools/advisor_eval/{name}.md/.json, {reset}.md/.json,
{priorities}.md, ARCHITECTURE_MAP_450.md and development450/REPORT.md,
FINDINGS.json, TERMINAL_TOTALS.json, TRACE.json, METRICS.json, REVIEW.md.
{'Candidate and exact-installed gates pass'if installed_mode else'Candidate1 passes'}329Lua/494Python;110runtime/382tests.
Digest {digest}. Held-Steel-preserving discard shortlist; full proof/budgets unchanged.
{'Installed; settings/DLLs preserved; activation unconfirmed.'if installed_mode else'Installed449/2.224 remains unchanged pending separate release.'}
Full loaded2.224 session preserved:26,655events,10starts/10ends,7wins/3losses;
0unended/0errors. Three-discard benchmark unmet;15clears leave41. All7copyoffers
acquired. Strong next lead: last Uranus retained before run5 final Two Pair;
terminal1,998/2,000. No all-fixed, historical-rescue or population win-rate claim.
Historical experiments/review450 CLOSED. No game control/captured execution.
Earlier records follow as preserved history.

'''
nav={};backups={}
for rel in P['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;old=p.read_bytes()
 if installed_mode:
  assert file_digest(p)==read(H/'FINAL_VERIFICATION.json')['navigation_hashes'][rel]
  dest=H/'install/navigation_before_install'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
  with dest.open('xb')as f:f.write(old)
  backups[rel]=file_digest(dest)
 else:assert file_digest(p)==P['before_files'][rel]
 p.write_bytes(prefix.encode('utf-8')+old);nav[rel]=file_digest(p);assert p.read_bytes().endswith(old)
paths=[EVAL/(x+ext)for x in(name,reset)for ext in('.json','.md')]+[EVAL/(priorities+'.md'),EVAL/'ARCHITECTURE_MAP_450.md',CANDIDATE/'freeze.json',CANDIDATE/'validation/report.json']
if installed_mode:
 paths += [FINAL/'record.json',FINAL/'validation/report.json',H/'FINAL_VERIFICATION.json',H/'install/preinstall_verification.json',H/'install/installation.log']
 dest=H/'install/INSTALLED_VERIFICATION.json'
else:
 paths += [p for p in H.rglob('*')if p.is_file()and'before'not in p.relative_to(H).parts and'__pycache__'not in p.parts]
 dest=H/'FINAL_VERIFICATION.json'
save(dest,{**checkpoint,'navigation_hashes':nav,'navigation_backups':backups,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}})
exact(installed_mode)
print(json.dumps({'mode':mode,'version':'2.225.0-alpha','digest':digest,'counts':counts(CANDIDATE),
 'public_events':26655,'outcomes':summary['outcomes'],'backup':str(backup)if backup else None,'passive_processes':status}))
