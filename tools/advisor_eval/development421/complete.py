"""Verify exact421 candidate and preserved baseline before publication/release."""
from pathlib import Path
from datetime import datetime,timezone
import json,re,sys,difflib
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def save(p,v):
 with p.open('x',encoding='utf-8') as f:json.dump(v,f,indent=2);f.write('\n')
def write(p,s):
 with p.open('x',encoding='utf-8') as f:f.write(s)
candidate=EVAL/'runs/repair421_candidate2'
freeze=json.loads((candidate/'freeze.json').read_text());gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text());base=json.loads((EVAL/'SESSION_RESET_420.json').read_text());installed=Path(base['installed'])
assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==freeze['candidate_policy_files']==gate['policy_files']
assert test_manifest()==freeze['test_files']==gate['test_files']
assert provenance()==freeze['validation_provenance']==gate['validation_provenance']==pre['provenance']
assert policy_hashes(installed.parent)==base['policy_files']==pre['installed_runtime_files']
assert file_digest(installed/'config.lua')==pre['config_sha256']
for root in (installed,ROOT/'Brainstorm'):assert {p.name:file_digest(p) for p in root.glob('*.dll')}==pre['native_files']
for rel,sha in pre['prior_files'].items():assert file_digest(ROOT/rel)==sha,rel
assert file_digest(HERE/'SCOPE.md')==freeze['scope_sha256']
changed_tests={r for r,h in freeze['test_files'].items() if pre['test_files'].get(r)!=h}
assert changed_tests=={'tests/advisor_joker_plan421.lua','tests/advisor_joker_forecasts421.lua','tests/advisor_joker_decisions421.lua','tests/fixtures/joker_centers421.lua'}
allowed=set(freeze['changed_runtime_files'])|changed_tests
for rel,sha in pre['before_files'].items():
 assert file_digest(HERE/'before'/rel)==sha,rel
 if rel not in allowed:assert file_digest(ROOT/rel)==sha,rel
for rel,sha in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==sha
m=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text());assert m and m[1]==m[2]
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
counts={'lua_fixtures':int(m[1]),'python_tests':py};assert counts=={'lua_fixtures':294,'python_tests':458}
audit=json.loads((HERE/'catalog_audit.json').read_text());assert len(audit['rows'])==150
assert sum(not r['baseline_known'] for r in audit['rows'])==28
assert '1/1 fixtures passed' in (HERE/'baseline_regressions2.log').read_text()
diff=[]
for rel in sorted(allowed):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before421/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':421,'version':'2.205.0-alpha','status':'frozen_validated_not_installed',
 'candidate':candidate.relative_to(ROOT).as_posix(),'policy_digest':freeze['candidate_policy_digest'],'policy_files':freeze['candidate_policy_files'],
 'changed_runtime_files':freeze['changed_runtime_files'],'runtime_file_count':len(freeze['candidate_policy_files']),
 'test_files':freeze['test_files'],'test_file_count':len(freeze['test_files']),'changed_test_files':sorted(changed_tests),'validation_counts':counts,
 'installed_checkpoint':420,'installed_runtime_unchanged':True,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installation_authority':'tools/advisor_eval/INSTALLATION_POLICY.md','normal_exit_confirmation_required':False,
 'catalog_count':150,'previously_generic_unknown':28,'strategic_utilities_not_win_probabilities':True,
 'candidate_loaded_evidence':False,'all_contexts_optimal_claim':False,'game_control':False,'save_profile_access':False,
 'captured_policy_replay':False,'original_game_execution':False,'monitor_status':'prior_PAUSED','review_cycle_exhausted':True}
