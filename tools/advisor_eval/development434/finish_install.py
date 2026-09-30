"""Close434 only after exact candidate and installed full validation."""
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
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
deployed={};changed=[]
for row in deployment['files']:
 rel=row['path'].replace('\\','/')
 assert row['before']and file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel]
 assert file_digest(installed/rel)==row['after'].lower()==freeze['candidate_policy_files']['Brainstorm/'+rel]
 deployed[rel]=row['after'].lower()
 if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==94 and set(changed)==set(freeze['changed_runtime_files'])and len(changed)==13
digest=freeze['candidate_policy_digest'];public_bytes=sum(r['bytes']for r in manifest['segments'])
checkpoint={'version':'2.214.0-alpha','revision':434,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':freeze['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':110,'deployment_file_count':94,'backed_existing_file_count':94,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':360,'new_fixture_assertions':55930,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':current,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False,
 'all_discard_cases_fixed':False,'review_cycle_exhausted':True,'prior_preserved_hashes':len(pre['prior_files']),
 'latest_public_loaded_label':'2.213.0-alpha','latest_public_session':summary['session'],
 'latest_public_capture':capture.relative_to(ROOT).as_posix(),'latest_public_capture_last_sequence':summary['events'],
 'latest_public_recorded_starts':len(summary['starts']),'latest_public_recorded_outcomes':summary['outcomes'],
 'latest_public_unended_runs':len(summary['unended_run_ids']),'latest_public_manifest_sha256':file_digest(capture/'manifest.json'),
 'captured_policy_replay434':False,'historical_experiments':'CLOSED'}
