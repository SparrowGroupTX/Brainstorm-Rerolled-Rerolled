from pathlib import Path
import json,sys
from datetime import datetime,timezone
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2);f.write('\n')
freeze=read(EVAL/'runs/repair436_candidate2/freeze.json');gate=read(EVAL/'runs/repair436_candidate2/validation/report.json')
pre=read(HERE/'prework.json');base=read(EVAL/'SESSION_RESET_434.json')
assert gate['passed'] and gate['test_files']==test_manifest()
assert policy_hashes(ROOT)==freeze['candidate_policy_files']==gate['policy_files']
assert policy_hashes(Path(base['installed']).parent)==base['policy_files']
assert file_digest(Path(base['installed'])/'config.lua')==pre['config_sha256']
for name,h in pre['native_files'].items():assert file_digest(Path(base['installed'])/name)==h
for rel,h in freeze['evaluation_helpers'].items():assert file_digest(ROOT/rel)==h
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':436,'version':'2.215.0-alpha',
 'status':'validated_candidate_not_installed','policy_digest':gate['policy_digest'],'policy_files':gate['policy_files'],
 'candidate':'tools/advisor_eval/runs/repair436_candidate2','lua_fixtures':314,'python_tests':458,
 'tests':len(gate['test_files']),'evaluation_helpers':freeze['evaluation_helpers'],
 'installed_release':434,'installed_version':base['version'],'installed_unchanged':True,
 'review_exhausted':True,'captured_evaluation_performed':False,'game_process_observed':42508,
 'new_user_scope':'437 discard-policy repair and separately preregistered ten targeted continuations'}
save(HERE/'FINAL_VERIFICATION.json',record);save(EVAL/'CANDIDATE_CHECKPOINT_436.json',record)
(HERE/'REVIEW.md').write_text('''# Review436 complete

One technical assessment and one focused recheck by the same read-only reviewer;
allocation exhausted. Reviewer executed no tests/captured states/original code.
The focused review found missing conditional Joker type fields could become
unconditional multipliers. Required type/chip/mult fields and hidden markers now
fail closed, with negative controls. It also found cached Stencil XMult stayed
stale after Seltzer expiry; current physical capacity now drives Stencil scoring.
A two-play source-shaped fixture checks X4 then X5. No remaining blocker found.
Complete conditional samples remain model evidence, never guarantees/win rates.
''',encoding='utf-8')
(HERE/'REPORT.md').write_text('''# Repair436 candidate

2.215 is frozen and passes314 Lua fixtures/458 Python tests;110 runtime
dependencies/365 frozen test files. Not installed: Balatro42508 remains running.

Owned Lucky sampling now supports a qualified canonical deterministic Joker row,
including the five-Joker family that censored435, shared copy/retrigger counts,
exact conditional cash and physical Lucky Cat growth. Public selection still uses
public score estimates; private outcomes resolve only after action selection.
Typed uncertainty survives suppressed warning text; unrelated effects fail closed.
Stencil refreshes its multiplier after physical row expiry.

Final-action receipts distinguish an impossible clear from an unresolved range,
using at most one additional upper-bound check inside existing12/ordinary caps.
Detached graph-frame export preserves full finishing certificates and aliases;
the future adapter retains structured unsupported warnings rather than table
addresses. Historical435 results/runner and all earlier artifacts remain intact.

291 new manufactured checks across four fixtures cover arithmetic/transitions,
owned shop integration/cache/budget, final-action receipts and complete export.
The first full gate exposed an obsolete historical instrumentation assumption:
mixed newline matching and new additive typed metadata. The fixture normalizes
line endings and compares its original semantic output surface; all3402 arithmetic
and work checks remain, and the typed channel has separate negative tests.
Candidate2 passed every gate. The command's trailing PowerShell log redirection
was malformed after validation completed; report.json and per-group logs confirm
the successful gate. No test was rerun merely to recreate that console wrapper.

No captured evaluations, simulations, original gameplay execution, saves/profiles,
game control or installation occurred. Long-horizon comparisons remain incomplete.
The newer user request creates scope437: repair demonstrated discard admission,
then exactly ten targeted round continuations against4*available-discard benchmark.
''',encoding='utf-8')
prefix='''VALIDATED CANDIDATE436 /2.215 —2026-09-28
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_436.md/.json and development436/REPORT.md,
REVIEW.md, FINAL_VERIFICATION.json.314Lua/458Python;110 runtime/365 test files.
Owned-Lucky conditional transitions, exact Stencil expiry scoring, honest clear
receipts and complete bounded evidence export. NOT INSTALLED;434/2.214 unchanged.
Balatro42508 running; no game control/captured evaluation/original execution.
436 review exhausted.435 and all earlier experiments remain CLOSED.
New user instruction now authorizes scope437 discard repair and TEN TARGETED
ROUND CONTINUATIONS, benchmark4 cards per available discard; see development437/SCOPE.md.
No claim of target achievement or loaded-game win-rate improvement.

'''
(EVAL/'CANDIDATE_CHECKPOINT_436.md').write_text(prefix,encoding='utf-8')
(EVAL/'NEXT_PRIORITIES_436.md').write_text('Complete the new user-directed437 scope. Do not reopen435. Whole-game reward/shop/Perkeo transitions remain unqualified. Current2.215 candidate is not installed.\n',encoding='utf-8')
(EVAL/'ARCHITECTURE_MAP_436.md').write_text('scoring.sampled_lucky_plan shares repetition_count with score; sampled_outcomes supplies private conditional events. blind_finishing and shop_scoring use typed uncertainty admission. phase_copy samples the actual ordered row. decision records bounded ceiling support via player_journal. Detached continuation_evidence emits/restores full bounded graphs; continuation_adapter.run_frames is future-use tooling, with no launcher/authorization.\n',encoding='utf-8')
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;p.write_bytes(prefix.encode()+p.read_bytes())
print(json.dumps(record|{'policy_files':'omitted'}))
