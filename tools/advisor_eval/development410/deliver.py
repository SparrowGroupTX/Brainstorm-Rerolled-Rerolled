"""Verify candidate410 and publish factual, history-preserving navigation."""
from datetime import datetime,timezone
from pathlib import Path
import json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance

def write(path,text):
    with path.open('x',encoding='utf-8') as out:out.write(text)

candidate=EVAL/'runs/repair410_candidate1'
freeze=json.loads((candidate/'freeze.json').read_text())
gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text())
base=json.loads((EVAL/'SESSION_RESET_409.json').read_text());installed=Path(base['installed'])
assert gate['passed'] and gate['policy_unchanged'] and gate['tests_unchanged'] and gate['provenance_unchanged']
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']
for rel,sha in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==sha
assert policy_hashes(installed.parent)==base['policy_files']==pre['runtime_files']
for root in (ROOT/'Brainstorm',installed):
    assert {p.name:file_digest(p) for p in root.glob('*.dll')}==pre['native_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
assert file_digest(EVAL/'development409/final_verification.json')==pre['prior409_verification_sha256']
prior=json.loads((EVAL/'development409/final_verification.json').read_text())
prior_local={p:sha for p,sha in prior['artifact_hashes'].items() if p.startswith('tools/advisor_eval/development409/')}
for rel,sha in prior_local.items():assert file_digest(ROOT/rel)==sha,rel
allowed=set(freeze['changed_runtime_files'])|{'tests/advisor_runtime.lua'}
for rel,sha in pre['before_files'].items():
    assert file_digest(HERE/'before'/rel)==sha,rel
    if rel not in allowed:assert file_digest(ROOT/rel)==sha,rel
lua=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text())
assert lua and lua.group(1)==lua.group(2)=='275'
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/name).read_text()).group(1))
       for name in ('python.log','python_1.log','python_2.log'))