save(EVAL/'SESSION_RESET_434.json',checkpoint)
report=f'''# Installed434 /2.214.0-alpha

The combined update is installed. Candidate and exact-installed gates both pass
310 Lua fixtures /458 Python tests,110 runtime dependencies/360 frozen test files.
Digest `{digest}`.13 changed runtime files,94 deployed/94 backed paths.
Config and all seven DLLs are unchanged. Backup: `{backup}`.
User-loaded2.214 activation and effectiveness remain unconfirmed.

Repairs: Lucky-ranked Burnt reorder oscillation with independently reliable
finish; Campfire/Road Acorn public-action continuity and visible Jack growth;
Blueprint/Brainstorm reserve-funded sale-to-buy admission despite an open slot;
canonical Joker/edition and complete card-product discard floors; bounded
per-size risk rejection receipts; canonical Road creation metadata admission.
See development434/REPORT.md and REVIEW.md for evidence, fixtures and limits.

Latest completed session safely copied at `{capture.relative_to(ROOT).as_posix()}`:
27 segments,{public_bytes:,} bytes,27,925 verified events,10 starts/10 endings,
4wins/4losses/1abandoned_stall/1unsupported,no unended runs or verification errors.
These are loaded2.213 outcomes.510 discards removed1,939 cards;28 clears left57
discards. Actual2.214 improvement is not measured. Four terminal losses spent all
their final-round discards; early survival and valuation questions remain.

Fresh successful passive absence authorized installation without confirmation or
normal-exit inference. Source journals matched the preserved copy immediately
before and after deployment. No journals cleared, game controlled, saves/profiles
accessed, original component executed, captured evaluation, simulation or
automation performed. All{len(pre['prior_files'])} prior hashes and{len(pre['before_files'])}
before-work files are preserved.434 review and historical experiments are closed.

Candidate1's stale Wild-rejection fixture failure remains preserved. The explicit
120-order Wild/Flower Pot oracle replaces that obsolete expectation; candidate2
and the installed full gates are authoritative. No all-decisions-optimal,
near-never-unused-discards or improved population win-rate claim is made.
Release complete; stop after this delivery.
'''
write(EVAL/'SESSION_RESET_434.md',report);write(HERE/'INSTALLED_REPORT.md',report)
write(EVAL/'NEXT_PRIORITIES_434.md','''# Priorities434

Installed434/2.214 is complete. Read SESSION_RESET_434.md/.json and
development434/INSTALLED_VERIFICATION.json. Await user-started loaded evidence;
installation does not prove activation or effectiveness.434 review is exhausted;
historical experiments remain CLOSED. Do not resume an old lease or broad replay.

Compare future public loop/unsupported receipts and discard counts against the
preserved2.213 batch:4wins/4losses/1stall/1unsupported;510discards/1,939cards,
209full-five;28clears/57unused. The two retirement causes and a concrete rental
Blueprint funding omission are repaired. There is no causal win-rate estimate.

Remaining evidence-backed questions: early immediate survival versus future
rank-repeat value (Trio/Sly pack at10072); short final-round discard tradeoffs;
larger mixed-order/uncertain scoring families; budget-complete Acorn products;
whole-inventory consumable action planning and unsupported boss resources.
Per-size rejection receipts now distinguish admission failures from a shorter
best reported sample. Compact pack receipts still omit per-candidate full
finishing distributions; opening score conflicts alone do not prove dominance.

Respect preserved public-only observation, settings, DLLs, all tracked/untracked
work and original journals. No game control, saves/profiles, captured scorer or
policy execution, simulation or new experiment is authorized by this record.
Any future runtime edit needs a new exact combined freeze and candidate/installed
gates. Do not claim every suspicious action was a bug or every loss is fixed.
''')
write(EVAL/'ARCHITECTURE_MAP_434.md','''# Architecture434

ordering.supersedes_consumable identifies a selected independent scoring reorder
that replaced an earlier consumable proposal, including a Lucky-average order.
phase_copy.burnt allows that candidate past the stale proposal guard but separately
proves a reliable held finish and complete real discard effects. Already-arranged
Burnt issues the discard; chosen proposal presentation clears stale consumables.

acorn_belief qualifies canonical Campfire/Road before first scoring and subsequent
completed-action advancement. Road consumes an explicit visible nondebuff
non-Stone Jack count, grows once per physical Joker, and remains opaque to popup
identity filtering. acorn_public snapshots only visible selected playing cards
when that count is needed; acorn_discard supplies it for hypothetical transitions.
shop_scoring accepts canonical empty type/integral creation metadata for Road.

strategy admits focused copy reserve-funding sales even with capacity and an
affordable sticker. decision prequalifies the real sale-to-buy sequence within
the same shop context. Existing reserve, supported comparison and core guards
remain. player_journal exposes direct copy reserve/shortfall diagnostics.

growth extends exact canonical Joker/edition families and proves card-order
equivalence for a narrow Glass/identity product floor. Card-stage +Mult/Poly and
first-card-sensitive effects remain outside that theorem. Actual state/resource
checks and12-call cap remain. Green/Blue cannot claim neutral second-step utility;
hidden Road cannot claim identity-independent callbacks. Acorn product families
are still withheld. search/player_journal expose bounded overlapping per-size
rejection counts without exporting sampled hidden worlds.

Authoritative freezes repair434_candidate2 and repair434_installed share110
dependencies and360 test files; both full gates310Lua/458Python. Candidate1 failure
is preserved. Development434 analysis reads copied JSON/SQLite only. See REPORT.md
for action anchors, all flag categories, negative findings and limitations.
''')
prefix=f'''INSTALLED REVISION434 /2.214.0-alpha —{now()[:10]}
Read tools/advisor_eval/SESSION_RESET_434.md/.json, NEXT_PRIORITIES_434.md,
ARCHITECTURE_MAP_434.md and development434/REPORT.md, REVIEW.md,
INSTALLED_VERIFICATION.json. Candidate2 and exact-installed gates310Lua/458Python;
110 dependencies/360 frozen tests. Digest {digest}.
13 changed runtime files;94 deployed/94 backed; config/seven DLLs unchanged.
Repairs: Burnt stale-consumable/Lucky reorder loop; Campfire/Road Acorn continuity;
reserve-funded copy acquisition with capacity; canonical discard product/Joker
proofs; per-size rejection diagnostics; Road creation metadata support.
Latest preserved loaded2.213 session: development434/captures/001,27,925events,
4wins/4losses/1stall/1unsupported;10starts/10endings,no unended runs.
510discards/1,939cards;28clears left57discards. Actual2.214 improvement unconfirmed.
Fresh passive absence authorized deployment; no confirmation/normal-exit inference.
No game control, saves/profiles, original execution, captured replay, simulation,
experiment or automation.434review exhausted; historical experiments CLOSED.
No all-fixed or population win-rate claim. Release complete. Preserved history follows.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;prior=p.read_bytes();back=HERE/'navigation_before_install'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 assert file_digest(p)==pre['before_files'][rel],rel
 with back.open('xb')as f:f.write(prior)
 p.write_bytes(prefix.encode('utf-8')+prior);assert p.read_bytes().endswith(prior)
write(HERE/'git_status_installed.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
paths=[EVAL/'SESSION_RESET_434.md',EVAL/'SESSION_RESET_434.json',EVAL/'NEXT_PRIORITIES_434.md',EVAL/'ARCHITECTURE_MAP_434.md',
 HERE/'preinstall_verification.json',HERE/'installation.log',HERE/'FINAL_VERIFICATION.json',HERE/'final_changes.diff',
 HERE/'REVIEW.md',HERE/'REPORT.md',HERE/'INSTALLED_REPORT.md',CANDIDATE/'freeze.json',CANDIDATE/'validation/report.json',
 FINAL/'record.json',FINAL/'validation/report.json',capture/'manifest.json',capture/'summary.json']
verification={'verified_utc':now(),'version':'2.214.0-alpha','revision':434,'digest':digest,'counts':counts[0],
 'candidate_and_installed_gates_passed':True,'installed_runtime_exact':True,'config_preserved':True,'native_files_preserved':7,
 'deployed_paths':94,'backed_existing_paths':94,'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'public_segments_preserved':27,'public_bytes_preserved':public_bytes,'public_capture':str(capture),
 'public_outcomes':summary['outcomes'],'public_events':summary['events'],'normal_exit_inferred':False,
 'activation_confirmed':False,'passive_processes':current,'backup':str(backup),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}}
save(HERE/'INSTALLED_VERIFICATION.json',verification)
print(json.dumps({k:verification[k]for k in ('version','digest','counts','installed_runtime_exact','config_preserved','native_files_preserved','backup','passive_processes')},indent=2))
