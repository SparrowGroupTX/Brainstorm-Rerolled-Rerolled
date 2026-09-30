"""Verify exact423 candidate, preserve prior work and publish current navigation."""
from pathlib import Path
from datetime import datetime,timezone
import difflib,json,re,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def save(path,value):
 with path.open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
def write(path,value):
 with path.open('x',encoding='utf-8') as f:f.write(value)
candidate=EVAL/'runs/repair423_candidate2'
freeze=json.loads((candidate/'freeze.json').read_text());gate=json.loads((candidate/'validation/report.json').read_text())
pre=json.loads((HERE/'prework.json').read_text());base=json.loads((EVAL/'SESSION_RESET_421.json').read_text());installed=Path(base['installed'])
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
assert changed_tests=={'tests/advisor_discard_order423.lua','tests/advisor_perkeo_sources423.lua','tests/advisor_shop_alignment419.lua','tests/advisor_perkeo_exit414.lua','tests/advisor_runtime.lua'}
allowed=set(freeze['changed_runtime_files'])|changed_tests
for rel,sha in pre['before_files'].items():
 assert file_digest(HERE/'before'/rel)==sha,rel
 if rel not in allowed:assert file_digest(ROOT/rel)==sha,rel
for rel,sha in freeze['test_files'].items():assert file_digest(candidate/'tests_source'/rel)==sha
for capture in sorted((HERE/'captures').iterdir()):
 manifest=json.loads((capture/'manifest.json').read_text());summary=json.loads((capture/'summary.json').read_text())
 assert not summary['errors']
 for row in manifest['segments']:assert file_digest(capture/'logs'/row['name'])==row['sha256']
 assert file_digest(capture/'events.sqlite3')==summary['database_sha256']
m=re.search(r'(\d+)/(\d+) fixtures passed',(candidate/'validation/lua.log').read_text());assert m and m[1]==m[2]
py=sum(int(re.search(r'Ran (\d+) tests',(candidate/'validation'/n).read_text())[1]) for n in ('python.log','python_1.log','python_2.log'))
counts={'lua_fixtures':int(m[1]),'python_tests':py};assert counts=={'lua_fixtures':296,'python_tests':458}
ps=subprocess.run(['pwsh','-NoProfile','-Command',"@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
processes=json.loads(ps.stdout) if ps.stdout.strip() else []
branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
assert branch=='codex/exact-search-speedups',branch
status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
write(HERE/'git_status_after.txt',status)
diff=[]
for rel in sorted(allowed):
 old=HERE/'before'/rel
 diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],(ROOT/rel).read_text().splitlines(True),fromfile='before423/'+rel,tofile=rel))
write(HERE/'final_changes.diff',''.join(diff))
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':423,'version':'2.206.0-alpha','status':'frozen_validated_not_installed',
 'candidate':candidate.relative_to(ROOT).as_posix(),'policy_digest':freeze['candidate_policy_digest'],'policy_files':freeze['candidate_policy_files'],
 'changed_runtime_files':freeze['changed_runtime_files'],'runtime_file_count':len(freeze['candidate_policy_files']),
 'test_files':freeze['test_files'],'test_file_count':len(freeze['test_files']),'changed_test_files':sorted(changed_tests),'validation_counts':counts,
 'installed_checkpoint':421,'installed_runtime_unchanged':True,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installation_authority':'tools/advisor_eval/INSTALLATION_POLICY.md','normal_exit_confirmation_required':False,
 'process_check_successful':True,'processes':processes,'normal_exit_inferred':False,
 'candidate_loaded_evidence':False,'win_rate_claim':False,'unused_discards_below_one_percent_demonstrated':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,'original_game_execution':False,
 'automation_created':False,'historical_experiment_allowances':'CLOSED','review_cycle_exhausted':True,'branch':branch}
