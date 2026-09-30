"""Verify exact installed426 and publish append-only navigation prefixes."""
from datetime import datetime
import json,re,subprocess
from pathlib import Path
from release import HERE,EVAL,ROOT,CANDIDATE,FINAL,exact,journals,save,now,processes
from benchmark import file_digest,policy_hashes
def write(p,s):
 with p.open('x',encoding='utf-8') as f:f.write(s)
base,installed,freeze,pre=exact(True);manifest=journals(False)
record=json.loads((FINAL/'record.json').read_text());backup=Path(record['installation']['backup']);current=processes()
for p in current if isinstance(current,list) else [current]:
 assert datetime.fromisoformat(p['StartTime']).timestamp()>datetime.fromisoformat(record['created_utc']).timestamp()
counts=[]
for folder in (CANDIDATE,FINAL):
 gate=json.loads((folder/'validation/report.json').read_text())
 assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
 assert gate['policy_files']==freeze['candidate_policy_files'] and gate['test_files']==freeze['test_files']
 assert gate['validation_provenance']==freeze['validation_provenance']
 m=re.search(r'(\d+)/(\d+) fixtures passed',(folder/'validation/lua.log').read_text());assert m and m[1]==m[2]
 py=sum(int(re.search(r'Ran (\d+) tests',(folder/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
 counts.append({'lua_fixtures':int(m[1]),'python_tests':py})
assert counts==[{'lua_fixtures':299,'python_tests':458}]*2
assert policy_hashes(FINAL/'policy')==freeze['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'));deployed={};changed=[];backed=0
for row in deployment['files']:
 rel=row['path'].replace('\\','/')
 if row['before']:
  assert file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel];backed+=1
 else:
  raise AssertionError('426 adds no deployment paths')
 assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
 deployed[rel]=row['after'].lower()
 if not row['before'] or row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and backed==94 and set(changed)==set(freeze['changed_runtime_files'])
for rel,sha in pre['before_files'].items():assert file_digest(HERE/'before_resume'/rel)==sha,rel

digest=freeze['candidate_policy_digest']
capture=EVAL/'development427/captures/001'
summary=json.loads((capture/'summary.json').read_text())
public_bytes=sum(r['bytes'] for r in manifest['segments'])
assert public_bytes==58608017
assert len(summary['starts'])==10 and len(summary['endings'])==10 and not summary['unended_run_ids']
checkpoint={
 'version':'2.209.0-alpha','revision':426,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':348,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True,
 'latest_public_loaded_label':'2.208.0-alpha','latest_public_session':summary['session'],
 'latest_public_capture':capture.relative_to(ROOT).as_posix(),'latest_public_capture_last_sequence':summary['events'],
 'latest_public_recorded_starts':len(summary['starts']),'latest_public_recorded_outcomes':summary['outcomes'],
 'latest_public_unended_runs':len(summary['unended_run_ids']),'latest_public_censored_runs':0,
 'latest_public_deep_audit_complete':False,'latest_public_manifest_sha256':file_digest(capture/'manifest.json'),
 'latest_public_session_stopped_reason':'run_limit','soul_expired_joker_fix_included':True}
save(EVAL/'SESSION_RESET_426.json',checkpoint)
report=f'''# Installed426 — 2.209.0-alpha

Exact candidate426 is installed. A visible Soul can now receive a supported
expired-Joker sale preparation, then fresh choice after the sale. The proof
preserves supported active effects, copy targets, inventory and resources. No
hypothetical legendary or lasting Stencil vacancy boost is valued. The legacy
Egg route cannot bypass these guards. Read REPORT.md and IMPLEMENTATION_REVIEW.md.

Candidate and exact-installed gates: **299 Lua fixtures /458 Python tests**.
Digest `{digest}`;110 runtime dependencies,348 frozen tests. Four changed runtime
files,94 deployed/94 backed paths. Settings and all seven DLLs are unchanged.
Backup: `{backup}`. No new runtime edits during installation.

The just-finished loaded2.208 ten-run session is safely archived at
`tools/advisor_eval/development427/captures/001`:28 segments,58,608,017 bytes,
23,927 verified events;10 starts and10 endings,5 wins and5 losses, no unended or
unsupported runs and no verification errors. Journal session_stopped reason is
run_limit. Original source bytes matched the copy before/after deployment and
were never cleared or edited. This session result is not an established long-run
win rate. Requested causal audit is ongoing in development427.

Fresh successful passive process absence authorized installation. No normal exit
inferred or game controlled. Installation is not loaded2.209 activation evidence.
All{len(pre['before_files'])} before_resume backups and{len(pre['prior_files'])}
historical hashes are preserved. Original426 prework/review remain history;
resume_prework.json binds the post425 baseline.426 review exhausted.
No captured replay, saves/profiles, original execution, experiment or automation.
Other unused-discard proof gaps remain; no all-fixed claim.
'''
write(EVAL/'SESSION_RESET_426.md',report)
write(HERE/'INSTALLED_REPORT.md',report)
write(capture/'README.md',f'''# Preserved complete ten-run session — 2026-09-27

Session `{summary['session']}`, loaded2.208.0-alpha. All28 original BRJ segments
are under logs/; SHA256 hashes and byte counts are in manifest.json. Verified
read-only events.sqlite3 contains23,927 events. Total bytes:58,608,017. No chain or
parse errors; source bytes matched at installation and were left untouched.
Ten recorded starts/endings:5 wins,5 losses; no unended/unsupported runs.
The journal records session_stopped/run_limit. No normal exit is inferred.
This archive predates installed2.209 and cannot establish its effectiveness.
Audit artifacts belong to development427. Do not replay captured states through
the policy/scorer. Preserve this directory when active journals are cleared.
''')
prefix=f'''INSTALLED REVISION426 — 2026-09-27
2.209.0-alpha installed. Read tools/advisor_eval/SESSION_RESET_426.md/.json,
NEXT_PRIORITIES_426.md, ARCHITECTURE_MAP_426.md and development426/INSTALLED_REPORT.md,
INSTALLED_VERIFICATION.json. Digest {digest}.
Candidate and exact-installed gates:299 Lua/458 Python;110 dependencies/348 tests.
Four changed runtime files;94 deployed/94 backed. Settings/seven DLLs preserved.
Soul/expired-Joker admission repair is included; fresh observation follows sale.
Loaded2.209 activation/effectiveness unconfirmed. Other discard proof gaps remain.
Completed loaded2.208 ten-run archive: development427/captures/001,28 segments,
58,608,017 bytes,23,927 verified events;5 wins5losses,no unended runs,run_limit stop.
Requested passive decision audit is ongoing in development427. No population win-rate
claim. Original journals and previous archives untouched.426 original prework predates
425 install; resume_prework.json governs426. No extra confirmation or inferred normal exit.
No game control, saves/profiles, captured replay, original execution, experiment
or automation. Historical budgets CLOSED;426 review exhausted.
Release complete. Earlier candidate/history records follow for provenance.

'''
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;prior=p.read_bytes();back=HERE/'navigation_before_install'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(prior)
 p.write_bytes(prefix.encode()+prior);assert p.read_bytes().endswith(prior)
for rel in ('NEXT_PRIORITIES_426.md','ARCHITECTURE_MAP_426.md'):
 p=EVAL/rel;prior=p.read_bytes();write(HERE/('candidate_'+rel),prior.decode())
 p.write_bytes(b'Installed426/2.209: release complete. Read SESSION_RESET_426 and development426/INSTALLED_VERIFICATION.json.\nLatest complete ten-run logs: development427/captures/001 (loaded2.208); causal audit ongoing.\nThe candidate-stage release instructions below are preserved history.\n\n'+prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
paths=[EVAL/'SESSION_RESET_426.md',EVAL/'SESSION_RESET_426.json',HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'INSTALLED_REPORT.md',CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json',capture/'manifest.json',capture/'summary.json',capture/'README.md']
verification={'verified_utc':now(),'version':'2.209.0-alpha','revision':426,'digest':digest,'counts':counts[0],
 'candidate_and_installed_gates_passed':True,'installed_runtime_exact':True,'config_preserved':True,'native_files_preserved':7,
 'deployed_paths':94,'backed_existing_paths':94,'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':len(manifest['segments']),'public_bytes_preserved':public_bytes,
 'public_capture':str(capture),'public_outcomes':summary['outcomes'],'public_events':summary['events'],
 'normal_exit_inferred':False,'activation_confirmed':False,'passive_processes':current,'backup':str(backup),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in paths}}
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k] for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes','public_capture','public_outcomes')}))
