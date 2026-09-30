"""Close combined433 only after exact candidate and installed full gates."""
from pathlib import Path
import json,subprocess
from release import HERE,EVAL,ROOT,CANDIDATE,FINAL,exact,journals,save,now,processes,read
from complete import gate_counts
from benchmark import file_digest,policy_hashes

def write(path,text):
 with Path(path).open('x',encoding='utf-8')as f:f.write(text)

base,installed,freeze,pre=exact(True);capture,manifest,summary=journals(False)
record=read(FINAL/'record.json');backup=Path(record['installation']['backup']);current=processes()
counts=[gate_counts(folder)for folder in (CANDIDATE,FINAL)]
for folder in (CANDIDATE,FINAL):
 gate=read(folder/'validation/report.json')
 assert gate['policy_files']==freeze['candidate_policy_files']and gate['test_files']==freeze['test_files']
 assert gate['validation_provenance']==freeze['validation_provenance']
assert policy_hashes(FINAL/'policy')==freeze['candidate_policy_files']==record['policy_files']
deployment=read(backup/'deployment.json') if not (backup/'deployment.json').read_bytes().startswith(b'\xef\xbb\xbf') else json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
deployed={};changed=[]
for row in deployment['files']:
 rel=row['path'].replace('\\','/')
 assert row['before']and file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel]
 assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
 deployed[rel]=row['after'].lower()
 if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and set(changed)==set(freeze['changed_runtime_files'])and len(changed)==9
digest=freeze['candidate_policy_digest'];public_bytes=sum(r['bytes']for r in manifest['segments'])
checkpoint={'version':'2.213.0-alpha','revision':433,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':356,'new_fixture_assertions':404,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True,'prior_preserved_hashes':len(pre['prior_files']),
 'latest_public_loaded_label':'2.212.0-alpha','latest_public_session':summary['session'],
 'latest_public_capture':capture.relative_to(ROOT).as_posix(),'latest_public_capture_last_sequence':summary['events'],
 'latest_public_recorded_starts':len(summary['starts']),'latest_public_recorded_outcomes':summary['outcomes'],
 'latest_public_unended_runs':len(summary['unended_run_ids']),'latest_public_manifest_sha256':file_digest(capture/'manifest.json'),
 'captured_policy_replay433':False,'historical_experiments':'CLOSED'}