assert py==458
digest=freeze['candidate_policy_digest']
report=f'''# Repair410 — spend discards before clearing

Repository2.197.0-alpha is frozen at `runs/repair410_candidate1`, fully validated
and **not installed**. Digest `{digest}`. Six changed runtime files,109 total
runtime dependencies and321 declared test files are bound to the freeze.
Full gate:275 Lua fixtures and458 Python tests pass with unchanged runtime,
test and helper provenance. Installed runtime remains exact409 2.196.

The user revised an absolute rule to a strong preference with rare exceptions
and a below1% observed target. That preference supersedes historical wording that
unused discards are merely qualitative hypotheses. No observed rate is claimed.

The supported cause is reproducible without captured games: the previous clear
path could reject discards because it required105% of the target, positive growth
merit, a qualifying Yorick/Burnt/Death engine or future development horizon.
The manufactured before fixture fails the requested discard behavior.

Changes:

- Teacher clear paths request bounded discard exhaustion before optional stored
  development. A supported post-discard floor reaching100% is sufficient; generic
  profile behavior and ordinary optional-growth thresholds remain unchanged.
- Low/negative heuristic merit, mature distant Yorick growth and final-Boss
  horizon no longer veto a supported retained-clear discard. Each real draw
  requires fresh advice. A maximum spare discard wins equal-utility ties.
- Up to six singleton probes can free cards from an unnecessarily large clearing
  hand, within the same12-call allowance. They use a subset of the original play
  and preserve Glass, Arm, population-cost and supported finish-reward checks.
- A final guard follows phase-copy and retry arbitration and uses actual action
  indices. It respects the existing retry restrictions and one shared work
  allowance, including smaller caller caps and the70-call fast path.
- Public receipts distinguish selected discards, nonfinishing plays and explicit
  exceptions, including exact charged work. The panel explains remaining-discards
  exceptions, and Execute uses the same selected action/indices.

The new policy fixture passes57 checks; actual capture/presentation/Execute adds
13 checks (runtime total830). Positive cases cover all three remaining discards,
final Boss, exact target, empty deck, no growth engine and mature Yorick. Negative
controls cover ordinary profile, Green/Banner/Ramen score loss, paid current cash,
forced Bell selection, unsupported Purple generation, sole clearing card,
retry constraints, hidden/public worlds and caller budgets. Gold/Blue and Steel
retention and input determinism are exercised. See REVIEW.md and raw logs for
all initial failures, fixture corrections and the three focused-review repairs.

Limits: this does not force a discard that loses the supported clear. Acorn and
concealed-card paths have explicit public-model coverage exceptions, not proof
that finishing early is strategically correct. Other draw hazards, unavailable
mechanics, failed bounded candidates and exhausted work are also visible gaps.
A future cohort must adjudicate them; exception labels do not make them acceptable
or establish a rate below1%. The Yorick sale work from409 remains unpatched.

Measurement: count physically settled round-clearing plays in the teacher profile;
report the fraction whose linked pre-play public state had positive discards.
Also report rounds that began with usable discards separately from zero-discard
blinds. Join final receipts to the settled actions, categorize every numerator
event, retain unsupported/censored runs and show numerator/denominator. Claims of
below1% require loaded-game evidence and adequate coverage, not these fixtures.

No game control, active-journal read, installed/config/DLL change, save/profile
access, captured-state policy/scorer execution, experiment or cap increase.
Preservation:436 backed files, earlier409 local artifacts and all old git status
paths verified. Candidate remains uninstalled during user play. A later release
requires current normal-exit confirmation, passive absence, newer-public-journal
preservation/classification, exact preflight, backed explicit six-file install
and separate exact-installed freeze/full gate. Installation is not activation.
'''
write(HERE/'REPORT.md',report)
write(EVAL/'CANDIDATE_CHECKPOINT_410.md',f'''# Frozen410 candidate — 2.197.0-alpha

NOT installed. Installed remains exact2.196 checkpoint409.
Freeze: `runs/repair410_candidate1/freeze.json`; digest `{digest}`.
109 dependencies,6 changed runtime files,321 declared test files.
Full candidate gate275 Lua fixtures/458 Python tests passes with matching inputs.
Read development410/REPORT.md, REVIEW.md and FINAL_VERIFICATION.json.

Strong teacher discard-before-clear preference replaces optional-only heuristic
vetoes. Safety/public-model/budget exceptions remain visible. Below1% is a target,
not demonstrated behavior. No loaded2.197 evidence or win-rate claim exists.
Only release after current-session normal-exit confirmation, passive absence,
newer public-journal preservation/classification and exact preflight. Use the six
explicit changed_runtime_files from the freeze with install_slice.py2.197, retain
backup, freeze installed bytes and run the full installed gate. Do not reinstall
while a game runs. All mandatory full-resume boundaries remain.
''')
write(EVAL/'NEXT_PRIORITIES_410.md','''# Priorities after candidate410

1. Leave2.197 uninstalled during current play. After latest normal-exit confirmation,
   complete the exact backed release/full installed validation in CANDIDATE_CHECKPOINT_410.md.
2. Audit completed loaded sessions passively. Measure settled clears with unused
   discards against all settled teacher clears, with a separate eligible-round
   denominator. Inspect every exception; no below1% rate is established yet.
3. Public-model exceptions remain unresolved, especially Acorn/concealed worlds,
   draw-order/held-score hazards and bounded shortlist coverage. Do not mislabel
   model gaps as proven strategic exceptions or bypass concealed-information rules.
4. Yorick→Brainstorm trade valuation and durable Buffoon replacement admission
   remain as documented in development409/YORICK_FINDINGS.md. Invisible/pack/cash
   opportunity audits also remain; do not implement another slice automatically.

One source review and one focused recheck for410 are complete. No new experiment,
game control, captured-state evaluation or expanded score budget is authorized.
''')
write(EVAL/'ARCHITECTURE_MAP_410.md','''# Candidate410 navigation

- growth.lua: opt-in teacher exhaust_discards mode, supported retained floor,
  singleton subset anchors and existing transition/draw/resource protections.
- decision.lua: early clear preference and final discard_preference after copy/
  retry arbitration; hidden-Joker early return emits a public-model exception.
- player_journal.lua: compact_discard_before_clear copies bounded public scalars.
- runtime.lua: explicit exception line; selected growth controls existing display
  and Execute machinery. Runtime integration is appended to advisor_runtime.lua.
- tests/advisor_discard_before_clear410.lua:57 invented policy checks.
- development410/: baseline before/, prework, failures, targeted logs, review,
  freeze.py, deliver.py, REPORT.md and FINAL_VERIFICATION.json.
- runs/repair410_candidate1/: immutable policy/test bytes, freeze and full gate.

Installed409 remains2.196. No active journals or game engine were used as inputs.
All source paths above are under Brainstorm/Advisor; test paths are under tests.
''')
header=f'''FROZEN CANDIDATE410 — 2026-09-26
User requested spending discards before clearing, with rare exceptions and a
below1% observed target. Repository2.197 is frozen and full-validated, NOT installed.
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_410.md, NEXT_PRIORITIES_410.md,
ARCHITECTURE_MAP_410.md and development410/REPORT.md/REVIEW.md/FINAL_VERIFICATION.json.
Digest {digest};109 runtime dependencies,6 changed paths,321 tests;
275 Lua fixtures and458 Python tests pass with exact runtime/tests/provenance.
Strong teacher retained-clear discard preference removes heuristic merit/horizon
vetoes and uses supported100% floors, final-action checks and explicit exception
receipts. Existing score limits, physical population, Glass/resources, hidden
information and retry restrictions remain. No below1% exception rate or loaded
2.197 gain is demonstrated; public-model exceptions require later adjudication.
Installed remains exact2.196 checkpoint409. No active journals, game control,
save/profile access, captured replay, configuration/DLL change or new experiment.
Current normal exit is not confirmed. Release awaits current normal exit, passive
absence, new-public-log preservation, exact preflight, backed explicit install
and separate exact-installed freeze/full gate.410 review allowance is complete.
Stop this candidate slice; no automatic second repair. All full historical
preservation/execution/release requirements below remain mandatory.

'''
for rel in pre['navigation']:
    path=ROOT/rel;old=path.read_bytes();path.write_bytes(header.encode('utf-8')+old)
    assert path.read_bytes().endswith((HERE/'before'/rel).read_bytes())
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
old_paths={line[3:] for line in (HERE/'git_status_before.txt').read_text().splitlines() if line}
assert old_paths<={line[3:] for line in status.splitlines() if line}
(HERE/'git_status_after.txt').write_text(status,encoding='utf-8')
process=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
observed=json.loads(process.stdout) if process.stdout.strip() else []
assert policy_hashes(ROOT)==freeze['candidate_policy_files'] and policy_hashes(installed.parent)==base['policy_files']
assert test_manifest()==freeze['test_files'] and provenance()==freeze['validation_provenance']
paths=[p for p in HERE.glob('*') if p.is_file()]+[ROOT/rel for rel in pre['navigation']]+[
 EVAL/n for n in ('CANDIDATE_CHECKPOINT_410.md','NEXT_PRIORITIES_410.md','ARCHITECTURE_MAP_410.md')]+[
 candidate/'freeze.json',candidate/'validation/report.json']
verification={'verified_utc':datetime.now(timezone.utc).isoformat(),'candidate_version':'2.197.0-alpha',
 'candidate_digest':digest,'candidate_full_gate_passed':True,'lua_fixtures':275,'python_tests':458,
 'runtime_files':109,'changed_runtime_files':6,'test_files':321,'inputs_unchanged':True,
 'installed':'exact2.196 checkpoint409','installed_runtime_unchanged':True,'config_unchanged':True,
 'native_files_preserved':7,'backed_files_preserved':len(pre['before_files']),
 'prior409_local_artifacts_preserved':len(prior_local),'navigation_history_preserved':True,
 'prior_git_status_paths_preserved':True,'passive_processes':observed,'active_journals_read':False,
 'installation_performed':False,'normal_exit_confirmed':False,'new_experiment':False,
 'game_control':False,'saved_game_or_profile_access':False,'captured_state_policy_execution':False,
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in paths}}
write(HERE/'FINAL_VERIFICATION.json',json.dumps(verification,indent=2)+'\n')
print(json.dumps({k:verification[k] for k in ('candidate_version','candidate_digest','candidate_full_gate_passed','lua_fixtures','python_tests','installed_runtime_unchanged','passive_processes')}))
