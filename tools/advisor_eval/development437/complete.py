"""Seal truthful results/preservation and navigation; no further evaluation."""
from pathlib import Path
from datetime import datetime,timezone
import json,sys,subprocess
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
pre=read(HERE/'prework.json');base=read(EVAL/'SESSION_RESET_434.json');candidate=EVAL/'runs/repair437_candidate2'
freeze=read(candidate/'freeze.json');gate=read(candidate/'validation/report.json');closed=read(HERE/'CLOSED.json');results=read(HERE/'RESULTS.json')
assert closed['remaining_authority']==0 and closed['registered']==closed['received']==10
assert gate['passed']and test_manifest()==gate['test_files']and provenance()==gate['validation_provenance']
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==gate['policy_files']
installed=Path(base['installed']);assert policy_hashes(installed.parent)==base['policy_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
assert {p.name:file_digest(p)for p in installed.glob('*.dll')}==pre['native_files']
for rel,h in freeze['evaluation_helpers'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h,rel
manifest=read(HERE/'manifest.json')
for rel,h in manifest['files'].items():assert file_digest(HERE/rel)==h,rel
for rel,h in manifest['source_files'].items():assert file_digest(Path(rel))==h,rel
claims=list((HERE/'ledger').glob('*.started.json'));workers=list((HERE/'ledger').glob('*.worker.json'))
assert len(claims)==len(workers)==10
receipt={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':437,'candidate_version':'2.216.0-alpha',
 'candidate_policy_digest':gate['policy_digest'],'candidate_policy_files':gate['policy_files'],
 'candidate':'tools/advisor_eval/runs/repair437_candidate2','runtime_dependencies':110,'test_files':len(gate['test_files']),
 'lua_fixtures':316,'python_tests':458,'runner_control_tests':6,'installed':str(installed),'installed_version':base['version'],
 'installed_release':434,'installed_policy_digest':base['policy_digest'],'installed_unchanged':True,'candidate_installed':False,
 'preserved_prior_files':len(pre['prior_files']),'review_exhausted':True,'experiment_closed':True,'remaining_authority':0,
 'experiment_manifest_sha256':file_digest(HERE/'manifest.json'),'ten_results_sha256':file_digest(HERE/'RESULTS.json'),
 'experiment_seconds':closed['elapsed_seconds'],'summed_child_seconds':sum(read(p)['seconds']for p in(HERE/'results').glob('*.json')),
 'results':{k:v for k,v in results.items()if k!='rows'},'new_loaded_game_evidence':False}
save(HERE/'FINAL_VERIFICATION.json',receipt);save(EVAL/'CANDIDATE_CHECKPOINT_437.json',receipt);save(EVAL/'SESSION_RESET_437.json',receipt)
(HERE/'REPORT.md').write_text('''# Discard repairs and ten targeted continuations

The discard benchmark was not met. Ten registered continuations produced five
modeled clears, one modeled failure and four unsupported attempts. Six completed
rounds discarded61 cards against72 required:10.17 cards per round,4.07 per used
discard. One completed Violet Vessel round used no discards and left all three.
The unsupported attempts remain in the ten-case report; their prefixes do not
establish completed-round averages. No population win rate is demonstrated.

The combined2.216 candidate is frozen and passes316 Lua fixtures,458 Python tests
and six manufactured runner controls. It includes436's owned-Lucky conditional
transitions, exact Stencil expiry scoring, honest clear receipts and complete
bounded graph export.437 preserves a full-five option in the capped continuation
family and protects teacher Yorick's prior winning paths against a crossed-world
play-now override that omits later discards. Budgets and survival checks remain.
The actual Search regression demonstrates a weaker-immediate five that wins over
two plays; old admission omitted it. The suspected equal-value override was
disproved: its existing gain threshold already retains the discard.

The experiment used four workers, ten one-use jobs,16 actions per continuation,
40seconds per child,400 reserved child-seconds and600 overall seconds. Actual
elapsed12.828seconds, summed child time42.829seconds. No retry/replacement,
unregistered captured evaluations, full games, original gameplay execution,
saves/profiles or live game control. All unused capacity is permanently closed.
See EXPERIMENT_REPORT.md and RESULTS.json for all ten outcomes and action receipts.

The selected round in each archived run was fixed independently of new policy
outcomes. Preliminary deal-time observations were preserved under
preliminary_selection1, then replaced BEFORE execution by each same round's first
visible untouched observation. Acorn cases stayed registered and explicitly stop
before any unqualified hidden-Joker transition. Policy-first tests ensure no
forced opening and no private future order entering policy input.

Remaining issues:

1. The zero-discard Vessel case's selected Pair scores1,201,200 against1,200,000.
   It uses Mult-before-Glass, Yorick/Brainstorm and Blue Joker. Discarding/drawing
   reduces Blue Joker's contribution enough to invalidate that same one-hand
   retained floor. Five candidate proofs consume the12-score allowance; the clear
   shortcut then returns play and skips general specialists. A second held pair
   suggests a useful two-play retained certificate, but this is not yet qualified.
   Do not claim that increasing the budget or forcing five is a sound repair.
2. Goad discarded4/4/3 and cleared (one card below target). Vessel discarded3/3/4
   and failed at495,075/1,200,000 (two below target). Current comparisons omit later
   discard choices and have limited horizon. Their exact growth/survival tradeoff
   remains unresolved; one modeled loss does not label every earlier action wrong.
3. Crimson Heart stopped on Clever Joker's debuff-resource transition. Its name
   is omitted from after_draw's supported-resource guard, despite ordinary scoring
   support. Extend only a source-shaped, tested conditional-Joker family.
4. The detached refill adapter omits Bell's required sampled forced-card argument.
   This is an adapter support defect, not proof that the live product stalled.
5. Concealed Acorn Joker-belief advancement remains unqualified in this adapter;
   the two attempts were censored before transitions, never modeled as inert backs.

Installed434/2.214 is unchanged. Balatro42508 remained active; the candidate was
not installed. Review437 is exhausted. The next useful code slice is the bounded
retained-two-play discard proof plus targeted adapter qualification. Any later
captured experiment needs new prospective authorization/caps;437 cannot be resumed.
''',encoding='utf-8')
prefix='''FROZEN CANDIDATE437 + CLOSED TEN-ROUND TEST —2026-09-28
Read tools/advisor_eval/SESSION_RESET_437.md/.json, CANDIDATE_CHECKPOINT_437.md/.json,
NEXT_PRIORITIES_437.md, ARCHITECTURE_MAP_437.md and development437/REPORT.md,
EXPERIMENT_REPORT.md, RESULTS.json, CLOSED.json, FINAL_VERIFICATION.json.
Combined2.216 passed316Lua/458Python/6runner controls;110 runtime/367 frozen tests.
NOT INSTALLED:434/2.214 unchanged, Balatro42508 active. Five-card continuation
admission and owned-Yorick crossed-world protection added atop436's repairs.
Ten targeted rounds:5 modeled clears,1 failure,4 unsupported. Completed6 averaged
10.17 cards/round against12;61/72cards,15/18discards used. Benchmark NOT met.
One Vessel clear left all3discards; retained-two-play planning remains missing.
Other gaps: Heart/Clever debuff, adapter Bell draw, Acorn belief transitions.
No loaded-game improvement/population win-rate claim.437review exhausted and
all unused experiment capacity permanently CLOSED; no retries or automatic rerun.
Preserved earlier history follows.

'''
for name in ('SESSION_RESET_437.md','CANDIDATE_CHECKPOINT_437.md'):(EVAL/name).write_text(prefix,encoding='utf-8')
(EVAL/'NEXT_PRIORITIES_437.md').write_text('''# Priorities after closed437

First qualify a bounded retained-two-play discard certificate. The Vessel clear
at source26399 loses its same-hand floor after Blue Joker draw debits; Growth
spends12 and the clear shortcut skips specialists despite five hands remaining.
Use manufactured disjoint-pair states, exact Glass/copy/Yorick/Blue transitions,
population/cash preservation, all held resources, adverse draws and shared caps.
Do not replay437's captured state or renew its closed10-attempt allowance.

Then qualify canonical conditional-Joker Heart debuff transitions and supply a
separate deterministic Bell forced-card stream in detached refill. Hidden Acorn
belief transitions need public belief advancement, not inert redacted Jokers.
All four unsupported437 attempts remain visible. Goad/Vessel short-discard
survival-versus-growth tradeoffs and long-horizon economy remain unresolved.

2.216 is validated but not installed while Balatro runs. Preserve latest journals
and use fresh process absence plus exact-installed validation before deployment;
no normal-exit confirmation question. No population win-rate or all-fixed claim.
''',encoding='utf-8')
(EVAL/'ARCHITECTURE_MAP_437.md').write_text('''# Architecture437

Runtime: search.resource_discard_candidates admits at most3 discard branches
alongside play, preserving actual prior/ranked leader and reserving best five in
the teacher scope. resource_override_supported applies the existing per-world
check to active teacher Yorick when >1 discard remains. Both keep existing caps.
See436 map for shared Lucky repetition/shape/uncertainty and full graph export.

Detached tooling: continuation_adapter.run uses policy_first for unforced first
Decision; run_frames preserves full certificates, and hidden Joker rows censor
before a transition. Development437 freezes exact modules/wiring/DLL/input/world
mapping. run.py exclusive parent/worker claims and CLOSED enforce ten one-use
jobs/four workers/40seconds per job. evidence_reader restores bounded full graphs.
analyze.py is passive; complete.py checks all exact artifacts and preserves history.
All experiment files are CLOSED; new simulations must not invoke its runner.
''',encoding='utf-8')
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;assert p.read_bytes().endswith((HERE/'before'/rel).read_bytes())
 p.write_bytes(prefix.encode()+p.read_bytes())
with(HERE/'git_status_after.txt').open('x',encoding='utf-8')as f:f.write(subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:v for k,v in receipt.items()if k!='candidate_policy_files'}))
