"""Seal the exact candidate and preserve history before any installation."""
from pathlib import Path
from datetime import datetime, timezone
import json, re, subprocess, sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def write(p,t):
 with p.open('x',encoding='utf-8')as f:f.write(t)
candidate=EVAL/'runs/repair440_candidate3';freeze=read(candidate/'freeze.json');gate=read(candidate/'validation/report.json')
base=read(EVAL/'INSTALLED_CHECKPOINT_437.json');pre=read(HERE/'prework.json');installed=Path(base['installed'])
assert all(gate[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']
assert len(gate['policy_files'])==110 and len(gate['test_files'])==372
for rel,h in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==h,rel
for rel,h in freeze['evaluation_helpers'].items():assert file_digest(ROOT/rel)==file_digest(candidate/'helpers'/rel)==h,rel
assert freeze['evaluation_helpers']==read(EVAL/'runs/repair438_candidate1/freeze.json')['evaluation_helpers']
for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h,rel
assert file_digest(HERE/'SCOPE.md')==freeze['scope_sha256']
assert policy_hashes(installed.parent)==base['policy_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
for root in (ROOT/'Brainstorm',installed):assert {p.name:file_digest(p)for p in root.glob('*.dll')}==pre['native_files']
lua=(candidate/'validation/lua.log').read_text(encoding='utf-8')
m=re.search(r'(\d+)/(\d+) fixtures passed',lua);assert m and m[1]==m[2]=='321'
python=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/name).read_text(encoding='utf-8'))[1])for name in ('python.log','python_1.log','python_2.log'));assert python==458
for label,count in [('Discard admission440',2799),('Matador inert440',170)]:assert f'{label}: {count} checks passed'in lua
assert 'Focused recheck: the blocker is resolved' in (HERE/'REVIEW.md').read_text()
ps=subprocess.run(['pwsh','-NoProfile','-Command',"@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout)if ps.stdout.strip()else[]
branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip();assert branch=='codex/exact-search-speedups'
now=datetime.now(timezone.utc).isoformat();digest=freeze['candidate_policy_digest']
receipt={'created_utc':now,'revision':440,'candidate_version':'2.218.0-alpha','candidate':candidate.relative_to(ROOT).as_posix(),
 'candidate_policy_digest':digest,'candidate_policy_files':gate['policy_files'],'candidate_installed':False,
 'changed_from_installed437':freeze['changed_from_installed437'],'runtime_dependencies':110,'test_files':372,
 'lua_fixtures':321,'python_tests':458,'new_manufactured_assertions':2969,'installed':str(installed),
 'installed_version':base['version'],'installed_release':437,'installed_policy_digest':base['policy_digest'],
 'installed_unchanged':True,'config_unchanged':True,'native_files_preserved':7,'preserved_prior_files':len(pre['prior_files']),
 'evaluation_helpers':freeze['evaluation_helpers'],'review_exhausted':True,'new_experiment':False,
 'historical_experiments':'CLOSED','new_loaded_candidate_evidence':False,'discard_benchmark_verified':False,
 'game_control':False,'save_profile_access':False,'original_journals_modified':False,'passive_processes':processes,
 'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,'branch':branch}
save(EVAL/'CANDIDATE_CHECKPOINT_440.json',receipt);save(EVAL/'SESSION_RESET_440.json',receipt)
report=f'''# Repair440 / candidate2.218.0-alpha

The supported discard-admission causes are repaired and manufactured-tested.
Final candidate3 passes321 Lua fixtures and458 Python tests, including2969 new
assertions. It freezes110 runtime dependencies and372 test files. Digest:
`{digest}`. This candidate record is written before deployment; a later
INSTALLED_CHECKPOINT_440 supersedes only its installation status.

The previous20-round experiment439 remains CLOSED and unchanged. Its17 complete
rounds averaged11.1765 discarded cards against12.7059 required; three additional
attempts had censored final Matador resource transitions. The later actual loaded
2.216 run6/round12 zero-discard Flush is preserved separately: observation16439,
advice16441, request16444, callback16445, settled observation16449/link16451.
Photograph/Chad and two Glass cards hit a sorting/progress-admission gap. That
captured state was not rerun, rescored or added to the20-round cohort in440.

Repairs and their evidence:

* Mature Yorick no longer automatically skips the ordinary sampled comparison
  above x8. Explicit fast_clear still works. Mature/final comparisons need all
  of at least24 completed common-world samples to clear with a105% minimum
  sampled margin, plus existing legal/resource/continuation gates. Bell must
  discard its current forced card and reevaluate forced selection after draws.
* Canonical scoring enhancements, Red seal and canonical editions no longer erase
  physical Yorick discard progress. Gold/Steel, Blue/Purple/Gold seals, unknown
  fields, paid transitions and population loss retain their guards. Final-boss
  progress credit expresses the user's discard preference, not future income.
* A smaller fully qualified batch can bypass the decaying growth-utility hurdle
  when five cards fail the survival check. The real invented Photo/Chad Glass
  fixture preserves a Flush and discards four spares. Five-card failures remain
  rejected; sample coverage is not a guarantee about the next actual draw.
* A sampled short choice now checks for a larger supported retained one-play
  discard using the remaining shared12-call allowance. This specific comparison
  disables two-play generation/reservation, so an extra-hand finish cannot hide
  the one-play option. General retained two-play behavior remains intact.
* Canonical Matador is physically inert on Small/Big/Needle/Leaf with an empty
  debuff table. Static vanilla source reads show trigger reset and no payout;
  manufactured copied/editioned rows preserve actual counters/inventory/cash.
  Other triggering, disabled or modified cases remain unsupported. No source
  code was executed and no Matador payout was invented.

Tests: admission440 has2799 checks, Matador_inert440 has170. New evidence includes
real Decision/scoring for6/12-card final Bell and the invented9-card Glass Flush,
legal forced-card reselection, failed/partial worlds, strict mature/final margins,
protected resources, ordinary/fast caps, continuation loss and the competing
one-play/two-play arbitration regression. Wild/Lucky are helper-qualified but do
not each have dedicated new production integration coverage. Shared caps remain
140000 ordinary,50000 shop,25000 consumable,70 fast-clear and12 growth. Mature
comparison uses ordinary search; the fast-clear cap itself was not raised.

Candidate1's gate failed on a real sampled-small versus retained-larger regression
and an outdated Bell expectation. Candidate2 passed but review found the two-play
reservation defect. Candidate3 resolves it and passes the full gate. All earlier
freezes and logs remain preserved. See REVIEW.md for the exhausted single
assessment/focused recheck and legacy expectation migrations.

Combined bytes include the previously uninstalled438 retained-two-play and Heart
runtime repairs. The qualified detached Bell/Acorn helpers are unchanged from438.
Seven runtime files differ from installed437: five advisor modules and two version
stamps. No unrelated work is included. All {len(pre['prior_files'])} prior hashes and
before-work copies, installed437, settings and seven DLLs verified unchanged at
candidate completion. Passive process snapshot: `{processes}`. No normal exit
is inferred. Latest journals must be preserved before installation; recheck passive
absence immediately before the explicit backed install_slice and installed gate.

Remaining limits: some resource/order/unknown rows can still decline discards;
retained deterministic Bell is still excluded, last-hand progress is unchanged,
other Matador triggers and Lucky-with-Matador remain unsupported. This repair
provides no new20-round average,12-card benchmark success, complete-game result
or improved loaded-game win rate. New captured evaluation needs fresh prospective
scope/caps/authorization. All historical experiment budgets remain CLOSED.
'''
write(HERE/'REPORT.md',report);write(EVAL/'CANDIDATE_CHECKPOINT_440.md',report);write(EVAL/'SESSION_RESET_440.md',report)
write(EVAL/'NEXT_PRIORITIES_440.md','''# Priorities440

Candidate3 /2.218 is exact-frozen and fully validated; check INSTALLED_CHECKPOINT_440
if present for the subsequent deployment. Preserve current public journals and use
fresh passive absence for installation; never request normal-exit confirmation.

Follow public advice through search proposals, by-size refusal counters, final
arbitration and actual settlement. New risk receipts distinguish mature/final
scope, safe small batches and retained larger-batch overrides. Sampled draws are
not deterministic proofs. Do not call a discard optimal solely from card count.

The closed439 benchmark remains unmet; it was not rerun in440. Verify actual
loaded2.218 identity and compare remaining zero/short-discard causes before
selecting another bounded repair. Remaining candidates include last-hand progress,
broader resource/order rows, and qualified Matador trigger/Lucky continuations.
No broad simulator gap or full-game win-rate claim is justified. Any new captured
evaluation requires prospective hypothesis, counts/workers/time/compute caps,
fresh authority and a one-use ledger. All historical experiments are CLOSED.
Review440 is exhausted; stop after this coherent delivery.
''')
write(EVAL/'ARCHITECTURE_MAP_440.md','''# Architecture440

Decision's Yorick comparison eligibility admits finite mature multipliers through
1048576 on the ordinary search path; explicit fast_clear remains authoritative.
Search.yorick_disposable qualifies canonical scoring enhancements/Red/editions,
protecting held/generation resources and rejecting unknown fields. The progress
bonus may use a one-unit final horizon only beside an existing risky-clear
comparison. Mature/final comparisons require complete24+ all-clear samples and
105% minimum score. safe_batch_preference extends only the old utility exception
to smaller batches; legal/transition/resource/survival/continuation guards stay.

Decision.discard_preference checks a sampled short incumbent against an existing
retained clear. Its remaining shared12-call allowance flows to suggest_portfolio
with disable_burnt_setup and disable_two_play. growth skips two-play generation
and reservation only when that option is true. A larger one-play proposal can
override the sample; final risk stamps prevent falsely claiming the Search
incumbent was executed. player_journal emits the bounded new flags.

scoring.after_play qualifies inert canonical Matador on Small/Big/Needle/Leaf
using empty blind debuff state and the existing neutral Joker shape checker.
Static source trigger-reset evidence is recorded in development440. Other cases
remain unsupported, including current sampled Lucky-with-Matador paths.

Combined seven-file runtime delta from installed437 includes inherited438 growth,
Heart and public-receipt changes; detached Bell/Acorn helpers match438 exactly.
Candidate3 binds110 runtime dependencies,372 test files and helper/provenance
hashes.321 Lua fixtures/458 Python tests. No captured-policy execution in440.
''')
prefix=f'''FROZEN CANDIDATE440 /2.218.0-alpha —{now[:10]}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_440.md/.json, SESSION_RESET_440.md/.json,
NEXT_PRIORITIES_440.md, ARCHITECTURE_MAP_440.md and development440/REPORT.md,
REVIEW.md, FINAL_VERIFICATION.json.321Lua/458Python;2969 new manufactured assertions;
110 runtime dependencies/372 test files. Digest {digest}.
Candidate3 fixes mature/final sampled admission, upgraded-card progress, safe
smaller batches, retained larger-batch arbitration and narrowly inert Matador.
Combined438 repairs included; all work/budget/resource limits preserved.
Installed437/2.216 exact at candidate completion; a later INSTALLED_CHECKPOINT_440
supersedes deployment status. All discard gaps and the12-card benchmark are NOT
solved. No new captured evaluations or loaded win-rate evidence. Review440
exhausted; historical experiments CLOSED. Installation: INSTALLATION_POLICY.md.
Earlier records below are preserved history.

'''
for rel in pre['navigation']:
 if rel.endswith('INSTALLATION_POLICY.md'):continue
 p=ROOT/rel;assert file_digest(p)==pre['before_files'][rel],rel
 prior=p.read_bytes();p.write_bytes(prefix.encode('utf-8')+prior);assert p.read_bytes().endswith(prior)
paths=[EVAL/f'{stem}_440.{ext}'for stem,ext in [('CANDIDATE_CHECKPOINT','md'),('CANDIDATE_CHECKPOINT','json'),('SESSION_RESET','md'),('SESSION_RESET','json'),('NEXT_PRIORITIES','md'),('ARCHITECTURE_MAP','md')]]
paths += [HERE/name for name in ('REPORT.md','REVIEW.md','SCOPE.md','MATADOR_SOURCE_READ.json','BLIND_SOURCE_READ.json')]
paths += [candidate/'freeze.json',candidate/'validation/report.json']
receipt['artifact_hashes']={p.relative_to(ROOT).as_posix():file_digest(p)for p in paths}
save(HERE/'FINAL_VERIFICATION.json',receipt)
write(HERE/'git_status_after.txt',subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout)
print(json.dumps({k:receipt[k]for k in ('candidate_version','candidate_policy_digest','lua_fixtures','python_tests','new_manufactured_assertions','installed_unchanged','passive_processes')}))
