"""Verify installed2.198 revision412 and write history-preserving navigation."""
from pathlib import Path
from datetime import datetime
import difflib,json,re,subprocess
from release import HERE,EVAL,ROOT,CANDIDATE,FINAL,exact,journals,save,now,processes
from benchmark import file_digest,policy_hashes
def write(path,value):
    with path.open('x',encoding='utf-8') as f:f.write(value)
base,installed,frozen,pre=exact(True)
observed=processes()
for p in observed if isinstance(observed,list) else [observed]:
    assert datetime.fromisoformat(p['StartTime']).timestamp()>(FINAL/'validation/report.json').stat().st_mtime
manifest=journals(False);public=json.loads((HERE/'public_classification.json').read_text())
counts=[]
for directory in (CANDIDATE,FINAL):
    gate=json.loads((directory/'validation/report.json').read_text())
    assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
    assert gate['policy_files']==frozen['candidate_policy_files'] and gate['test_files']==frozen['test_files']
    assert gate['validation_provenance']==frozen['validation_provenance']
    m=re.search(r'(\d+)/(\d+) fixtures passed',(directory/'validation/lua.log').read_text());assert m and m[1]==m[2]
    py=sum(int(re.search(r'Ran (\d+) tests',(directory/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
    counts.append({'lua_fixtures':int(m[1]),'python_tests':py})
assert counts==[{'lua_fixtures':277,'python_tests':458}]*2
record=json.loads((FINAL/'record.json').read_text());backup=Path(record['installation']['backup'])
assert policy_hashes(FINAL/'policy')==frozen['candidate_policy_files']==record['policy_files']
deployment=json.loads((backup/'deployment.json').read_text(encoding='utf-8-sig'))
deployed={};changed=[]
for row in deployment['files']:
    rel=row['path'].replace('\\','/')
    assert file_digest(backup/rel)==row['before'].lower()==base['deployment_files'][rel]
    assert file_digest(installed/rel)==row['after'].lower()==frozen['candidate_policy_files']['Brainstorm/'+rel]
    deployed[rel]=row['after'].lower()
    if row['before'].lower()!=row['after'].lower():changed.append('Brainstorm/'+rel)
assert len(deployed)==93 and set(changed)==set(frozen['changed_runtime_files'])
for rel,sha in pre['before_files'].items():
    assert file_digest(HERE/'before'/rel)==sha
    if rel!='Brainstorm/Advisor/strategy.lua':assert file_digest(ROOT/rel)==sha,rel
digest=frozen['candidate_policy_digest']
checkpoint={'version':'2.198.0-alpha','revision':412,'installed_at':record['installation']['installedAt'],
 'installed':str(installed),'backup':str(backup),'policy_digest':digest,'policy_files':frozen['candidate_policy_files'],
 'deployment_files':deployed,'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
 'runtime_file_count':109,'deployment_file_count':93,'changed_runtime_files':sorted(changed),
 'candidate_validation':str(CANDIDATE/'validation/report.json'),'installed_validation':str(FINAL/'validation/report.json'),
 'validation_counts':counts[0],'frozen_test_file_count':323,
 'latest_public_loaded_label':'2.196.0-alpha','latest_public_profile':'perkeo_yorick_win_v1',
 'latest_public_session':manifest['session'],'latest_public_capture_last_sequence':public['events'],
 'latest_public_capture_complete_batch':True,'latest_public_starts':10,'latest_public_recorded_outcomes':public['outcomes'],
 'latest_public_deep_audit_complete':False,'latest_public_manifest_sha256':file_digest(HERE/'capture/manifest.json'),
 'normal_exit_confirmation_sha256':file_digest(HERE/'normal_exit_confirmation.json'),
 'activation':'Unconfirmed; installation is not loaded-game evidence','post_gate_processes':observed,
 'native_or_config_changed':False,'game_process_control':False,'saved_game_or_profile_access':False}
save(EVAL/'SESSION_RESET_412.json',checkpoint)
report=f'''# Installed revision412 — 2.198.0-alpha

The user's corrected Perkeo policy is installed together with410's discard-before-
clear preference and411's Yorick/duplicate-copy repairs. Authoritative freeze:
`runs/repair412_candidate2`; exact installed freeze: `runs/repair412_installed`.
Digest `{digest}`. Both full gates pass277 Lua fixtures/458 Python tests with
unchanged runtime/tests/provenance.109 dependencies,323 declared tests,7 changed
runtime paths,93 deployment/backup paths. Settings and7 DLLs are unchanged.
Backup: `{backup}`. Earlier411 also used2.198 but was never installed; its digest
and artifacts remain immutable. This412 digest is the released2.198 candidate.

Perkeo may now fund a new durable Blueprint or Brainstorm before the final Boss
when an original active durable scaled Yorick remains and the declared supported
ordering makes the new copy resolve to it. Existing complete paired-copy evidence
requires a material score gain, four clearing endpoint worlds, supported mechanics,
no paired progress regression and enough actual cash for the existing reserve.
Unknown/debuffed/temporary targets or copies, cycles, illegal pinned reorders,
already-owned copies and missing/incomplete evidence do not waive the guard.
Sole-Yorick preservation remains. Existing immediate-rescue and final-Boss rules
also remain. This is a bounded proof, not a full-run guarantee.

Focused enumeration now includes a prospective Perkeo trade and checks its full
endpoint before publishing a sale. Qualified pack exchanges can outweigh Perkeo's
future-copy utility. Held consumables, including Negative stock, are retained;
their presence alone is not a veto. Other retained-inventory valuation remains.
Before a pack sale, fresh vacant-row ranking must select the same physical copy
with complete supported evidence within the same cap; a competing choice or
incomplete proof rejects the sale. Direct/pack public receipts name
`perkeo_yorick_copy_exchange` and retain physical
victim/offer IDs. Ordinary generic Yorick sale rating remains unsupported outside
the already qualified duplicate/sequence routes.

New412 fixture:80 checks. It tests both copies through direct/pack/complete graph/
focused arbitration, fresh sale-to-buy advice, public reasons, held stock, bad
targets/orders/proofs/cash and exhausted work. Production scorer/finisher selects
both exchanges on invented cards. Two-offer pack controls reproduce and fix the
reviewed sale-to-different-choice discontinuity. Existing411,400,381,404,408 targeted regressions
pass unchanged. No captured public state entered a policy or scorer.

Before edits or installation, all27 public BRJ2 segments were copied to
`development412/logs1` (55,896,334 bytes), SHA256 matched against originals, then
decoded with a verified continuous chain:23,156 events, ten starts and ten recorded
endings (4 win/6 loss), no unended run. Public loaded label is2.196, not2.198.
These are indexed recorded outcomes; deeper strategy/terminal corroboration is
pending. No causal gain, population win rate or below1% unused-discard rate is
claimed. The copy is outside the game's clearable log directory and remains safe
when the user clears logs for the next session. Originals were not erased.

Release uses the user's current own-exit statement and explicit installation
request, plus passive absence before/after installation. No game launch/control,
save/profile access, new experiment, score-cap change or automation. Installation
does not establish activation. Further log review can use only the immutable copy
while another user-started session runs. Full historical boundaries remain.
'''
write(HERE/'REPORT.md',report);write(EVAL/'SESSION_RESET_412.md',report)
write(EVAL/'NEXT_PRIORITIES_412.md','''# Priorities after installed412

1. User may start the next ten-run session.2.198 revision412 is installed and both
   full gates passed; do not reinstall or read active journals during play.
2. Deeply audit the preserved2.196 marathon under development412/logs1 and its
   events.sqlite3. Ten recorded outcomes (4 win/6 loss) are indexed, not fully
   strategy-audited. Follow suspect decisions through settlement and later effects.
3. After a later normal session exit, preserve its logs before clear and establish
   loaded2.198 evidence. Measure unused-discard clears and adjudicate exceptions;
   assess Perkeo/Yorick/copy trades, weak pack choices and Invisible opportunities.
4. Broader future-run value and ordinary replacement followup commitments remain
   heuristic/incomplete. No below1% exception rate or win-rate target is proven.

412's one substantive review and one focused recheck are complete. Stop this
coherent release; no new experiments, captured-policy replay or higher caps.
''')
write(EVAL/'ARCHITECTURE_MAP_412.md','''# Installed412 navigation

- strategy.lua: factored supported_copy_evidence; perkeo_copy_exchange resolves a
  declared four-sample order to an original retained Yorick; endpoint admission,
  focused enumeration and pack copy priority; named direct/pack receipt reason.
- tests/advisor_perkeo_copy412.lua:80 independently invented checks; all411 tests
  retained.410 discard work and411 last-Yorick/duplicate-copy work remain combined.
- development412/logs1 and capture/: immutable public marathon backup/chain index.
  events.sqlite3 is decoded public data only; deep strategy audit remains pending.
- development412/: prework436-file backup, prior411895-file preservation manifest,
  raw failures, targeted logs, review, release/complete helpers, final verification.
- runs/repair412_candidate2 and repair412_installed: exact freeze and both gates.
- SESSION_RESET_412.json is authoritative.411's differently hashed2.198 candidate
  was never installed and is retained as history. No loaded2.198 evidence yet.
''')
header=f'''INSTALLED REVISION412 — 2026-09-26
2.198.0-alpha is installed, including the user's Perkeo-for-Yorick-copy correction.
Read tools/advisor_eval/SESSION_RESET_412.md/.json, NEXT_PRIORITIES_412.md,
ARCHITECTURE_MAP_412.md and development412/REPORT.md/REVIEW.md/FINAL_VERIFICATION.json.
Digest {digest};109 dependencies,7 changed files,93 deployment/backup paths,
323 tests. Candidate and exact-installed gates pass277 Lua/458 Python tests.
Settings and7 DLLs preserved. Earlier411's different2.198 freeze was never installed.
All27 public segments (55,896,334 bytes) are safe in development412/logs1, outside
the game's clearable directory.23,156 events form a verified chain; ten starts,
4 recorded wins/6 losses, no unended run, public label2.196. Deep audit pending.
User reported own exit and authorized this release. No game control or save/profile
access. New user play is permitted; do not inspect its active logs or reinstall.
Perkeo can fund a qualified new copy of retained Yorick; sole-Yorick guard remains.
No loaded2.198 gain,50% win-rate or below1% unused-discard rate is established.
Stop this release slice; all historical preservation/execution boundaries remain.

'''
for rel in pre['navigation']:
    path=ROOT/rel;old=path.read_bytes();path.write_bytes(header.encode()+old)
    assert path.read_bytes().endswith((HERE/'before'/rel).read_bytes())
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
before_paths={line[3:] for line in (HERE/'git_status_before.txt').read_text().splitlines() if line}
assert before_paths<={line[3:] for line in status.splitlines() if line}
write(HERE/'git_status_after.txt',status)
paths=[p for p in HERE.glob('*') if p.is_file()]+[HERE/'capture/manifest.json',HERE/'capture/verification.json',
 CANDIDATE/'freeze.json',CANDIDATE/'validation/report.json',FINAL/'record.json',FINAL/'validation/report.json']
paths.extend(ROOT/rel for rel in pre['navigation'])
paths.extend(EVAL/n for n in ('SESSION_RESET_412.json','SESSION_RESET_412.md','NEXT_PRIORITIES_412.md','ARCHITECTURE_MAP_412.md'))
save(HERE/'FINAL_VERIFICATION.json',{'verified_utc':now(),'version':'2.198.0-alpha','revision':412,'digest':digest,
 'candidate_and_installed_gates_passed':True,'counts':counts[0],'installed_runtime_exact':True,
 'config_preserved':True,'native_files_preserved':7,'deployed_and_backed_paths':93,'prior411_files_preserved':895,
 'before_files_preserved':436,'public_segments_preserved':27,'public_bytes_preserved':manifest['total_bytes'],
 'normal_exit_confirmed':True,'passive_processes':observed,'activation_confirmed':False,
 'deep_public_audit_complete':False,'game_control':False,'save_profile_access':False,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in paths}})
print(json.dumps({'installed':'2.198.0-alpha','revision':412,'digest':digest,'gates':counts[0],'public_segments_saved':27,'backup':str(backup)}))
