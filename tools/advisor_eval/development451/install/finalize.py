"""Record installed451 only after the exact-installed full gate succeeds."""
from pathlib import Path
import json,re
from release import ROOT,EVAL,CANDIDATE,FINAL,HERE,read,save,now,processes,exact,journals
from benchmark import file_digest,policy_hashes
def write(path,text):
    with path.open('x',encoding='utf-8')as f:f.write(text)
def counts(folder):
    gate=read(folder/'validation/report.json')
    assert all(gate[k]for k in('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
    assert re.search(r'330/330 fixtures passed',(folder/'validation/lua.log').read_text(encoding='utf-8'))
    n=sum(int(re.search(r'Ran (\d+) tests',(folder/'validation'/s).read_text())[1])for s in('python.log','python_1.log','python_2.log'))
    assert n==494
    return {'lua_fixtures':330,'python_tests':494}
B,I,F,P=exact(True);assert counts(CANDIDATE)==counts(FINAL)
G=read(FINAL/'validation/report.json');record=read(FINAL/'record.json')
assert G['policy_files']==F['candidate_policy_files']==policy_hashes(FINAL/'policy')==record['policy_files']
assert G['test_files']==F['test_files']and G['validation_provenance']==F['validation_provenance']
capture,manifest,summary=journals(False)
assert not manifest['processes_before']and not manifest['processes_after']
assert summary['events']==23010 and summary['outcomes']=={'win':5,'loss':2}
assert len(summary['starts'])==8 and len(summary['endings'])==7 and len(summary['unended_run_ids'])==1
assert not summary['errors']
backup=Path(record['installation']['backup'])
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
deployed={};changed=[]
for row in deployment['files']:
    rel=row['path'].replace('\\','/')
    assert row['before']and file_digest(backup/rel)==row['before'].lower()==B['deployment_files'][rel]
    assert file_digest(I/rel)==row['after'].lower()==F['candidate_policy_files']['Brainstorm/'+rel]
    deployed[rel]=row['after'].lower()
    if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and set(changed)==set(F['changed_from_installed450'])and len(changed)==3
pre=read(HERE/'preinstall_verification.json');stamp=now();ps=processes()
K={'revision':451,'created_utc':stamp,'version':'2.226.0-alpha','installed_at':record['installation']['installedAt'],
 'installed':str(I),'backup':str(backup),'candidate':str(CANDIDATE),'candidate_version':'2.226.0-alpha',
 'policy_digest':F['candidate_policy_digest'],'policy_files':F['candidate_policy_files'],
 'candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':P['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,'changed_runtime_files':changed,
 'frozen_test_file_count':383,'full_candidate_gate_passed':True,'full_installed_gate_passed':True,
 'validation_counts':counts(FINAL),'lua_fixtures':330,'python_tests':494,'new_manufactured_assertions':307,'baseline_checks':3,
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'review_exhausted':True,
 'candidate1_qualified':True,'installation_performed':True,'config_preserved':True,'prior_files_preserved':len(P['prior_files']),
 'public_capture':capture.relative_to(ROOT).as_posix(),'public_events':23010,'public_starts':8,'public_endings':7,
 'public_outcomes':summary['outcomes'],'public_unended_runs':1,'public_archive_errors':[],
 'public_segments':len(manifest['segments']),'public_bytes':sum(r['bytes']for r in manifest['segments']),
 'previous_loaded_version':'2.225.0-alpha','activation':'Unconfirmed; awaits user-started loading',
 'passive_processes':ps,'normal_exit_inferred':False,'game_control':False,'captured_policy_executions':0,
 'historical_experiments':'CLOSED','all_discard_cases_fixed':False}
for name in('INSTALLED_CHECKPOINT_451','SESSION_RESET_451_INSTALLED'):save(EVAL/(name+'.json'),K)
description=f'''# Installed451 /2.226.0-alpha

Installed the unchanged qualified candidate. Candidate and exact-installed full
gates pass330 Lua fixtures/494 Python tests.110 runtime dependencies/383 frozen
test files. Digest `{K['policy_digest']}`.94 existing paths backed/deployed;
three runtime differences: two_hand_finish.lua and version markers. Current
configuration and all seven DLLs preserved. Backup: `{backup}`.

No-discard two-hand last-Planet comparison now includes actual owned use,
Perkeo/Observatory opportunity cost, matched incumbent first play, stronger hold
alternative and complete bounded paired continuations.307 new manufactured
assertions,3 baseline checks; no global optimality or historical rescue claim.

Latest loaded2.225 journals safely preserved under {K['public_capture']}:
{K['public_segments']} segments/{K['public_bytes']:,} bytes,23,010 verified events,
eight starts/seven endings (five wins,two losses),one run without a terminal.
Zero archive errors. This is not a completed ten-run session. Passive absence
permitted deployment; no normal exit or missing run outcome was inferred.

2.226 activation is unconfirmed until a user-started load; no game was controlled.
Candidate histories, prior captures and all work preserved. See
development451/REPORT.md, REVIEW.md, install/INSTALLED_VERIFICATION.json,
NEXT_PRIORITIES_451_INSTALLED.md and ARCHITECTURE_MAP_451.md. Other unused-discard
issues remain; no all-fixed or loaded-game improvement/win-rate claim.
Historical experiments/review451 CLOSED; stop after this installation.
'''
for name in('INSTALLED_CHECKPOINT_451','SESSION_RESET_451_INSTALLED'):write(EVAL/(name+'.md'),description)
write(EVAL/'NEXT_PRIORITIES_451_INSTALLED.md','''# Priorities after installing451

1. Installed2.226 matches the frozen candidate and passes its exact-installed
   gate. Establish activation only from later user-started public observations.
2. Freshly preserved loaded2.225 journal: development451/install/captures/001,
   23,010 events,eight starts/seven endings,five wins/two losses/one unended run.
   Analyze it in a later authorized slice; do not assume the final run completed.
3. Qualify Juggler/Bootstraps ordering and visible-floor gaps from450's unused
   clears. Keep strict identity, scoring, order, population and resource proofs.
4. Review early survival/reserve purchases, conditional held bonuses,
   Ancient/Idol, changing final bosses and large Acorn families. Whole-inventory
   multi-action planning remains incomplete;451 covers only its declared bounded
   two-hand/no-discard Planet family. No global optimum or historical rescue.

Historical experiments and review451 are CLOSED. No game control, captured
policy/scorer execution, new simulation campaign, automation or extra review.
Preserve all work/journals/settings/DLLs. One prospective coherent slice, then stop.
''')
prefix=f'''INSTALLED REVISION451 /2.226.0-alpha —{stamp[:10]}
Read tools/advisor_eval/INSTALLED_CHECKPOINT_451.md/.json,
SESSION_RESET_451_INSTALLED.md/.json, NEXT_PRIORITIES_451_INSTALLED.md,
ARCHITECTURE_MAP_451.md and development451/install/INSTALLED_VERIFICATION.json.
Candidate and exact-installed gates pass330Lua/494Python;110runtime/383tests.
Digest {K['policy_digest']};94 paths backed/deployed,settings/sevenDLLs preserved.
No-discard two-hand Planet survival comparison; Perkeo/Observatory costs and
complete paired worlds,unchanged budgets.307 manufactured assertions.
Latest loaded2.225 session copied:23,010events,8starts/7endings,5wins/2losses,
1unended run,0archiveerrors. No missing outcome or normal exit inferred.
2.226 installed; activation awaits user-started loading. No game control.
Other discard issues remain; no win-rate improvement or all-fixed claim.
Historical experiments/review451 CLOSED. Earlier records are preserved history.

'''
nav={};nav_before={};V=read(HERE.parent/'FINAL_VERIFICATION.json')
for rel,h in V['navigation_hashes'].items():
    p=ROOT/rel;assert file_digest(p)==h
    old=p.read_bytes();dest=HERE/'navigation_before_install'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
    with dest.open('xb')as f:f.write(old)
    assert file_digest(dest)==h;nav_before[rel]=h
    p.write_bytes(prefix.encode('utf-8')+old);assert p.read_bytes().endswith(old);nav[rel]=file_digest(p)
paths=[p for p in HERE.rglob('*')if p.is_file()and'__pycache__'not in p.parts]
paths += [EVAL/(n+ext)for n in('INSTALLED_CHECKPOINT_451','SESSION_RESET_451_INSTALLED')for ext in('.md','.json')]
paths += [EVAL/'NEXT_PRIORITIES_451_INSTALLED.md',FINAL/'record.json',HERE.parent/'FINAL_VERIFICATION.json']
paths += list((FINAL/'validation').glob('*'))
save(HERE/'INSTALLED_VERIFICATION.json',{**K,'navigation_hashes':nav,'navigation_before_install':nav_before,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}})
exact(True)
for rel,h in read(HERE/'INSTALLED_VERIFICATION.json')['artifact_hashes'].items():assert file_digest(ROOT/rel)==h,rel
print(json.dumps({k:K[k]for k in('version','policy_digest','validation_counts','backup','public_segments','public_bytes',
    'public_starts','public_endings','public_outcomes','public_unended_runs','passive_processes')}))
