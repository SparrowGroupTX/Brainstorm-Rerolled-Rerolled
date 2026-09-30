"""Verify exact installed420 and publish preserved deployment navigation."""
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
assert counts==[{'lua_fixtures':291,'python_tests':458}]*2
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
summary=json.loads((HERE/'captures/003/summary.json').read_text())
assert len(summary['starts'])==10 and summary['outcomes']=={'win':5,'loss':4,'unsupported':1} and not summary['unended_run_ids']
assert sum(x['bytes'] for x in manifest['segments'])==52621858 and len(manifest['segments'])==26
digest=freeze['candidate_policy_digest']
checkpoint={'version':'2.204.0-alpha','revision':420,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':109,'deployment_file_count':93,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':339,
 'latest_public_loaded_label':'2.203.0-alpha','latest_public_profile':'perkeo_yorick_win_v1',
 'latest_public_session':manifest['session'],'latest_public_capture':'tools/advisor_eval/development420/captures/003',
 'latest_public_capture_last_sequence':21524,'latest_public_recorded_starts':10,
 'latest_public_recorded_outcomes':summary['outcomes'],'latest_public_unended_runs':0,'latest_public_censored_runs':1,
 'latest_public_deep_audit_complete':False,'latest_public_manifest_sha256':file_digest(HERE/'captures/003/manifest.json'),
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True,'late_user_additions_independently_reviewed':False}
save(EVAL/'SESSION_RESET_420.json',checkpoint)
report=f'''# Installed420 —2.204.0-alpha

This combined release repairs useful Death acquisition/source progression,
Death-to-larger-discard preparation, canonical Seltzer/Holo retained proof and
missing Burnt growth valuation. It supports one safe opening single-card cycle
for a useful five-card first Burnt discard, temporarily reducing Yorick copies
when needed to keep the play nonwinning, copying Burnt for the first discard,
and restoring Yorick through a paired resource comparison. All steps require
fresh observations. Ante5–6 surplus target is$40; Ante7+ remains$25, plus
unavoidable rental/discard reserves. See development420/REPORT.md for exact scope.

Candidate runs/repair420_candidate4 and exact-installed runs/repair420_installed
both pass **291 Lua fixtures/458 Python tests**. Digest `{digest}`;109 dependencies,
339 frozen test files, eight changed runtime paths,93 verified deployed and backed
paths. Runtime, tests and validation helpers match. Settings/seven DLLs unchanged.
Backup: `{backup}`.

Installation followed the user's process-check authorization in INSTALLATION_POLICY.md.
Fresh successful checks found no Balatro process before/during deployment; no normal
exit was inferred or confirmation requested. Current public files matched preserved
26-segment logs before and after installation:21524 verified events/52,621,858 bytes,
ten starts,5 recorded wins/4 losses/1 unsupported retirement. These are2.203 records,
not candidate2.204 outcomes.59 physical clears left discards; not all are proven
avoidable. Final whole-cohort deep analysis remains outstanding. Logs are safe from
the game's Clear button. Prior heartbeat remains paused.

The Death/Seltzer scope had one substantive review and one focused recheck, closed
after the held Gold/Blue correction. Late user-added spending/Burnt changes were
tested through manufactured boundaries and production arbitration but are outside
that exhausted independent review disposition. Prior candidates, failures, all
tracked/untracked work,450 prework files and1156 unique historical files remain.

No game control, save/profile access, captured policy/scorer replay, original-game
execution or experiment. Activation awaits user launch. No loaded2.204 outcome,
causal win gain, stable50% win rate, below1% exception or all-discard-cases-fixed
claim. Raised Fist, concealment, mixed rows and broader multi-step fishing still
need separate qualified coverage. Stop this release slice; further runtime work
requires a new scope and exact combined freeze/full validation.
'''
write(EVAL/'SESSION_RESET_420.md',report);write(HERE/'INSTALLED_REPORT.md',report)
prefix=f'''INSTALLED REVISION420 — 2026-09-27
2.204.0-alpha installed. Read tools/advisor_eval/SESSION_RESET_420.md/.json,
NEXT_PRIORITIES_420.md, ARCHITECTURE_MAP_420.md and development420/REPORT.md,
REVIEW.md, INSTALLED_VERIFICATION.json. Digest {digest}.
Candidate4 and exact-installed gates pass291 Lua/458 Python;109 dependencies,
339 tests, eight runtime changes,93 verified deployment/backup paths.
Death source progression, larger-discard preparation, Seltzer proof, Burnt valuation,
one safe first-discard fishing play, temporary reduced Yorick copying, copied Burnt
discard and scoring restoration are implemented in bounded supported scopes.
$40 Ante5–6 and$25 Ante7+ surplus targets retain unavoidable reserves.
Latest2.203 logs preserved:21524 events,26 segments/52,621,858 bytes,
5 wins/4 losses/1 unsupported retirement;59 clears left discards. No loaded2.204
outcome, stable win-rate or all-fixed claim. Broader discard coverage remains.
INSTALLATION_POLICY.md supersedes historical normal-exit confirmation requirements:
fresh successful process absence authorized this backed installation. No normal
exit inferred. Settings/seven DLLs/history preserved; heartbeat stays PAUSED.
No game control, saves/profiles, captured replay or original-game execution.
Review exhausted; late Burnt/spending changes fall outside its disposition.
420 release complete; activation awaits user launch. Earlier history follows.

'''
nav=[p for p in pre['navigation'] if not p.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;prior=path.read_bytes();copy=HERE/'navigation_before_install'/rel;copy.parent.mkdir(parents=True,exist_ok=True)
 with copy.open('xb') as f:f.write(prior)
 path.write_bytes(prefix.encode()+prior);assert path.read_bytes().endswith(prior)
for rel in ('NEXT_PRIORITIES_420.md','ARCHITECTURE_MAP_420.md'):
 path=EVAL/rel;prior=path.read_bytes()
 with (HERE/('candidate_'+rel)).open('xb') as f:f.write(prior)
 path.write_bytes(b'Installed420 update: release complete. Read SESSION_RESET_420.md/.json and\ndevelopment420/INSTALLED_VERIFICATION.json. Earlier candidate notes follow.\n\n'+prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
verification={'verified_utc':now(),'version':'2.204.0-alpha','revision':420,'digest':digest,
 'candidate_and_installed_gates_passed':True,'counts':counts[0],'installed_runtime_exact':True,
 'config_preserved':True,'native_files_preserved':7,'deployed_and_backed_paths':93,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':26,'public_bytes_preserved':52621858,'public_events':21524,
 'public_outcomes':summary['outcomes'],'normal_exit_inferred':False,'passive_processes':current,
 'activation_confirmed':False,'deep_final_public_audit_complete':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,
 'candidate_digest':digest,'backup':str(backup),'artifact_hashes':{}}
for p in [EVAL/'SESSION_RESET_420.md',EVAL/'SESSION_RESET_420.json',EVAL/'INSTALLATION_POLICY.md',
 HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'release.log',HERE/'FINAL_VERIFICATION.json',
 HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'INSTALLED_REPORT.md',CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json']:
 verification['artifact_hashes'][p.relative_to(ROOT).as_posix()]=file_digest(p)
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k] for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')}))