save(EVAL/'CANDIDATE_CHECKPOINT_423.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_423.md',f"# Candidate423 —2.206.0-alpha\n\nExact digest `{record['policy_digest']}`. Passed296 Lua fixtures/458 Python tests.\n110 runtime dependencies/345 frozen test files; six runtime changes.\nNot installed. Installed remains421/2.205; process was present at verification.\nRead development423/REPORT.md, REVIEW.md, TRACE.json, FINAL_VERIFICATION.json.\nNo loaded2.206 evidence or measured win-rate/unused-discard frequency claim.\nRelease policy permits fresh passive process absence without further confirmation,\nthen preserve current journals, explicit backed install and exact installed gate.\n")
write(EVAL/'NEXT_PRIORITIES_423.md',"""# Next priorities423

Candidate423/2.206 is frozen and fully validated; installed remains421/2.205.
Finish release only when a fresh successful passive process query finds Balatro
absent. Preserve newer public journals first; install exact combined bytes with
install_slice.py, explicit files/backups, then run the exact installed gate.
INSTALLATION_POLICY.md removes any further normal-exit confirmation requirement.
Absence does not prove a normal exit or a completed marathon.

Next user-loaded evidence should measure final action/settled unused discards by
exception reason, not just a global rate. Trace retained proof, optional Tarot,
final arbitration and actual physical round outcome. New secondary-Planet values
and source hunting are heuristic; audit their cash/slot/pool consequences without
scoring captured states. Inspect source receipt paid miss/cash buffer/final mode.

Latest prefix is development423/captures/004 (17011 events), incomplete session.
No complete ten-run claim. Do not keep broadening this delivered slice. Order-
sensitive and concealed discard gaps remain, as do broader cohort causal reviews.
No game control, saves/profiles, original execution, captured replay or new
experiment/automation. Historical budgets CLOSED. Sole423 review cycle exhausted.
""")
write(EVAL/'ARCHITECTURE_MAP_423.md',"""# Architecture delta423

- growth.lua: strict canonical suit and hand-type additive families extend
  retained-clear order qualification; no scoring/search budget change.
- decision.lua: supported teacher clear/discard comparison precedes optional
  development for mature/mixed rows; stale final-action mismatch excluded. Early
  shop12000 probe shares its paid miss with source exploration and existing
  fallback. Final leave-shop source preference preserves visible actions and
  passes completed lost-clear evidence to the optional cash rule.
- strategy.lua: Pair fallback and witnessed/concentrated secondary rank-repeat
  Planet utility; full-row Judgement filler; unchanged whole-inventory cleanup.
  Canonical first-slot source catalog opportunity and complete paid miss proof.
  Cash thresholds50/35/25 at1–3/4–6/7–8; only packs/rerolls, no new Joker sale.
- player_journal.lua: bounded scalar source status, paid-miss support/lost clear,
  opportunity mass and final selected mode; no catalog/world dump.
- New fixtures advisor_discard_order423 / advisor_perkeo_sources423.419 cash
  controls reflect new user limits;414/runtime saturation controls use sources
  whose actual utility is still capped. All unrelated fixture assertions retained.
""")
prefix=f"""FROZEN CANDIDATE423 —2026-09-27
2.206.0-alpha candidate validated:296 Lua/458 Python;110 dependencies/345 tests.
NOT INSTALLED. Installed/user-loaded remains421/2.205.0-alpha. Balatro running
at final passive verification; never control it or infer normal exit from absence.
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_423.md/.json, NEXT_PRIORITIES_423.md,
ARCHITECTURE_MAP_423.md and development423/REPORT.md, REVIEW.md, TRACE.json,
FINAL_VERIFICATION.json. Exact digest {record['policy_digest']}.
Repairs retained discard qualification/arbitration, secondary rank-repeat Planet
stock, weak Perkeo source search and user cash thresholds50/35/25. No loaded2.206
win rate or <1% unused-discard result is established. Newest preserved public
prefix development423/captures/004 has17011 events; session still incomplete.
INSTALLATION_POLICY.md authorizes installation after fresh successful passive
absence; no further closure confirmation. First preserve newer logs, then explicit
backed install and exact installed gate. Preserve settings/seven DLLs/all history.
No game control, saves/profiles, original execution, captured replay or experiment.
No automation started. Historical experiment budgets CLOSED.423 review exhausted.
Earlier checkpoints/history follow; this candidate supersedes their current-work
navigation, not the installed421 release or binding safety/execution boundaries.

"""
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;old=p.read_bytes();back=HERE/'navigation_before'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(old)
 p.write_bytes(prefix.encode()+old)
artifacts=[HERE/n for n in ('REPORT.md','REVIEW.md','TRACE.json','targeted3.log','source_targeted7.log','discard_targeted2.log')]+[candidate/'freeze.json',candidate/'validation/report.json']
save(HERE/'FINAL_VERIFICATION.json',{**record,'candidate_gate_passed':True,'counts':counts,'config_preserved':True,'native_files_preserved':7,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in artifacts},'final_diff_sha256':file_digest(HERE/'final_changes.diff')})
print(json.dumps({'digest':record['policy_digest'],'counts':counts,'prior_files':len(pre['prior_files']),'candidate_gate':True,'processes':processes,'installed':base['version']}))
