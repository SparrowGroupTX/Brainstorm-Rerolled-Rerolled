"""Verify exact installed421 and publish append-only navigation prefixes."""
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
assert counts==[{'lua_fixtures':294,'python_tests':458}]*2
assert policy_hashes(FINAL/'policy')==freeze['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'));deployed={};changed=[];backed=0
for row in deployment['files']:
 rel=row['path'].replace('\\','/')
 if row['before']:
  assert file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel];backed+=1
 else:
  assert rel not in base['deployment_files'] and rel=='Advisor/joker_plan.lua' and not (backup/rel).exists()
 assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
 deployed[rel]=row['after'].lower()
 if not row['before'] or row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and backed==93 and set(changed)==set(freeze['changed_runtime_files'])
for rel,sha in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==sha,rel
digest=freeze['candidate_policy_digest']
checkpoint={**{k:v for k,v in base.items() if k.startswith('latest_public_')},
 'version':'2.205.0-alpha','revision':421,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':93,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':343,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'all_joker_contexts_optimal':False,'joker_catalog_count':150,'previous_generic_unknown':28,
 'review_cycle_exhausted':True,'post_review_strength_integration_independently_reviewed':False}
save(EVAL/'SESSION_RESET_421.json',checkpoint)
report=f'''# Installed421 —2.205.0-alpha

Audited150 vanilla Joker identities and repaired28 formerly generic teacher
ratings. Dynamic values account for public hand history/levels, embedded
rank-repeat hands, scoring versus played/held counts, actual counters,
discard-growth conflicts, suit feasibility and owned/future synergy timing.
Read development421/REPORT.md, CATALOG.md, REVIEW.md for exact scope and limits.

Candidate2 and exact-installed gates pass **294 Lua fixtures/458 Python tests**.
Digest `{digest}`;110 runtime dependencies/343 frozen test files, seven changed
runtime paths,94 verified deployed files/93 backed existing files. The new
Advisor/joker_plan.lua had no previous installed file. Settings/seven DLLs unchanged.
Backup: `{backup}`.

Fresh successful passive process absence authorized installation under
INSTALLATION_POLICY.md. No confirmation requested or normal exit inferred.
Current public journals matched the preserved26-segment2.203 capture under
development420/captures/003 before and after deployment.21524 events and
52,621,858 bytes remain safe. Their5 wins/4 losses/1 unsupported retirement are
not2.205 results. Activation and loaded-game improvement are unconfirmed.

238 new manufactured assertions plus unchanged regressions cover the repairs;
candidate1's Strength preservation failure and corrected candidate2 remain.
One substantive review/one focused recheck closed after suit/held/redaction
corrections. The final Strength reserve integration fix was root-tested against
the existing unchanged fixture, outside independent re-review. Review exhausted.

All tracked/untracked work,454 prework files and{len(pre['prior_files'])} unique
historical files remain. No game control, saves/profiles, captured replay,
original-game execution, new experiment or monitor. Prior heartbeat stays paused.
Heuristic weights are not proven optimal for every run; no win-rate claim.
Broader mixed-row discard coverage and old cohort deep analysis remain open.
Stop this delivery; further runtime changes require a new exact combined gate.
'''
write(EVAL/'SESSION_RESET_421.md',report);write(HERE/'INSTALLED_REPORT.md',report)
prefix=f'''INSTALLED REVISION421 —2026-09-27
2.205.0-alpha installed. Read tools/advisor_eval/SESSION_RESET_421.md/.json,
NEXT_PRIORITIES_421.md, ARCHITECTURE_MAP_421.md and development421/REPORT.md,
CATALOG.md, REVIEW.md, INSTALLED_VERIFICATION.json. Digest {digest}.
Candidate2 and exact-installed gates pass294 Lua/458 Python;110 dependencies,
343 frozen tests;seven runtime changes,94 deployment paths/93 backed existing.
150 Jokers audited;28 formerly generic teacher values repaired. Public hand mix,
embedded rank hands, scoring/held counts, counters, discard conflicts and synergy
timing now inform the shared values. No all-contexts-optimal or win-rate claim.
Fresh passive process absence authorized installation without confirmation under
INSTALLATION_POLICY.md. No normal exit inferred; settings/seven DLLs preserved.
Latest public data remains preserved2.203, not2.205 evidence. No game control,
saves/profiles, captured replay, original execution or new experiment. Heartbeat
stays PAUSED. Review exhausted; final Strength integration root-tested separately.
421 release complete; activation awaits user launch. Earlier history follows.

'''
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;prior=p.read_bytes();back=HERE/'navigation_before_install'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(prior)
 p.write_bytes(prefix.encode()+prior);assert p.read_bytes().endswith(prior)
for rel in ('NEXT_PRIORITIES_421.md','ARCHITECTURE_MAP_421.md'):
 p=EVAL/rel;prior=p.read_bytes();write(HERE/('candidate_'+rel),prior.decode())
 p.write_bytes(b'Installed421: release complete. Read SESSION_RESET_421 and development421/INSTALLED_VERIFICATION.json.\n\n'+prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
paths=[EVAL/'SESSION_RESET_421.md',EVAL/'SESSION_RESET_421.json',HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'INSTALLED_REPORT.md',CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json']
verification={'verified_utc':now(),'version':'2.205.0-alpha','revision':421,'digest':digest,'counts':counts[0],
 'candidate_and_installed_gates_passed':True,'installed_runtime_exact':True,'config_preserved':True,'native_files_preserved':7,
 'deployed_paths':94,'backed_existing_paths':93,'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':len(manifest['segments']),'public_bytes_preserved':sum(r['bytes'] for r in manifest['segments']),
 'normal_exit_inferred':False,'activation_confirmed':False,'passive_processes':current,'backup':str(backup),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in paths}}
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k] for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')}))
