"""Verify exact installed425 and publish append-only navigation prefixes."""
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
assert counts==[{'lua_fixtures':298,'python_tests':458}]*2
assert policy_hashes(FINAL/'policy')==freeze['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'));deployed={};changed=[];backed=0
for row in deployment['files']:
 rel=row['path'].replace('\\','/')
 if row['before']:
  assert file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel];backed+=1
 else:
  raise AssertionError('425 adds no deployment paths')
 assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
 deployed[rel]=row['after'].lower()
 if not row['before'] or row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and backed==94 and set(changed)==set(freeze['changed_runtime_files'])
for rel,sha in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==sha,rel

digest=freeze['candidate_policy_digest']
capture=EVAL/'development426/captures/002'
summary=json.loads((capture/'summary.json').read_text())
public_bytes=sum(r['bytes'] for r in manifest['segments'])
assert public_bytes==27846979
assert len(summary['starts'])==5 and len(summary['endings'])==4 and summary['unended_run_ids']==['game:6']
checkpoint={
 'version':'2.208.0-alpha','revision':425,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':347,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True,
 'latest_public_loaded_label':'2.207.0-alpha','latest_public_session':summary['session'],
 'latest_public_capture':capture.relative_to(ROOT).as_posix(),'latest_public_capture_last_sequence':summary['events'],
 'latest_public_recorded_starts':len(summary['starts']),'latest_public_recorded_outcomes':summary['outcomes'],
 'latest_public_unended_runs':len(summary['unended_run_ids']),'latest_public_censored_runs':1,
 'latest_public_deep_audit_complete':False,'latest_public_manifest_sha256':file_digest(capture/'manifest.json'),
 'latest_public_session_stopped_reason':None,'soul_expired_joker_fix_included':False}
save(EVAL/'SESSION_RESET_425.json',checkpoint)
report=f'''# Installed425 — 2.208.0-alpha

Installed the exact validated425 discard arbitration repair. Optional Tarot/Planet
development now waits behind an admitted, complete Search-selected Yorick discard.
The held-Death fallback preserves that discard, and final telemetry follows later
phase-copy/retry overrides. See REPORT.md, REVIEW.md and TRACE.json in development425.
No new discard proof scope or computation budget is introduced. Other unsupported
order/held-card cases remain; this does not establish that every discard case is fixed.

Candidate and exact-installed gates passed **298 Lua fixtures / 458 Python tests**.
Digest `{digest}`;110 runtime dependencies and347 frozen test files. Four changed
runtime files,94 verified deployment paths and94 backed existing paths. Settings
and all seven DLLs are unchanged. Backup: `{backup}`.

Newest public logs are preserved in `tools/advisor_eval/development426/captures/002`:
13 segments,27,846,979 bytes,11,341 verified events, no parse or chain errors.
Five recorded starts, four endings:3 wins and1 loss; game:6 remains unended and
censored. No session-stopped event establishes completed play. Source bytes matched
the archive before and after deployment; original logs were not cleared or edited.
These are loaded2.207 records, not2.208 results. No population win-rate claim.

The separate Soul/expired-Joker admission issue is confirmed but NOT fixed in2.208;
read development426/REVIEW.md. No426 runtime edits were made. Its prework baseline
predates this installation/navigation update and must not be mistaken for a new
release baseline when that repair resumes.

Fresh successful passive process absence authorized installation under
INSTALLATION_POLICY.md. No normal exit inferred and no game controlled.
Installation is not activation; user-loaded2.208 evidence remains unconfirmed.
All{len(pre['before_files'])} prework backups and{len(pre['prior_files'])} historical
file hashes remain preserved.425 review is exhausted. No release-time runtime
changes, captured replay, saves/profiles, original execution, experiment or automation.
'''
write(EVAL/'SESSION_RESET_425.md',report)
write(HERE/'INSTALLED_REPORT.md',report)
write(capture/'README.md',f'''# Preserved public session — 2026-09-27

Session `{summary['session']}`, loaded2.207.0-alpha. All13 original BRJ segments
are under logs/; SHA256 values and byte counts are in manifest.json. The verified
11,341-event read-only analysis source is events.sqlite3, with lifecycle and
verification details in summary.json. Total bytes:27,846,979. No verification
errors. Original source journals were left untouched.

Five starts/four endings:3 wins,1 loss, plus one unended/censored run (game:6).
No session-stopped event is recorded. Process absence does not imply normal exit
or a completed session. This archive predates installed2.208 and cannot establish
its effectiveness. Do not replay captured states through the policy/scorer.
Preserve this directory when the user clears active logs.
''')
prefix=f'''INSTALLED REVISION425 — 2026-09-27
2.208.0-alpha installed. Read tools/advisor_eval/SESSION_RESET_425.md/.json,
NEXT_PRIORITIES_425.md, ARCHITECTURE_MAP_425.md and development425/INSTALLED_REPORT.md,
INSTALLED_VERIFICATION.json. Digest {digest}.
Candidate and exact-installed gates:298 Lua/458 Python;110 dependencies/347 tests.
Four changed runtime files;94 deployed/94 backed paths. Settings/seven DLLs preserved.
Optional development and held-Death fallback preserve qualified Search discards.
Loaded2.208 activation/effectiveness remain unconfirmed; other discard gaps remain.
Newest2.207 logs: development426/captures/002,13 segments/27,846,979 bytes/11,341
verified events;3 wins,1 loss,one unended/censored run. Original logs untouched.
Previous completed ten-run2.205 archive remains development424/captures/002.
Soul/expired-Joker gap is confirmed but NOT fixed here; development426/REVIEW.md.
426 investigation is read-only; its prework predates this425 installation/update.
Fresh passive absence authorized installation; no normal exit inferred or further
confirmation required. No game control, saves/profiles, captured replay, original
execution, new experiment or automation. Historical budgets CLOSED;425 review exhausted.
Release complete. Earlier candidate/history records follow for provenance.

'''
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;prior=p.read_bytes();back=HERE/'navigation_before_install'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(prior)
 p.write_bytes(prefix.encode()+prior);assert p.read_bytes().endswith(prior)
for rel in ('NEXT_PRIORITIES_425.md','ARCHITECTURE_MAP_425.md'):
 p=EVAL/rel;prior=p.read_bytes();write(HERE/('candidate_'+rel),prior.decode())
 p.write_bytes(b'Installed425: release complete. Read SESSION_RESET_425 and development425/INSTALLED_VERIFICATION.json.\nLatest logs: development426/captures/002 (loaded2.207; one unended run).\nSoul/expired-Joker repair remains pending; development426/REVIEW.md.\nThe candidate-stage release instructions below are preserved history.\n\n'+prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
paths=[EVAL/'SESSION_RESET_425.md',EVAL/'SESSION_RESET_425.json',HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'INSTALLED_REPORT.md',CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json',capture/'manifest.json',capture/'summary.json',capture/'README.md']
verification={'verified_utc':now(),'version':'2.208.0-alpha','revision':425,'digest':digest,'counts':counts[0],
 'candidate_and_installed_gates_passed':True,'installed_runtime_exact':True,'config_preserved':True,'native_files_preserved':7,
 'deployed_paths':94,'backed_existing_paths':94,'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':len(manifest['segments']),'public_bytes_preserved':public_bytes,
 'public_capture':str(capture),'public_outcomes':summary['outcomes'],'public_events':summary['events'],
 'normal_exit_inferred':False,'activation_confirmed':False,'passive_processes':current,'backup':str(backup),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in paths}}
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k] for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes','public_capture','public_outcomes')}))
