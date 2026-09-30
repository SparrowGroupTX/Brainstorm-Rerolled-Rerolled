"""Seal a validated candidate while preserving active installation and history."""
from pathlib import Path
from datetime import datetime,timezone
import json,re,sys,subprocess
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,t):
 with p.open('x',encoding='utf-8')as f:f.write(t)
candidate=EVAL/'runs/repair438_candidate1';freeze=read(candidate/'freeze.json');gate=read(candidate/'validation/report.json')
base=read(EVAL/'INSTALLED_CHECKPOINT_437.json');pre=read(HERE/'prework.json');installed=Path(base['installed'])
assert all(gate[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']
for rel,h in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==h,rel
for rel,h in freeze['evaluation_helpers'].items():assert file_digest(ROOT/rel)==file_digest(candidate/'helpers'/rel)==h,rel
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h,rel
assert file_digest(HERE/'SCOPE.md')==freeze['scope_sha256']
assert policy_hashes(installed.parent)==base['policy_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
for root in (ROOT/'Brainstorm',installed):assert {p.name:file_digest(p)for p in root.glob('*.dll')}==pre['native_files']
lua=(candidate/'validation/lua.log').read_text(encoding='utf-8')
m=re.search(r'(\d+)/(\d+) fixtures passed',lua);assert m and m[1]==m[2]=='319'
python=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/name).read_text(encoding='utf-8'))[1])
 for name in ('python.log','python_1.log','python_2.log'));assert python==458
for label,count in [('Retained two438',404),('Heart Bell438',336),('Acorn adapter438',185)]:
 assert f'{label}: {count} checks passed' in lua
