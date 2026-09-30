"""Verify installed419 and both gates; publish exact deployment navigation."""
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
assert counts==[{'lua_fixtures':287,'python_tests':458}]*2
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
for rel,sha in candidate_verification['artifact_hashes'].items():assert file_digest(ROOT/rel)==sha,rel
summary=json.loads((HERE/'captures/003/summary.json').read_text())
assert len(summary['starts'])==10 and summary['outcomes']=={'win':3,'loss':6,'abandoned_stall':1} and not summary['unended_run_ids']
assert sum(x['bytes'] for x in manifest['segments'])==44832110 and len(manifest['segments'])==25
digest=freeze['candidate_policy_digest']
checkpoint={'version':'2.203.0-alpha','revision':419,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':109,'deployment_file_count':93,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':335,
 'latest_public_loaded_label':'2.202.0-alpha','latest_public_profile':'perkeo_yorick_win_v1',
 'latest_public_session':manifest['session'],'latest_public_capture':'tools/advisor_eval/development419/captures/003',
 'latest_public_capture_last_sequence':18475,'latest_public_recorded_starts':10,
 'latest_public_recorded_outcomes':summary['outcomes'],'latest_public_unended_runs':0,'latest_public_censored_runs':1,
 'latest_public_deep_audit_complete':False,'latest_public_manifest_sha256':file_digest(HERE/'captures/003/manifest.json'),
 'normal_exit_confirmation_sha256':file_digest(HERE/'normal_exit_confirmation.json'),
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True}
save(EVAL/'SESSION_RESET_419.json',checkpoint)
report=f'''# Installed419 —2.203.0-alpha

Safe five-card discard volume is the leading preference. This update searches
smaller already-scored winning anchors, orders full-batch physical variants before
smaller proofs consume the cap, and qualifies canonical Hiker/Stencil rows. Full
Chad rotations and score/resource safeguards remain. It also aligns first Perkeo
stock, early Joker economy, conflict-Joker admission, Perkeo-preserving same-copy
exchanges and ante7+ surplus spending. See development419/REPORT.md for evidence,
scope, fixture migrations and remaining coverage gaps.

Candidate runs/repair419_candidate3 and exact installed runs/repair419_installed
both pass **287 Lua fixtures/458 Python tests**. Digest `{digest}`;109 runtime
dependencies,335 frozen test files, six changed runtime paths,93 verified deployed
and backed paths. Runtime, tests and validation helpers match. Settings and all
seven DLLs are unchanged. Backup: `{backup}`.

The user authorized installation and explicitly confirmed the latest normal exit.
Passive checks showed no Balatro process during deployment. All current public
files matched the preserved25-segment copy before and after installation. The
2.202 session has18475 verified events/44,832,110 bytes, ten recorded starts,
3 wins/6 losses/1 abandoned_stall, no unended identity. Those logs are safe from
the game's Clear button. Final descriptive joins found28 clearing plays with
discards; these are suspect flags, not proof all28 were safely avoidable. A deep
final-cohort audit remains separate. Prior heartbeat is still paused.

No game control, save/profile access, captured policy/scorer replay, original-game
execution or experiment. Tracked/untracked work, old checkpoints, failed candidate1
and2, raw logs and bounded review evidence are preserved. One substantive review
and one focused recheck are exhausted with no remaining blocker.

Installation is complete; activation awaits the user's next normal launch. No
loaded2.203 outcome, causal win gain,50% win rate or below1% unused-discard rate is
established. Bell, concealment and mixed scoring rows still need further qualified
coverage. It is not an all-fixed claim. Stop this coherent release slice; future
runtime edits require a new scope and exact combined freeze/full validation.
'''
write(EVAL/'SESSION_RESET_419.md',report);write(HERE/'INSTALLED_REPORT.md',report)
prefix=f'''INSTALLED REVISION419 — 2026-09-27
2.203.0-alpha is installed. Read tools/advisor_eval/SESSION_RESET_419.md/.json,
NEXT_PRIORITIES_419.md, ARCHITECTURE_MAP_419.md, development419/REPORT.md,
REVIEW.md and INSTALLED_VERIFICATION.json. Digest {digest}.
Candidate3 and exact-installed gates pass287 Lua/458 Python;109 dependencies,
335 tests, six changed runtime paths and93 verified deployment/backup paths.
Safe five-card discard volume leads optional growth merit; smaller scored anchors,
full-batch shortlist order and canonical Hiker/Stencil coverage are repaired.
Initial Perkeo stock, early economy, conflict-Joker admission, safer same-copy
victims and ante7+ surplus spend are aligned. Broader discard coverage remains.
Settings/seven DLLs and history preserved. Failed candidates1/2 were not installed.
Latest2.202 logs safely copied:25 segments/44,832,110 bytes/18475 verified events,
3 wins/6 losses/1 abandoned_stall, no unended identity.28 clears left discards;
no all-fixed, below1% or loaded2.203 win-rate claim. Final deep audit is separate.
Normal current exit explicitly confirmed; passive absence, backed installation
and exact installed gate verified. Activation awaits user launch; no game control,
saves/profiles, captured replay or original execution. Heartbeat stays PAUSED.
419 release/review complete. Stop this slice. Earlier candidate history follows.

'''
nav=pre['navigation']+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;prior=path.read_bytes();copy=HERE/'navigation_before_install'/rel
 copy.parent.mkdir(parents=True,exist_ok=True)
 with copy.open('xb') as f:f.write(prior)
 path.write_bytes(prefix.encode()+prior);assert path.read_bytes().endswith(prior)
for rel in ('NEXT_PRIORITIES_419.md','ARCHITECTURE_MAP_419.md'):
 path=EVAL/rel;prior=path.read_bytes()
 with (HERE/('candidate_'+rel)).open('xb') as f:f.write(prior)
 path.write_bytes(('Installed419 update: release complete. Read SESSION_RESET_419.md/.json and\n'
  'development419/INSTALLED_VERIFICATION.json. Candidate-only deployment notes\n'
  'below are historical; no further work or experiment is implied.\n\n').encode()+prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
verification={'verified_utc':now(),'version':'2.203.0-alpha','revision':419,'digest':digest,
 'candidate_and_installed_gates_passed':True,'counts':counts[0],'installed_runtime_exact':True,
 'config_preserved':True,'native_files_preserved':7,'deployed_and_backed_paths':93,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':447,
 'public_segments_preserved':25,'public_bytes_preserved':44832110,'public_events':18475,
 'public_outcomes':summary['outcomes'],'normal_exit_confirmed':True,'passive_processes':current,
 'activation_confirmed':False,'deep_final_public_audit_complete':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,
 'candidate_digest':digest,'backup':str(backup),'artifact_hashes':{}}
for p in [EVAL/'SESSION_RESET_419.md',EVAL/'SESSION_RESET_419.json',HERE/'normal_exit_confirmation.json',
 HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'release.log',
 HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'INSTALLED_REPORT.md',
 CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json']:
 verification['artifact_hashes'][p.relative_to(ROOT).as_posix()]=file_digest(p)
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k] for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')}))
