"""Verify the combined411 candidate and preserve prior navigation verbatim."""
from datetime import datetime,timezone
from pathlib import Path
import difflib,json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def write(path,text):
    with path.open('x',encoding='utf-8') as out:out.write(text)
candidate=EVAL/'runs/repair411_candidate1'
freeze=json.loads((candidate/'freeze.json').read_text())
gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text())
base=json.loads((EVAL/'SESSION_RESET_409.json').read_text());installed=Path(base['installed'])
assert gate['passed'] and gate['policy_unchanged'] and gate['tests_unchanged'] and gate['provenance_unchanged']
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']==pre['provenance']
for rel,sha in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==sha
assert policy_hashes(installed.parent)==base['policy_files']==pre['installed_runtime_files']
for root in (ROOT/'Brainstorm',installed):
    assert {p.name:file_digest(p) for p in root.glob('*.dll')}==pre['native_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
for rel,sha in pre['prior410_files'].items():assert file_digest(ROOT/rel)==sha,rel
changed={'Brainstorm/Advisor/strategy.lua','Brainstorm/Core/Brainstorm.lua','Brainstorm/steamodded_compat.lua',
 'tests/advisor_engine_retention381.lua','tests/advisor_blueprint_priority400.lua'}
for rel,sha in pre['before_files'].items():
    assert file_digest(HERE/'before'/rel)==sha,rel
    if rel not in changed:assert file_digest(ROOT/rel)==sha,rel
lua=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text())
assert lua and lua.group(1)==lua.group(2)=='276'
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/name).read_text()).group(1))
       for name in ('python.log','python_1.log','python_2.log'))