r=subprocess.run(['pwsh','-NoProfile','-Command',"@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(r.stdout)if r.stdout.strip()else[]
branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
assert branch=='codex/exact-search-speedups'
now=datetime.now(timezone.utc).isoformat();digest=freeze['candidate_policy_digest']
receipt={'created_utc':now,'revision':438,'candidate_version':'2.217.0-alpha','candidate':candidate.relative_to(ROOT).as_posix(),
 'candidate_policy_digest':digest,'candidate_policy_files':gate['policy_files'],'candidate_installed':False,
 'changed_from_installed437':freeze['changed_from_installed437'],'runtime_dependencies':110,'test_files':len(gate['test_files']),
 'lua_fixtures':319,'python_tests':458,'new_manufactured_assertions':925,'installed':str(installed),
 'installed_version':base['version'],'installed_release':437,'installed_policy_digest':base['policy_digest'],
 'installed_unchanged':True,'config_unchanged':True,'native_files_preserved':7,'preserved_prior_files':len(pre['prior_files']),
 'evaluation_helpers':freeze['evaluation_helpers'],'review_exhausted':True,'new_experiment':False,
 'historical_experiments':'CLOSED','new_loaded_candidate_evidence':False,'discard_benchmark_verified':False,
 'game_control':False,'save_profile_access':False,'original_journals_modified':False,'passive_processes':processes,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,'branch':branch}
save(EVAL/'CANDIDATE_CHECKPOINT_438.json',receipt);save(EVAL/'SESSION_RESET_438.json',receipt)
report=f'''# Candidate438 / 2.217.0-alpha

Four supported remaining causes are repaired and manufactured-tested. Exact
combined candidate passes319 Lua fixtures /458 Python tests, including925 new
assertions.110 runtime dependencies /370 frozen test files. Digest `{digest}`.
NOT INSTALLED:437 /2.216 is byte-identical; settings and seven DLLs are preserved.
Passive journals confirm the user's current loaded label is2.216. Balatro process
at completion: `{processes}`. No process was controlled or normal exit inferred.

Runtime repairs:

* A marginal same-hand clear beside canonical Blue Joker/Yorick can now reserve
  two disjoint visible singleton/Pair anchors. Both real draw-count debits and
  the first-play transition are charged. Every order pair clears, including
  first-hand Glass destruction; no favorable replacement identity is assumed.
  Gold/Blue/Steel/Purple held resources and inventory survive, actual final hand
  category stays the same, and the extra hand reward/action cost is reported.
  Up to6 of the same12 growth calls are reserved for this narrow proof; at least4
  remain for the original one-hand path. Comfortable clears keep their original
  allocation. Only the immediate discard is proposed; fresh advice is required.
* Heart now supports fifteen canonical conditional Chips/Mult/XMult Jokers in
  debuff switching, including Clever. Modified/missing fields or hidden identities
  fail closed; resource fields remain neutral. Expiry and old-debuff eligibility
  ordering stay intact.
* Public receipts identify selected or rejected two-play proof, budget, minimum,
  both draw charges, Glass exposure and extra play cost.

Detached tooling repairs:

* Bell refill supplies its own deterministic forced-card channel, mapped to the
  actual post-draw hand size and preserved through sorting; both action kinds
  still require that physical card.
* Acorn retains one private sampled permutation from the complete public belief.
  Only redacted slots and public inventory enter Decision. Physical actions must
  match separately advanced public abilities; reorders update both views. Missing
  or mismatched public slot counts, removal, divergent mutations and consumable
  transitions remain unsupported. Popup-based belief filtering is not modeled;
  retaining more worlds is conservative. No private row is exported in receipts.

Evidence: tests/advisor_retained_two438.lua (404 checks), advisor_heart_bell438.lua
(336), advisor_acorn_adapter438.lua (185). The first exhausts15 manufactured draw
sets x both orders of each pair x both Glass outcomes (120 physical continuations),
checks budget limits, resource hazards, actual Decision and compact journal wiring.
The Acorn integration exercises play/discard/reorder/play with physical Yorick,
Road, Green, Burnt and copy effects, duplicate entries, poisoned hidden payloads,
unsupported transitions and actual public-belief Decision. These are constructed
unit scenarios, not captured runs, random game batches or population evidence.

Preserved failures: target1/acorn2 expected a one-action clear, but the actual
teacher correctly used its available discard. The corrected test explicitly
checks that discard and separately checks a clear when no discards remain.
Review438 found and closed Stone/Blue category and stale Acorn slot-count defects.
See REVIEW.md; its one assessment and focused recheck are exhausted.

Remaining limits: the two-play certificate covers canonical small anchors beside
a near-target Blue/Yorick clear on Small/Big/Vessel. More general long-horizon
survival/growth tradeoffs and broader resource/ordering families are not solved.
The closed437 experiment remains unchanged:6 completed rounds averaged10.17 cards
against12;4 unsupported attempts. It was NOT rerun, and there is no new discard
benchmark or improved loaded-game win-rate claim.

All {len(pre['prior_files'])} prior artifact hashes and before-work copies verified.
Active journals, saves/profiles and installed runtime were not modified. Any later
installation requires fresh successful passive process absence, latest journals
preserved, explicit backed six-file install_slice and exact-installed full gate.
No normal-exit confirmation question. New captured evaluations need prospective
authorization and caps; every historical experiment remains CLOSED.
'''
write(HERE/'REPORT.md',report);write(EVAL/'CANDIDATE_CHECKPOINT_438.md',report);write(EVAL/'SESSION_RESET_438.md',report)
write(EVAL/'NEXT_PRIORITIES_438.md','''# Priorities438

Combined2.217 is exact-frozen/full-gate validated, not installed while user plays.
Preserve newest journals before explicit backed installation and exact-installed
gate; fresh passive absence is sufficient, without a closure confirmation.

Four concrete causes are repaired; runtime discard coverage remains narrow.
Inspect later public two_play receipts for admission, complete order coverage,
both draw charges, budget use, resource refusals and settled action. Distinguish
same-hand from two-play floors. Next evidence-backed questions are broader
retained anchor/ordering families and survival versus longer Yorick growth paths.
Goad short discards and failing Vessel continuation remain unresolved comparisons,
not proved suboptimal actions. Do not force five at the expense of supported wins.

Bell/Acorn tooling is newly qualified on manufactured inputs, not retrospectively
applied to closed437 attempts. Acorn popup filtering and consumable transitions
remain unsupported. Any new captured experiment requires fresh prospective scope,
caps and authorization. All historical leases stay closed; review438 exhausted.
No loaded2.217 benefit or12-card average has been established.
''')
write(EVAL/'ARCHITECTURE_MAP_438.md','''# Architecture438

growth.two_play_plan admits a narrow canonical marginal Blue/Yorick clear;
suggest_portfolio reserves its complete order-family cost inside12. Existing
one-hand suggestions retain priority when discarding as many cards. The new
retained_two_play applies after_discard, charges unknown draw counts, applies
after_play with all original Glass broken, debits the second draw and lower-bounds
the disjoint same-category final hand in every selected order. The fixed supported
row makes Glass survival subsets equivalent for that final score; no tally effect
is admitted. Extra action/cash cost is explicit; only current discard is returned.
decision/player_journal identify the two-play certificate and bounded receipts.

scoring.after_draw qualifies canonical typed Joker keys/fields using the existing
lucky_shape definitions before changing Heart debuffs. No arbitrary resource
fields are newly admitted. continuation_adapter.refill uses a separate Bell roll.
For Acorn, canonical ignores raw hidden payloads but preserves public slot count;
run samples and retains a private belief permutation, materializes only for raw
transitions, validates against advance_public, then redacts before Decision and
receipts. Reorder updates public worlds and private mapping. No popup refinement.

Six changed runtime files (four modules/two version stamps); one changed detached
adapter; three new manufactured fixtures. Candidate repair438_candidate1 binds
110 dependencies,370 test files and exact helper/provenance hashes. No game,
captured-policy or original-source execution; no installation in this slice.
''')
prefix=f'''FROZEN CANDIDATE438 /2.217.0-alpha —{now[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_438.md/.json, SESSION_RESET_438.md/.json,
NEXT_PRIORITIES_438.md, ARCHITECTURE_MAP_438.md and development438/REPORT.md,
REVIEW.md, FINAL_VERIFICATION.json.319Lua/458Python;925 new manufactured assertions;
110 runtime dependencies/370 test files. Digest {digest}.
NOT INSTALLED:437/2.216 remains exact; user is playing, loaded label confirmed.
Repairs: bounded retained-two-play discard floor; canonical Heart conditional
Jokers; Bell forced-card adapter stream; separate private/public Acorn transitions.
Preserves12/70/ordinary caps, inventories, settings and seven DLLs. Future actions
require fresh observations. Narrow proof scope; all discard gaps are NOT solved.
No new captured experiment or benchmark/win-rate claim. Historical experiments
CLOSED;438 review exhausted. Installation follows INSTALLATION_POLICY.md.
Earlier candidate/installation records below are preserved history.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;assert file_digest(p)==pre['before_files'][rel],rel
 prior=p.read_bytes();p.write_bytes(prefix.encode('utf-8')+prior);assert p.read_bytes().endswith(prior)
paths=[EVAL/'CANDIDATE_CHECKPOINT_438.md',EVAL/'CANDIDATE_CHECKPOINT_438.json',EVAL/'SESSION_RESET_438.md',
 EVAL/'SESSION_RESET_438.json',EVAL/'NEXT_PRIORITIES_438.md',EVAL/'ARCHITECTURE_MAP_438.md',HERE/'REPORT.md',
 HERE/'REVIEW.md',HERE/'SCOPE.md',HERE/'PASSIVE_STATUS.json',candidate/'freeze.json',candidate/'validation/report.json']
receipt['artifact_hashes']={p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}
save(HERE/'FINAL_VERIFICATION.json',receipt)
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:receipt[k]for k in ('candidate_version','candidate_policy_digest','lua_fixtures','python_tests','new_manufactured_assertions','installed_unchanged','passive_processes')}))
