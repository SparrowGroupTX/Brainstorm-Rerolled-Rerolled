"""Verify both exact431 gates, complete backups and preserved release evidence."""
import json,re,subprocess
from pathlib import Path
from release import HERE,EVAL,ROOT,CANDIDATE,FINAL,exact,journals,save,now,processes,read
from benchmark import file_digest,policy_hashes
def write(p,s):
 with Path(p).open('x',encoding='utf-8')as f:f.write(s)
base,installed,freeze,pre=exact(True);capture,manifest,summary=journals(False)
record=read(FINAL/'record.json');backup=Path(record['installation']['backup']);current=processes()
counts=[]
for folder in (CANDIDATE,FINAL):
 gate=read(folder/'validation/report.json')
 assert all(gate[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
 assert gate['policy_files']==freeze['candidate_policy_files']and gate['test_files']==freeze['test_files']
 assert gate['validation_provenance']==freeze['validation_provenance']
 m=re.search(r'(\d+)/(\d+) fixtures passed',(folder/'validation/lua.log').read_text());assert m and m[1]==m[2]
 py=sum(int(re.search(r'Ran (\d+) tests',(folder/'validation'/n).read_text())[1])for n in ('python.log','python_1.log','python_2.log'))
 counts.append({'lua_fixtures':int(m[1]),'python_tests':py})
assert counts==[{'lua_fixtures':302,'python_tests':458}]*2
assert policy_hashes(FINAL/'policy')==freeze['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'));deployed={};changed=[];backed=0
for row in deployment['files']:
 rel=row['path'].replace('\\','/')
 assert row['before'],'No new deployed paths expected'
 assert file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel];backed+=1
 assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
 deployed[rel]=row['after'].lower()
 if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and backed==94 and set(changed)==set(freeze['changed_runtime_files'])
digest=freeze['candidate_policy_digest'];public_bytes=sum(r['bytes']for r in manifest['segments'])
checkpoint={'version':'2.212.0-alpha','revision':431,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':351,'new_fixture_assertions':387,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True,'prior_preserved_hashes':len(pre['prior_files']),
 'latest_public_loaded_label':'2.209.0-alpha','latest_public_session':summary['session'],
 'latest_public_capture':capture.relative_to(ROOT).as_posix(),'latest_public_capture_last_sequence':summary['events'],
 'latest_public_recorded_starts':len(summary['starts']),'latest_public_recorded_outcomes':summary['outcomes'],
 'latest_public_unended_runs':len(summary['unended_run_ids']),
 'latest_public_manifest_sha256':file_digest(capture/'manifest.json'),
 'captured_policy_replay431':False,'historical_experiments':'CLOSED'}
save(EVAL/'SESSION_RESET_431.json',checkpoint)
report=f'''# Installed431 —2.212.0-alpha

The validated combined discard and Amber Acorn repair is installed. Candidate
and exact-installed gates both pass **302 Lua fixtures /458 Python tests**.
Digest `{digest}`;110 runtime dependencies,351 frozen test files. Six changed
runtime files,94 deployed/94 backed paths. Settings and all seven DLLs unchanged.
Backup: `{backup}`. Installation is not loaded2.212 activation evidence.

Includes428 enhanced-small-anchor discard proofs,430 public Smiley Face/Supernova
Amber Acorn continuity, and431 draw-independent Raised Fist/Blackboard omission
floors. The new387-check manufactured fixture demonstrates repeated full-five
discards before optional Tarot, copies/real growth/adverse draws/order, and
rejection of genuinely bonus-dependent or unsupported finishes. See REPORT.md,
REVIEW.md, PASSIVE_REASONS.json and development430/TRACE.json. Other discard proof
gaps remain; no all-fixed or improved population win-rate claim.

Latest completed user session remains safely preserved at
`{capture.relative_to(ROOT).as_posix()}`: {len(manifest['segments'])} segments,
{public_bytes:,} bytes,30,608 verified events;6 wins,2 losses,2 unsupported
retirements, no unended run IDs or verification errors. These are loaded2.209
outcomes. Original public journals matched the preserved copy before/after
deployment and were never edited or cleared. Unsupported is not a terminal loss.

A fresh successful passive check found Balatro absent, authorizing deployment
under the user's standing instruction. No normal exit inferred, game controlled,
saves/profiles accessed, original source executed, or new captured evaluation
performed. All{len(pre['prior_files'])} historical hashes and{len(pre['before_files'])}
before-work backups are intact.431 review and all historical experiments closed.
'''
write(EVAL/'SESSION_RESET_431.md',report);write(HERE/'INSTALLED_REPORT.md',report)
prefix=f'''INSTALLED REVISION431 —2026-09-27
2.212.0-alpha installed. Read tools/advisor_eval/SESSION_RESET_431.md/.json,
NEXT_PRIORITIES_431.md, ARCHITECTURE_MAP_431.md and development431/INSTALLED_REPORT.md,
INSTALLED_VERIFICATION.json. Digest {digest}.
Candidate and exact-installed gates:302 Lua/458 Python;110 dependencies/351 tests.
Six changed runtime files;94 deployed/94 backed. Settings/seven DLLs preserved.
Combined428+430+431: enhanced small-anchor discard floors, both Smiley/Supernova
Amber Acorn continuity causes, canonical Raised Fist/Blackboard omission floors.
387 new manufactured checks. Loaded2.212 activation/effectiveness unconfirmed.
Other unused-discard proof gaps remain; no all-fixed or population win-rate claim.
Latest loaded2.209 ten-run archive: development430/captures/002;30,608 verified
events,6wins/2losses/2unsupported,no unended runs. Original journals untouched.
Closed429 counterfactual results belong to2.209/2.210, not this installed build.
No process control, saves/profiles, captured replay, original execution,
experiment or automation.431 review exhausted; historical budgets CLOSED.
Fresh process absence authorized installation; no confirmation or normal-exit inference.
Release complete. Earlier candidate/history records follow for provenance.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;prior=p.read_bytes();back=HERE/'navigation_before_install'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb')as f:f.write(prior)
 p.write_bytes(prefix.encode()+prior);assert p.read_bytes().endswith(prior)
for name in ('NEXT_PRIORITIES_431.md','ARCHITECTURE_MAP_431.md'):
 p=EVAL/name;prior=p.read_bytes();write(HERE/('candidate_'+name),prior.decode())
 p.write_bytes(b'Installed431/2.212: release complete. Read SESSION_RESET_431 and development431/INSTALLED_VERIFICATION.json.\nNext: actual user-loaded discard and Amber Acorn behavior; remaining gaps are listed below.\nCandidate-stage release instructions below are preserved history.\n\n'+prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
paths=[EVAL/'SESSION_RESET_431.md',EVAL/'SESSION_RESET_431.json',HERE/'preinstall_verification.json',HERE/'installation.log',
 HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'INSTALLED_REPORT.md',
 CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json',capture/'manifest.json',capture/'summary.json']
verification={'verified_utc':now(),'version':'2.212.0-alpha','revision':431,'digest':digest,'counts':counts[0],
 'candidate_and_installed_gates_passed':True,'installed_runtime_exact':True,'config_preserved':True,'native_files_preserved':7,
 'deployed_paths':94,'backed_existing_paths':94,'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':len(manifest['segments']),'public_bytes_preserved':public_bytes,
 'public_capture':str(capture),'public_outcomes':summary['outcomes'],'public_events':summary['events'],
 'normal_exit_inferred':False,'activation_confirmed':False,'passive_processes':current,'backup':str(backup),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}}
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k]for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')},indent=2))
