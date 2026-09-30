"""Verify the installed freeze/full gate and publish the installed checkpoint."""
from pathlib import Path
from datetime import datetime
import json,re,subprocess
from release import HERE,EVAL,ROOT,CANDIDATE,FINAL,exact,journals,save,now,processes
from benchmark import file_digest,policy_hashes
def write(path,text):
 with path.open('x',encoding='utf-8') as f:f.write(text)
base,installed,freeze,pre=exact(True);manifest=journals(False)
record=json.loads((FINAL/'record.json').read_text());backup=Path(record['installation']['backup'])
current=processes()
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
assert counts==[{'lua_fixtures':283,'python_tests':458}]*2
assert policy_hashes(FINAL/'policy')==freeze['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
deployed={};changed=[]
for row in deployment['files']:
 rel=row['path'].replace('\\','/')
 assert file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel]
 assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
 deployed[rel]=row['after'].lower()
 if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==93 and set(changed)==set(freeze['changed_runtime_files'])
for rel,sha in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==sha,rel
candidate_verification=json.loads((HERE/'FINAL_VERIFICATION.json').read_text())
assert file_digest(HERE/'final_changes.diff')==candidate_verification['final_diff_sha256']
summary=json.loads((HERE/'captures/001/summary.json').read_text())
digest=freeze['candidate_policy_digest']
checkpoint={'version':'2.200.0-alpha','revision':416,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':109,'deployment_file_count':93,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':330,
 'latest_public_loaded_label':'2.199.0-alpha','latest_public_profile':'perkeo_yorick_win_v1',
 'latest_public_session':manifest['session'],'latest_public_capture':'tools/advisor_eval/development416/captures/001',
 'latest_public_capture_last_sequence':19086,'latest_public_capture_complete_batch':True,
 'latest_public_starts':10,'latest_public_recorded_outcomes':summary['outcomes'],'latest_public_censored_runs':0,
 'latest_public_deep_audit_complete':False,'latest_public_manifest_sha256':file_digest(HERE/'captures/001/manifest.json'),
 'normal_exit_confirmation_sha256':file_digest(HERE/'normal_exit_confirmation.json'),
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False}
save(EVAL/'SESSION_RESET_416.json',checkpoint)
report=f'''# Installed416 —2.200.0-alpha

The five supported diagnosis415 families are repaired and installed: qualified
discard-before-clear coverage, earlier Acorn discard comparisons, Mouth zero-score
and first-category planning, Perkeo terminal generator rescue, and shop shortfall
evidence through budget fallback. Details and limits are in `development416/REPORT.md`.

Candidate `runs/repair416_candidate2` and exact installed freeze
`runs/repair416_installed` both pass **283 Lua fixtures/458 Python tests**.
Digest `{digest}`;109 runtime dependencies,330 frozen test files,10 changed runtime
paths,93 verified deployment/backup paths. Runtime, tests and validation helpers
match. Settings and all7 DLLs are unchanged. Backup: `{backup}`.

The user explicitly confirmed normal exit of the latest session. Passive checks
showed no game process during deployment; all current public files still matched
the safe26-segment copy before and after installation. No game control, saves/profile
access, captured-state scorer/policy replay or original-game execution occurred.
All tracked/untracked work, previous checkpoints, candidate1 failures, raw test
logs and bounded review evidence remain preserved. Review416 is complete.

The archived session contains19,086 verified events and all ten results on public
loaded-label2.199: **2 wins,8 losses**, no unended run. It is safe from the game's
clear-log button. Heartbeat monitoring is paused; it must not follow a new session
without authorization. Full final-cohort deep audit is not claimed by this repair.

Installation is complete;2.200 activates on the next normal user start. No
loaded2.200 result, causal win improvement,50% win rate or below1% unused-discard
rate is established. Unsupported proof scopes and incomplete budgets still abstain;
early Acorn/Mouth estimates are bounded heuristics. Stop this coherent release
slice. Future runtime edits require a new exact combined freeze/full validation.
'''
write(EVAL/'SESSION_RESET_416.md',report);write(HERE/'INSTALLED_REPORT.md',report)
prefix=f'''INSTALLED REVISION416 — 2026-09-26
2.200.0-alpha is installed. Read tools/advisor_eval/SESSION_RESET_416.md/.json,
NEXT_PRIORITIES_416.md, ARCHITECTURE_MAP_416.md and development416/REPORT.md,
REVIEW.md and INSTALLED_VERIFICATION.json. Exact digest {digest}.
Candidate2 and exact-installed gates pass283 Lua/458 Python tests;109 dependencies,
330 tests,10 changed runtime files and93 verified deployment/backup paths.
Settings and7 DLLs are preserved. Candidate1 never installed. Supported discard,
Acorn, Mouth, generator and shop-fallback repairs are combined; budgets unchanged.
Latest public logs safely archived:26 segments/46,795,804 bytes/19,086 events,
ten starts/2 wins/8 losses on loaded-label2.199, no unended run. Full final-cohort
deep audit remains distinct. Monitor is PAUSED; no new-session monitoring implied.
Current normal exit was explicitly confirmed; passive absence and exact backed
installation verified. Installation is not activation; next game start is user-only.
No active-new-session logs, game control, saves/profiles, captured replay or experiment.
No loaded2.200 gain,50% win rate or below1% unused-discard rate is established.
416 candidate/review/release are complete. Stop this slice; all earlier preservation,
execution and release boundaries remain. Candidate-only notes below are history.

'''
nav=pre['navigation']+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;prior=path.read_bytes();copy=HERE/'navigation_before_install'/rel
 copy.parent.mkdir(parents=True,exist_ok=True)
 with copy.open('xb') as f:f.write(prior)
 path.write_bytes(prefix.encode()+prior);assert path.read_bytes().endswith(prior)
for rel in ('NEXT_PRIORITIES_416.md','ARCHITECTURE_MAP_416.md'):
 path=EVAL/rel;prior=path.read_bytes()
 with (HERE/('candidate_'+rel)).open('xb') as f:f.write(prior)
 path.write_bytes(('Installed416 update: release is complete; read SESSION_RESET_416.md/.json and\n'
  'development416/INSTALLED_VERIFICATION.json. Candidate-only release instructions\n'
  'below are preserved history. No further work or experiment is implied.\n\n').encode()+prior)
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
write(HERE/'git_status_installed.txt',status)
verification={'verified_utc':now(),'version':'2.200.0-alpha','revision':416,'digest':digest,
 'candidate_and_installed_gates_passed':True,'counts':counts[0],'installed_runtime_exact':True,
 'config_preserved':True,'native_files_preserved':7,'deployed_and_backed_paths':93,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':26,'public_bytes_preserved':46795804,'public_events':19086,
 'public_outcomes':summary['outcomes'],'normal_exit_confirmed':True,'passive_processes':current,
 'activation_confirmed':False,'deep_final_public_audit_complete':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,
 'candidate_digest':digest,'backup':str(backup),'artifact_hashes':{}}
for p in [EVAL/'SESSION_RESET_416.md',EVAL/'SESSION_RESET_416.json',HERE/'normal_exit_confirmation.json',
 HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'release.log',
 HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'INSTALLED_REPORT.md',
 CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json']:
 verification['artifact_hashes'][p.relative_to(ROOT).as_posix()]=file_digest(p)
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k] for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')}))