assert py==458
assert len(freeze['test_files'])==322 and len(freeze['candidate_policy_files'])==109
digest=freeze['candidate_policy_digest']
report=f'''# Repair411 — retain the last durable Yorick and Perkeo

Repository2.198.0-alpha is frozen at `runs/repair411_candidate1`, full-validated,
and **not installed**. It combines410's discard-before-clear work with411's
engine admission repairs. Installed remains exact2.196 checkpoint409.
Digest `{digest}`;109 runtime dependencies,7 changed paths relative to installed409,
322 declared test files. Full candidate gate:276 Lua fixtures and458 Python tests.

The preserved409 public trace showed a fulfilled Yorick-sale/Brainstorm-buy
sequence. It did not establish a scoring bug, a diverted purchase or an optimal
long-horizon trade. Source analysis found that any new core waived sequence
retention, and ordinary durable offers bypassed the direct/pack temporary guards.
An independently invented Perkeo pack/direct family reproduced the latter.
The new guard expresses the user's strong win-first engine preference; it does
not claim these fixtures establish a better population win rate.

Teacher-profile complete endpoints before the explicit final Boss retain at least
one active durable Yorick and Perkeo of each previously present kind, unless the
existing complete paired immediate-rescue certificate permits the loss. Blueprint,
Brainstorm and the other engine do not replace the missing kind. Rental remains
durable. Debuffed, permanently debuffed, concealed/unknown or Perishable cards do
not satisfy retained durable-engine coverage. Final-Boss, expired and ordinary
profile exceptions remain. Same-engine upgrades and duplicate replacements do not
fail merely because a different physical engine card was sold.

The complete sequence graph, ordinary purchase and pack endpoints use this shared
invariant. Public direct and pack receipts preserve the named rejection reason
`last_durable_engine_guard`; older temporary guards retain their specific reasons.
The guard itself adds no scoring. Existing four-world, cash, survival and work
limits remain; a bounded current-blind rescue is not a future-run guarantee.

The focused Blueprint path also excluded every engine victim by key. It now can
spend an expendable duplicate while retaining a usable durable source. Ordinary
Yorick ratings actually mark its sale unsupported; this was not a universal
direct-Yorick-sale vulnerability. A narrow duplicate-Yorick path is available in
focused copy shops and revealed copy packs only with complete supported copy
evidence. Its pack failure was separately manufactured before repair. Ordinary
unsupported Yorick replacement remains outside that path.

New411 fixture:93 checks, including actual sequence graph rejection, direct/pack
arbitration, serialized reasons, invalid rescue controls, duplicate/upgrade/final
Boss/expired/rental cases, and production scorer/finisher Blueprint selection on
an invented deck.381 retains all29 paired-ranking checks with a unique retained
duplicate Perkeo and physical-ID victim matching; sole-engine early controls
remain.400's old core-sale negative had created a duplicate; it now explicitly
tests a last-engine sale. No test was dropped to preserve an obsolete policy.
See REVIEW.md and raw logs for reviewer findings and fixture corrections.

Limits: no new loaded-game evidence or measured win-rate gain. Neither50% wins nor
below1% unused-discard clears is established. The current user session was at6/10
when work was authorized; active journals were not read. More general long-horizon
valuation, ordinary replacement followup commitments, unseen pack opportunities,
Invisible Joker and discard public-model gaps remain future audit topics.

Preservation:435 backed files,903 prior410 files, every previous git-status path,
installed runtime/settings and seven DLLs. No game control, save/profile access,
captured-state policy/scorer evaluation, new experiment or scoring-cap increase.
No installation while Balatro runs. Later release requires current normal-exit
confirmation, passive absence, newer public-journal preservation/classification,
exact preflight, backed explicit seven-file install and separate exact-installed
freeze/full gate. Installation alone does not prove activation.
'''
write(HERE/'REPORT.md',report)
write(EVAL/'CANDIDATE_CHECKPOINT_411.md',f'''# Frozen411 candidate — 2.198.0-alpha

NOT installed. Installed remains exact2.196 checkpoint409. This candidate combines
410's discard preference and411's last-engine/duplicate-copy repairs. Immutable
410 remains preserved as a prior candidate; use this combined freeze for release.
Freeze `runs/repair411_candidate1/freeze.json`; digest `{digest}`.
109 runtime dependencies,7 changed paths,322 tests;276 Lua/458 Python tests pass
with exact runtime, tests and helper provenance. Read development411/REPORT.md,
REVIEW.md, FINAL_VERIFICATION.json and current NEXT_PRIORITIES/ARCHITECTURE_MAP411.

No active-journal read, gameplay control or installed/config/DLL change. No loaded
2.197/2.198 result, win-rate gain or below1% unused-discard rate is established.
Release after current-session normal-exit confirmation and passive absence, then
preserve/classify newer public logs and verify exact inputs. Use the freeze's
seven explicit changed_runtime_files with install_slice.py2.198, retain backup,
freeze exact installed bytes and run the separate full installed gate. Do not
install into a running game. The full ADVISOR_RESUME_PROMPT.md remains mandatory.
''')
write(EVAL/'NEXT_PRIORITIES_411.md','''# Priorities after candidate411

1. Leave combined2.198 uninstalled while the user's session runs. Later normal exit,
   passive absence, preservation and exact release requirements are in checkpoint411.
2. Audit the completed loaded session only after it ends. Separate labels/physical
   actions/settlement/outcomes and censored segments; this session cannot evidence
   uninstalled2.197 or2.198 behavior. Include engine sales and qualitative flags.
3. Once the candidate is actually loaded, measure every settled clearing play with
   unused discards over all teacher clears, separately retaining an eligible-round
   denominator. Adjudicate public-model exceptions, particularly Acorn/concealment.
4. Review ordinary replacement followup commitments and next-observation reranking,
   Invisible Joker opportunities, weaker pack choices and future-copy liquidity.
   Generic unsupported Yorick replacement remains outside the narrow duplicate-copy
   path; complete long-horizon valuation is still heuristic.

411 received one substantive source review and one focused recheck by the same
read-only reviewer. Stop this slice after delivery. No automatic experiment,
captured-state replay, cap increase or new repair is authorized by this document.
''')
write(EVAL/'ARCHITECTURE_MAP_411.md','''# Candidate411 navigation

- Brainstorm/Advisor/strategy.lua: active_durable/retained_engine and shared
  last_engine_admission; direct and complete sequence endpoints; old temporary
  guards accept retained duplicate engines; focused duplicate copy victims and
  supported revealed-pack copy sale; named replacement-admission receipts.
- tests/advisor_last_engine411.lua:93 invented policy/arbitration/proof checks,
  including a real scorer/finisher case.381 paired-ranking fixtures now use an
  Eternal retained duplicate and physical IDs;400 keeps a true sole-engine control.
- development411/: scope,435-file before backup, prework, raw failures/targeted
  logs, review diff/notes, freeze/deliver helpers, report and final verification.
- runs/repair411_candidate1/: exact combined policy/test bytes and full validation.
- Candidate410 and all development410 evidence remain immutable; its map documents
  the included growth/decision/journal/runtime discard-before-clear work.
- Installed remains SESSION_RESET_409.json 2.196; no current journal was inspected.
''')
header=f'''FROZEN COMBINED CANDIDATE411 — 2026-09-26
Repository2.198 is frozen/full-validated, NOT installed. Read tools/advisor_eval/
CANDIDATE_CHECKPOINT_411.md, NEXT_PRIORITIES_411.md, ARCHITECTURE_MAP_411.md and
development411/REPORT.md/REVIEW.md/FINAL_VERIFICATION.json before historical maps.
Digest {digest};109 dependencies,7 changed runtime paths,322 tests;
276 Lua fixtures/458 Python tests pass with exact inputs. Includes410's discard
preference plus last-durable-Yorick/Perkeo endpoint protection. New copy Jokers do
not waive underlying-engine loss; duplicate copy acquisition has bounded complete
evidence requirements. Current frozen410 and all older histories remain preserved.
Installed stays exact2.196 checkpoint409; active session/journals are untouched.
No loaded2.197/2.198 gain,50% win rate or below1% unused-discard rate is established.
Release awaits current normal exit, passive absence, newer-public-log preservation,
exact preflight, explicit backed seven-file install and full exact-installed gate.
411 review allowance is complete. Stop this slice; all full historical execution,
preservation, experiment and release requirements below remain mandatory.

'''
for rel in pre['navigation']:
    path=ROOT/rel;old=path.read_bytes();path.write_bytes(header.encode('utf-8')+old)
    assert path.read_bytes().endswith((HERE/'before'/rel).read_bytes())
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
old_paths={line[3:] for line in (HERE/'git_status_before.txt').read_text().splitlines() if line}
assert old_paths<={line[3:] for line in status.splitlines() if line}
write(HERE/'git_status_after.txt',status)
diff=[]
for rel in sorted(changed|{'tests/advisor_last_engine411.lua'}):
    before=HERE/'before'/rel
    diff.extend(difflib.unified_diff(before.read_text().splitlines(True) if before.exists() else [],
                (ROOT/rel).read_text().splitlines(True),fromfile='before/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
process=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
observed=json.loads(process.stdout) if process.stdout.strip() else []
assert policy_hashes(ROOT)==freeze['candidate_policy_files'] and policy_hashes(installed.parent)==base['policy_files']
assert test_manifest()==freeze['test_files'] and provenance()==freeze['validation_provenance']
paths=[p for p in HERE.glob('*') if p.is_file()]+[ROOT/rel for rel in pre['navigation']]+[
 EVAL/n for n in ('CANDIDATE_CHECKPOINT_411.md','NEXT_PRIORITIES_411.md','ARCHITECTURE_MAP_411.md')]+[
 candidate/'freeze.json',candidate/'validation/report.json']
verification={'verified_utc':datetime.now(timezone.utc).isoformat(),'candidate_version':'2.198.0-alpha',
 'candidate_digest':digest,'candidate_full_gate_passed':True,'lua_fixtures':276,'python_tests':458,
 'runtime_files':109,'changed_runtime_files':7,'test_files':322,'inputs_unchanged':True,
 'installed':'exact2.196 checkpoint409','installed_runtime_unchanged':True,'config_unchanged':True,
 'native_files_preserved':7,'backed_files_preserved':len(pre['before_files']),
 'prior410_files_preserved':len(pre['prior410_files']),'navigation_history_preserved':True,
 'prior_git_status_paths_preserved':True,'passive_processes':observed,'active_journals_read':False,
 'installation_performed':False,'normal_exit_confirmed':False,'new_experiment':False,
 'game_control':False,'saved_game_or_profile_access':False,'captured_state_policy_execution':False,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in paths}}
write(HERE/'FINAL_VERIFICATION.json',json.dumps(verification,indent=2)+'\n')
print(json.dumps({k:verification[k] for k in ('candidate_version','candidate_digest','candidate_full_gate_passed','lua_fixtures','python_tests','installed_runtime_unchanged','passive_processes')}))