save(EVAL/'SESSION_RESET_433.json',checkpoint)
report=f'''# Installed433 /2.213.0-alpha

The combined update is installed. Candidate and exact-installed gates both pass
**306 Lua fixtures /458 Python tests**, including404 new manufactured assertions.
Digest `{digest}`;110 runtime dependencies,356 frozen test files. Nine changed
runtime files,94 deployed/94 backed paths. Config and all seven DLLs are unchanged.
Backup: `{backup}`. User-loaded2.213 activation remains unconfirmed.

Repairs: bounded stronger discard anchors; eight canonical Joker proof families;
continued Buffoon copy exploration after owning Blueprint; cash targets distinct
from mandatory reserves; ordinary-slot whole-pool Planet/Fool replacement;
independently complete focused copy endpoints with prequalified sale→buy;
Hit the Road's real Jack discard/reset/lifetime comparison and truthful Hook
diagnostics. See development433/REPORT.md and REVIEW.md for scope and controls.

Latest completed user session is safely copied at
`{capture.relative_to(ROOT).as_posix()}`:29 segments,{public_bytes:,} bytes,
25,337 verified events,10 starts/10 endings,5wins/5losses/0unsupported, no unended
run IDs or verification errors. These are loaded2.212 outcomes, not2.213 results
or evidence of a50% population win rate. The passive audit found27 clears with67
unused discards; this update's actual improvement has not been measured in-game.

Fresh successful passive absence authorized deployment under the user's standing
instruction. No normal exit was inferred and no confirmation was requested.
Original journals matched the preserved copy immediately before and after
deployment. No journals cleared, game controlled, saves/profiles accessed,
original game component executed, captured evaluation or simulation performed.
All{len(pre['prior_files'])} prior artifact hashes and{len(pre['before_files'])}
before-work files remain intact.433 review and historical experiments are closed.

This addresses the identified supported causes; larger or unsupported proof
families can still leave discards unused. There is no all-decisions-optimal,
near-never unused-discards, or improved loaded-game win-rate claim.
'''
write(EVAL/'SESSION_RESET_433.md',report);write(HERE/'INSTALLED_REPORT.md',report)
write(EVAL/'NEXT_PRIORITIES_433.md','''# Priorities433

Installed433/2.213 is release-complete. Read SESSION_RESET_433.md/.json and
development433/INSTALLED_VERIFICATION.json. Await user-supplied loaded evidence;
installation alone does not show activation or policy effectiveness.

The supported audit432 causes are repaired with404 manufactured assertions.
Do not repeat the completed review or reopen historical experiments. Compare
future public discard counts, cards per discard and admission reasons with the
preserved2.212 batch (27clears/67unused,423discards/1,637cards). Avoid cross-batch
causal win-rate claims. Remaining possible work is larger order-sensitive proof
families, per-size risky-discard rejection receipts, budget-complete Acorn products,
special bosses and uncertainty. Require evidence and bounded complete comparisons.

The latest public batch is development433/captures/001,5wins/5losses/0unsupported.
276heuristic flags are triage leads, not276 established mistakes. Preserve every
old freeze, journal and test; no game control, saves/profiles, captured execution
or simulation is authorized by this navigation. Future runtime changes require
a new exact combined freeze and candidate/installed validation.
''')
write(EVAL/'ARCHITECTURE_MAP_433.md','''# Architecture433

growth.select_clear returns a qualified stronger fallback; suggest_portfolio
preserves the original anchor's allowance and uses only residual work for one
fallback. decision routes both growth paths through it. growth qualifies eight
additional canonical nonnegative Joker families; hidden Faceless remains excluded.
player_journal records portfolio and independent copy-endpoint diagnostics.

strategy keeps funded Buffoon exploration after Blueprint, treats cash thresholds
as spend triggers, and evaluates ordinary-slot Perkeo exchanges against the full
inventory. Negative sales do not create a slot; Observatory Planets stay protected.
Its separate focused_copy_endpoint certificate requires a complete supported
same-target family and retained canonical Yorick. decision asks shop_sequences to
qualify the real sale→buy before publishing the sale, using the same budget.

shop_scoring resets canonical Hit the Road for the next blind and declares a
common additional observed-Jack policy before comparing endpoints. blind_finishing
executes one actual public Jack discard under that fixed policy in all worlds;
joker_plan values only remaining temporary support. Hook readiness reports the
unsupported mechanic instead of an absent target. Caps remain unchanged.

Frozen candidate repair433_candidate3 and repair433_installed have identical110
dependencies;356 frozen test files. Four new fixtures cover272/64/31/37 assertions.
Development433 passive helpers read copied JSON/SQLite only. Candidate1/2 failures
are preserved; candidate3 and installed gates are authoritative. Previous Acorn
continuity and conditional-held mechanics remain mapped in ARCHITECTURE_MAP_431.
''')
prefix=f'''INSTALLED REVISION433 /2.213.0-alpha —{now()[:10]}
Read tools/advisor_eval/SESSION_RESET_433.md/.json, NEXT_PRIORITIES_433.md,
ARCHITECTURE_MAP_433.md and development433/REPORT.md, REVIEW.md,
INSTALLED_VERIFICATION.json. Candidate and exact-installed gates306Lua/458Python;
404new manufactured assertions,110 dependencies/356 tests. Digest {digest}.
Nine changed runtime files;94 deployed/94 backed; config/seven DLLs unchanged.
Repairs cover alternate discard anchors/canonical Joker proofs, continued Buffoon
copy exploration, cash targets, full-slot Planet/Fool stock, focused copy endpoints,
real Hit-the-Road discard/reset/lifetime and truthful Hook diagnostics.
Latest preserved loaded2.212 session: development433/captures/001,25,337events,
5wins/5losses/0unsupported;10starts/10endings,no unended runs.27clears left67discards.
Loaded2.213 activation/effectiveness unconfirmed; no population win-rate or all-fixed claim.
Fresh passive absence authorized installation; no confirmation/normal-exit inference.
No game control, saves/profiles, original execution, captured replay, simulation,
experiment or automation.433review exhausted; historical experiments CLOSED.
Release complete. Earlier records below remain preserved history.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;prior=p.read_bytes();back=HERE/'navigation_before_install'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb')as f:f.write(prior)
 p.write_bytes(prefix.encode('utf-8')+prior);assert p.read_bytes().endswith(prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
paths=[EVAL/'SESSION_RESET_433.md',EVAL/'SESSION_RESET_433.json',EVAL/'NEXT_PRIORITIES_433.md',EVAL/'ARCHITECTURE_MAP_433.md',
 HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',
 HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'INSTALLED_REPORT.md',CANDIDATE/'freeze.json',CANDIDATE/'validation/report.json',
 FINAL/'record.json',FINAL/'validation/report.json',capture/'manifest.json',capture/'summary.json']
verification={'verified_utc':now(),'version':'2.213.0-alpha','revision':433,'digest':digest,'counts':counts[0],
 'candidate_and_installed_gates_passed':True,'installed_runtime_exact':True,'config_preserved':True,'native_files_preserved':7,
 'deployed_paths':94,'backed_existing_paths':94,'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':29,'public_bytes_preserved':public_bytes,'public_capture':str(capture),
 'public_outcomes':summary['outcomes'],'public_events':summary['events'],'normal_exit_inferred':False,
 'activation_confirmed':False,'passive_processes':current,'backup':str(backup),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}}
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k]for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')},indent=2))