save(EVAL/'CANDIDATE_CHECKPOINT_421.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_421.md',f"# Candidate421 —2.205.0-alpha\n\nExact digest `{record['policy_digest']}`. Passed294 Lua fixtures/458 Python tests.\n110 runtime dependencies/343 frozen test files. Seven runtime changes.\nRead development421/REPORT.md, CATALOG.md, REVIEW.md, FINAL_VERIFICATION.json.\nInstalled remains420 until SESSION_RESET_421 confirms deployment.\nDynamic teacher Joker valuation, all150 catalog accounting, counters, discard\nconflicts and corrected owned/future synergy accounting. Bounded utilities,\nnot exact long-horizon optimization or demonstrated win-rate improvement.\nRelease uses INSTALLATION_POLICY.md without asking closure confirmation.\n")
write(EVAL/'NEXT_PRIORITIES_421.md',"""# Next priorities421

Check SESSION_RESET_421 for installation. Process absence is not normal-exit or
run-completion evidence. INSTALLATION_POLICY.md remains authoritative.

Future authorized public analysis: inspect actual2.205 Joker offers, hand mix,
inventory/Negative endpoints, candidates, admission, budgets, chosen action,
settled state and subsequent trajectory. Avoid hindsight optimality claims.
The new static utilities do not replace paired tactical scoring or prove that
every qualitative decision is optimal. Random triggers, alternate multi-step
hand plans and long-horizon causal win effects remain uncalibrated.

Old2.203 capture003 remains under development420; whole-cohort deep audit and
mixed-row discard proofs (Raised Fist, concealment, Idol/Scholar) remain open.
No new experiment or replay authority. Heartbeat stays paused. Stop this Joker
valuation delivery; additional runtime edits need a new exact combined gate.
""")
write(EVAL/'ARCHITECTURE_MAP_421.md',"""# Architecture delta421

- joker_plan.lua: pure teacher-only public hand-history/level mixture, embedded
  hand containment, scoring-card opportunity, owned rank/suit population,
  bounded trigger/growth value and actual counter strength. No score calls.
- runtime.lua wires that helper into strategy.lua. Strategy uses it before
  conditional/edition/sticker adjustments. Shared complete-row values include
  counter strength exactly once; copy-target strength remains explicit.
- strategy.lua fixes owned Negative Stencil capacity and retains only the
  owned portion of synergy forecasts in complete retained-row accounting.
- conditional_value.lua stops crediting no-discard payout to this teacher.
- synergies.lua corrects Needle spare hands, perishable cashout/lifetime and
  exposes owned_bonus separately. Sparse teacher populations discount combos.
- Three manufactured fixtures plus150 literal center metadata records cover
  static/endpoint/production decisions. No scorer/search/executor/budget edits.
""")
prefix=f"""FROZEN CANDIDATE421 —2026-09-27
2.205.0-alpha candidate validated:294 Lua/458 Python;110 dependencies/343 tests.
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_421.md/.json, NEXT_PRIORITIES_421.md,
ARCHITECTURE_MAP_421.md and development421/REPORT.md, CATALOG.md, REVIEW.md.
Digest {record['policy_digest']}. Check SESSION_RESET_421 for deployment;
candidate validation alone is not installation or activation.150 Joker identities
audited;28 formerly generic-unknown teacher ratings now explicit. Public hand mix,
repeated-rank containment, counters, discard strategy and synergy timing repaired.
Bounded heuristic utilities, no all-contexts-optimal or win-rate claim.
INSTALLATION_POLICY.md supersedes historical normal-exit confirmation requirements.
Preserve journals/settings/DLLs/history; no game control, saves/profiles, original
execution, captured replay or new experiment. Heartbeat stays PAUSED.
Review allowance exhausted for421. Earlier history follows.

"""
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;old=p.read_bytes();back=HERE/'navigation_before'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(old)
 p.write_bytes(prefix.encode()+old)
artifacts=[HERE/n for n in ('REPORT.md','REVIEW.md','CATALOG.md','catalog_audit.json','source_centers.json','baseline_regressions2.log')]+[candidate/'freeze.json',candidate/'validation/report.json']
save(HERE/'FINAL_VERIFICATION.json',{**record,'candidate_gate_passed':True,'counts':counts,'config_preserved':True,'native_files_preserved':7,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in artifacts},'final_diff_sha256':file_digest(HERE/'final_changes.diff')})
print(json.dumps({'digest':record['policy_digest'],'counts':counts,'prior_files':len(pre['prior_files']),'candidate_gate':True}))
