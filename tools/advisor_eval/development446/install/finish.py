"""Seal installed qualification without rewriting closed candidate evidence."""
from pathlib import Path
import json,re
from release import HERE,EVAL,ROOT,CANDIDATE,FINAL,exact,journals,read,save,now,processes
from benchmark import file_digest,policy_hashes
def write(p,s):
    with Path(p).open('x',encoding='utf-8')as f:f.write(s)
def counts(folder):
    g=read(folder/'validation/report.json')
    assert all(g[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
    m=re.search(r'(\d+)/(\d+) fixtures passed',(folder/'validation/lua.log').read_text())
    assert m and m[1]==m[2]=='325'
    p=sum(int(re.search(r'Ran (\d+) tests',(folder/'validation'/n).read_text())[1])for n in ('python.log','python_1.log','python_2.log'))
    assert p==494;return {'lua_fixtures':325,'python_tests':494}
base,installed,freeze,pre=exact(True)
capture,manifest,summary=journals(False);record=read(FINAL/'record.json');backup=Path(record['installation']['backup'])
assert counts(CANDIDATE)==counts(FINAL)
for folder in (CANDIDATE,FINAL):
    gate=read(folder/'validation/report.json')
    assert gate['policy_files']==freeze['candidate_policy_files']
    assert gate['test_files']==freeze['test_files']
    assert gate['validation_provenance']==freeze['validation_provenance']
assert policy_hashes(FINAL/'policy')==freeze['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
deployed={};changed=[]
for row in deployment['files']:
    rel=row['path'].replace('\\','/')
    assert row['before']and file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel]
    assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
    deployed[rel]=row['after'].lower()
    if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and set(changed)==set(freeze['changed_from_installed444'])and len(changed)==8
assert len(summary['starts'])==len(summary['endings'])==10 and not summary['errors']and not summary['unended_run_ids']
assert summary['events']==28200 and summary['outcomes']=={'win':7,'loss':2,'abandoned_stall':1}
digest=freeze['candidate_policy_digest'];config=read(HERE/'preinstall_verification.json')['config_sha256']
current=processes();public_bytes=sum(r['bytes']for r in manifest['segments'])
checkpoint={'version':'2.221.0-alpha','revision':446,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':config,'native_files_preserved':pre['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,
 'changed_runtime_files':sorted(changed),'frozen_test_file_count':378,'validation_counts':counts(FINAL),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; awaits user-started loading','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True,'prior_preserved_hashes':len(pre['prior_files']),
 'latest_public_session':summary['session'],'latest_public_loaded_labels':list(summary['versions']),
 'latest_public_capture':capture.relative_to(ROOT).as_posix(),'latest_public_capture_last_sequence':summary['events'],
 'latest_public_recorded_starts':10,'latest_public_recorded_outcomes':summary['outcomes'],
 'latest_public_unended_runs':0,'latest_public_capture_errors':[],
 'latest_public_manifest_sha256':file_digest(capture/'manifest.json'),'historical_experiments':'CLOSED',
 'new_experiment_or_replay':False,'candidate2_qualified':True}
save(EVAL/'INSTALLED_CHECKPOINT_446.json',checkpoint)
save(EVAL/'SESSION_RESET_446_INSTALLED.json',checkpoint)
report=f'''# Installed446 /2.221.0-alpha

Installed successfully. Candidate and exact-installed full gates both pass
**325 Lua fixtures and494 Python tests**.110 runtime dependencies/378 frozen test
files; digest `{digest}`. Eight runtime files changed;94 files backed and deployed.
Settings and all seven DLLs remain unchanged. Backup: `{backup}`.

The combined update includes445 Acorn hand-size/canonical identity continuity,
446 Burnt/Yorick shared-budget stall repair and consistent vacant-slot copy
funding. No runtime changes were made during installation. Candidate1 remains
unqualified history; candidate2 is the installed freeze. Remaining unused-discard
cases are not claimed fixed. Activation/effectiveness awaits the next user launch.

The complete latest loaded2.219 session is safely preserved at
`{capture.relative_to(ROOT).as_posix()}`: {len(manifest['segments'])} segments,
{public_bytes} bytes,28,200 verified events,10 starts/10 endings: **7 wins,2 losses,
1 abandoned stall**. No unended runs or archive errors. Copy/source hashes matched
before and after deployment. The prior13,111-event analysis cutoff remains intact;
its metrics do not describe the whole marathon. These outcomes predate2.221 and
are not a population win-rate claim.

Passive successful absence checks authorized installation; no normal-exit inference
or game control. All prior candidate/analysis artifacts, tracked/untracked work,
settings and DLLs are preserved. Exact final evidence:
development446/install/INSTALLED_VERIFICATION.json and runs/repair446_installed.
Historical experiments and runtime review446 remain CLOSED.
'''
write(EVAL/'INSTALLED_CHECKPOINT_446.md',report)
write(EVAL/'SESSION_RESET_446_INSTALLED.md','''# Installed resume446

2.221.0-alpha is installed. Read INSTALLED_CHECKPOINT_446.md/.json and
development446/install/INSTALLED_VERIFICATION.json. Both exact gates pass
325Lua/494Python,110 dependencies/378 frozen tests. Candidate2 is installed.
Closed candidate446/SESSION_RESET_446 records remain unchanged as history.

Full loaded2.219 marathon is preserved in development446/install/captures/001:
28,200events,10starts/10ends,7wins/2losses/1abandoned_stall. No unended runs or
archive errors. Previous446 report analyzed only13,111events; later runs have not
received that deeper analysis. Do not extrapolate its partial metrics.

Activation/effectiveness awaits a user-started load. Preserve logs and check version
passively; never control Balatro or infer normal exit. Installation policy permits
fresh passive absence without confirmation. Keep saves/profiles, runtime execution,
preservation and frozen qualification boundaries. All historical experiment budgets
and runtime review446 remain CLOSED. See NEXT_PRIORITIES_446_INSTALLED.md.
''')
write(EVAL/'NEXT_PRIORITIES_446_INSTALLED.md','''# Installed priorities446

1. Establish loaded2.221 passively in the next user-started session. Check actual
   first-discard progress where Burnt copying previously caused reorder stalls;
   lack of exposure is not evidence of effectiveness.
2. On user authorization for analysis, review the complete preserved2.219 marathon,
   including its later five runs. The prior44613,111-event report remains a partial
   cutoff, not the completed-session analysis.
3. Continue the specific unresolved discarded-card proof gaps in
   NEXT_PRIORITIES_446.md and the offline settlement coverage gaps. Preserve all
   legality/resource proofs and demonstrate alternatives before strategy changes.

No experiment authorization or runtime-review renewal is created by this list.
New runtime repairs require prospective scope and exact combined qualification.
''')
prefix=f'''INSTALLED REVISION446 /2.221.0-alpha —{now()[:10]}
Read tools/advisor_eval/INSTALLED_CHECKPOINT_446.md/.json,
SESSION_RESET_446_INSTALLED.md/.json, NEXT_PRIORITIES_446_INSTALLED.md,
ARCHITECTURE_MAP_446.md and development446/install/INSTALLED_VERIFICATION.json.
Candidate2 and exact-installed full gates:325Lua/494Python;110runtime/378tests.
Digest {digest}.
Eight runtime changes;94backed/deployed files; settings/seven DLLs preserved.
Full loaded2.219 marathon copied to development446/install/captures/001:
28,200events,10starts/10ends,7wins/2losses/1abandoned_stall;0unended/0archiveerrors.
Prior446 analysis covers only13,111events. Loaded2.221 efficacy unconfirmed;
no all-fixed or population win-rate claim. No game control or reopened experiments.
Runtime review446 remains CLOSED. Earlier candidate/install records are history.

'''
navigation={}
for rel in pre['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'):continue
    path=ROOT/rel;old=path.read_bytes();dest=HERE/'navigation_before_install'/rel
    dest.parent.mkdir(parents=True,exist_ok=True)
    with dest.open('xb')as f:f.write(old)
    navigation[rel]=file_digest(dest);path.write_bytes(prefix.encode('utf-8')+old)
    assert path.read_bytes().endswith(old)
paths=[EVAL/'INSTALLED_CHECKPOINT_446.json',EVAL/'INSTALLED_CHECKPOINT_446.md',
 EVAL/'SESSION_RESET_446_INSTALLED.json',EVAL/'SESSION_RESET_446_INSTALLED.md',EVAL/'NEXT_PRIORITIES_446_INSTALLED.md',
 HERE/'preinstall_verification.json',HERE/'installation.log',CANDIDATE/'freeze.json',
 CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json',
 capture/'manifest.json',capture/'summary.json',HERE.parent/'FINAL_VERIFICATION.json',HERE/'ARCHIVE_REVIEW.md']
save(HERE/'INSTALLED_VERIFICATION.json',{'verified_utc':now(),'version':'2.221.0-alpha','digest':digest,
 'counts':counts(FINAL),'candidate_and_installed_gates_passed':True,'installed_runtime_exact':True,
 'config_preserved':True,'native_files_preserved':7,'deployed_paths':94,'backed_existing_paths':94,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':len(manifest['segments']),'public_bytes_preserved':public_bytes,
 'public_capture':str(capture),'public_outcomes':summary['outcomes'],'public_events':summary['events'],
 'normal_exit_inferred':False,'activation_confirmed':False,'passive_processes':current,
 'backup':str(backup),'navigation_backups':navigation,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}})
print(json.dumps({'version':'2.221.0-alpha','counts':counts(FINAL),'public_events':summary['events'],
 'outcomes':summary['outcomes'],'backup':str(backup),'passive_processes':current}))
