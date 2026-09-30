"""Verify installed418 and both full gates; preserve and publish release records."""
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
assert counts==[{'lua_fixtures':285,'python_tests':458}]*2
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
summary=json.loads((HERE/'captures/002/summary.json').read_text())
assert len(summary['starts'])==10 and summary['outcomes']=={'win':3,'loss':7} and not summary['unended_run_ids']
digest=freeze['candidate_policy_digest']
checkpoint={'version':'2.202.0-alpha','revision':418,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':109,'deployment_file_count':93,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':333,
 'latest_public_loaded_label':'2.200.0-alpha','latest_public_profile':'perkeo_yorick_win_v1',
 'latest_public_session':manifest['session'],'latest_public_capture':'tools/advisor_eval/development418/captures/002',
 'latest_public_capture_last_sequence':20169,'latest_public_capture_complete_batch':True,
 'latest_public_starts':10,'latest_public_recorded_outcomes':summary['outcomes'],'latest_public_censored_runs':0,
 'latest_public_deep_audit_complete':False,'latest_public_manifest_sha256':file_digest(HERE/'captures/002/manifest.json'),
 'normal_exit_confirmation_sha256':file_digest(HERE/'normal_exit_confirmation.json'),
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True}
save(EVAL/'SESSION_RESET_418.json',checkpoint)
report=f'''# Installed418 —2.202.0-alpha

The combined417/418 discard repairs are installed: Cloud9/Popcorn admission,
selection of safer already-scored alternatives, further canonical additive rows,
complete Hanging Chad first-scorer minima, and qualified identity-independent
hidden-spare discards. Acorn explicitly refuses an unproved product family.
Details and remaining gaps are in `development418/REPORT.md`.

Candidate `runs/repair418_candidate2` and exact installed freeze
`runs/repair418_installed` both pass **285 Lua fixtures/458 Python tests**.
Digest `{digest}`;109 runtime dependencies,333 frozen test files, four changed
runtime paths,93 verified deployment/backup paths. Runtime, tests and validation
helpers match. Settings and all seven DLLs are unchanged. Backup: `{backup}`.

The user explicitly confirmed this session's normal exit after requesting install.
Passive checks showed no game process during deployment. All current public files
matched the safe26-segment copy before and after installation. No game control,
save/profile access, captured-policy/scorer replay or original-game execution.
All tracked/untracked work, earlier checkpoints, failed candidate1, raw test logs
and bounded review evidence remain preserved. Review418 allocation is exhausted.

The complete archived2.200 session has20,169 verified events/49,278,780 bytes,
ten starts, **3 wins/7 losses**, no unended run. It is safe from the game's log-clear
button. The prior heartbeat remains paused; no new-session monitor was started.
The final complete-cohort deep audit remains separate from the earlier prefix work.

Installation is complete;2.202 activates on the next normal user launch. No loaded
2.202 result, causal win gain,50% win rate or below1% unused-discard rate is established.
Bell, additional Joker combinations, mixed scoring mechanics and combined Acorn/Chad
proofs remain incomplete. This is not a claim every discard issue is fixed.
Stop this coherent release slice. Future runtime changes require a new exact
combined freeze/full validation. Existing preservation/execution boundaries remain.
'''
write(EVAL/'SESSION_RESET_418.md',report);write(HERE/'INSTALLED_REPORT.md',report)
prefix=f'''INSTALLED REVISION418 — 2026-09-26
2.202.0-alpha is installed. Read tools/advisor_eval/SESSION_RESET_418.md/.json,
NEXT_PRIORITIES_418.md, ARCHITECTURE_MAP_418.md, development418/REPORT.md,
REVIEW.md and INSTALLED_VERIFICATION.json. Digest {digest}.
Candidate2 and exact-installed gates pass285 Lua/458 Python tests;109 dependencies,
333 tests, four changed runtime paths and93 verified deployment/backup paths.
Settings/seven DLLs and all earlier work preserved. Neither417 nor418 candidate1
was installed. The combined canonical-row/Chad/hidden-spare repairs are deployed;
Bell and additional combinations remain. No all-fixed or below1% claim.
Latest2.200 public session safely copied:26 segments/49,278,780 bytes/20,169 verified
events, ten starts/3 wins/7 losses, no unended run. Full final-cohort deep audit is
separate. Prior heartbeat stays PAUSED; no new-session monitoring implied.
User explicitly confirmed current normal exit; passive absence, exact backed
deployment and installed gate verified. Installation is not activation; user launch
only. No game control, saves/profiles, captured replay or original execution.
No loaded2.202 gain or50% population win-rate claim.418 release/review complete.
Stop this slice; all earlier boundaries remain. Candidate-only history follows.

'''
nav=pre['navigation']+['tools/advisor_eval/README.md']
for rel in nav:
 path=ROOT/rel;prior=path.read_bytes();copy=HERE/'navigation_before_install'/rel
 copy.parent.mkdir(parents=True,exist_ok=True)
 with copy.open('xb') as f:f.write(prior)
 path.write_bytes(prefix.encode()+prior);assert path.read_bytes().endswith(prior)
for rel in ('NEXT_PRIORITIES_418.md','ARCHITECTURE_MAP_418.md'):
 path=EVAL/rel;prior=path.read_bytes()
 with (HERE/('candidate_'+rel)).open('xb') as f:f.write(prior)
 path.write_bytes(('Installed418 update: release is complete; read SESSION_RESET_418.md/.json and\n'
  'development418/INSTALLED_VERIFICATION.json. Candidate-only release instructions\n'
  'below remain historical. No further work or experiment is implied.\n\n').encode()+prior)
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
write(HERE/'git_status_installed.txt',status)
verification={'verified_utc':now(),'version':'2.202.0-alpha','revision':418,'digest':digest,
 'candidate_and_installed_gates_passed':True,'counts':counts[0],'installed_runtime_exact':True,
 'config_preserved':True,'native_files_preserved':7,'deployed_and_backed_paths':93,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':26,'public_bytes_preserved':49278780,'public_events':20169,
 'public_outcomes':summary['outcomes'],'normal_exit_confirmed':True,'passive_processes':current,
 'activation_confirmed':False,'deep_final_public_audit_complete':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,
 'candidate_digest':digest,'backup':str(backup),'artifact_hashes':{}}
for p in [EVAL/'SESSION_RESET_418.md',EVAL/'SESSION_RESET_418.json',HERE/'normal_exit_confirmation.json',
 HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'release.log',
 HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'INSTALLED_REPORT.md',
 CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json']:
 verification['artifact_hashes'][p.relative_to(ROOT).as_posix()]=file_digest(p)
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k] for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')}))
