"""Verify the exact 426 candidate and publish preservation/navigation receipts."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, json, re, subprocess, sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import file_digest, policy_hashes
from validate_checkpoint import test_manifest, provenance

def save(path, value):
    with path.open('x', encoding='utf-8') as f:
        json.dump(value, f, indent=2)
        f.write('\n')

def write(path, value):
    with path.open('x', encoding='utf-8') as f:
        f.write(value)

candidate = EVAL / 'runs/repair428_candidate1'
freeze = json.loads((candidate / 'freeze.json').read_text())
gate = json.loads((candidate / 'validation/report.json').read_text())
pre = json.loads((HERE / 'prework.json').read_text())
base = json.loads((EVAL / 'SESSION_RESET_426.json').read_text())
installed = Path(base['installed'])
assert all(gate[k] for k in ('passed', 'policy_unchanged', 'tests_unchanged', 'provenance_unchanged'))
assert policy_hashes(ROOT) == policy_hashes(candidate / 'policy') == freeze['candidate_policy_files'] == gate['policy_files']
assert test_manifest() == freeze['test_files'] == gate['test_files']
assert provenance() == freeze['validation_provenance'] == gate['validation_provenance'] == pre['provenance']
assert policy_hashes(installed.parent) == base['policy_files'] == pre['installed_runtime_files']
assert file_digest(installed / 'config.lua') == pre['config_sha256']
for root in (installed, ROOT / 'Brainstorm'):
    assert {p.name: file_digest(p) for p in root.glob('*.dll')} == pre['native_files']
for rel, sha in pre['prior_files'].items():
    assert file_digest(ROOT / rel) == sha, rel
assert file_digest(HERE / 'SCOPE.md') == freeze['scope_sha256']
changed_tests = {r for r, h in freeze['test_files'].items() if pre['test_files'].get(r) != h}
assert changed_tests == {'tests/advisor_small_order428.lua'}
changed_runtime = {r for r, h in freeze['candidate_policy_files'].items() if pre['runtime_files'].get(r) != h}
assert changed_runtime == {'Brainstorm/Advisor/growth.lua', 'Brainstorm/Advisor/player_journal.lua',
                           'Brainstorm/Core/Brainstorm.lua', 'Brainstorm/steamodded_compat.lua'}
allowed = changed_runtime | changed_tests
for rel, sha in pre['before_files'].items():
    assert file_digest(HERE / 'before' / rel) == sha, rel
    if rel not in allowed:
        assert file_digest(ROOT / rel) == sha, rel
for rel, sha in freeze['test_files'].items():
    assert file_digest(candidate / 'tests_source' / rel) == sha
for capture in sorted((HERE / 'captures').iterdir()):
    manifest = json.loads((capture / 'manifest.json').read_text())
    summary = json.loads((capture / 'summary.json').read_text())
    assert not summary['errors']
    for row in manifest['segments']:
        assert file_digest(capture / 'logs' / row['name']) == row['sha256']
    assert file_digest(capture / 'events.sqlite3') == summary['database_sha256']
m = re.search(r'(\d+)/(\d+) fixtures passed', (candidate / 'validation/lua.log').read_text())
assert m and m[1] == m[2]
py = sum(int(re.search(r'Ran (\d+) tests', (candidate / 'validation' / n).read_text())[1])
         for n in ('python.log', 'python_1.log', 'python_2.log'))
counts = {'lua_fixtures': int(m[1]), 'python_tests': py}
assert counts == {'lua_fixtures': 300, 'python_tests': 458}
assert len(freeze['candidate_policy_files']) == 110 and len(freeze['test_files']) == 349
ps = subprocess.run(['pwsh', '-NoProfile', '-Command',
    "@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],
    capture_output=True, text=True, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
processes = json.loads(ps.stdout) if ps.stdout.strip() else []
process_text = 'Balatro was running at final passive verification.' if processes else 'Balatro was absent at final passive verification; release remains to be performed.'
branch = subprocess.run(['git', 'branch', '--show-current'], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
assert branch == 'codex/exact-search-speedups', branch
status = subprocess.run(['git', 'status', '--short', '--untracked-files=all'], cwd=ROOT, capture_output=True, text=True, check=True).stdout
write(HERE / 'git_status_after.txt', status)
diff = []
for rel in sorted(allowed):
    old = HERE / 'before' / rel
    diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],
                (ROOT / rel).read_text().splitlines(True), fromfile='before428/' + rel, tofile=rel))
write(HERE / 'final_changes.diff', ''.join(diff))
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':428,'version':'2.210.0-alpha',
 'status':'frozen_validated_not_installed','candidate':candidate.relative_to(ROOT).as_posix(),
 'policy_digest':freeze['candidate_policy_digest'],'policy_files':freeze['candidate_policy_files'],
 'changed_runtime_files':freeze['changed_runtime_files'],'runtime_file_count':110,
 'test_files':freeze['test_files'],'test_file_count':349,'changed_test_files':sorted(changed_tests),'validation_counts':counts,
 'installed_checkpoint':426,'installed_runtime_unchanged':True,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installation_authority':'tools/advisor_eval/INSTALLATION_POLICY.md','normal_exit_confirmation_required':False,
 'process_check_successful':True,'processes':processes,'normal_exit_inferred':False,
 'candidate_loaded_evidence':False,'win_rate_claim':False,'unused_discards_below_one_percent_demonstrated':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,'original_game_execution':False,
 'automation_created':False,'historical_experiment_allowances':'CLOSED','review_cycle_exhausted':True,'branch':branch}

save(EVAL/'CANDIDATE_CHECKPOINT_428.json',record)
digest=record['policy_digest']
write(EVAL/'CANDIDATE_CHECKPOINT_428.md',f"""# Candidate428 -2.210.0-alpha

Exact digest `{digest}`;300 Lua fixtures/458 Python tests passed.110 runtime dependencies,349 frozen test files;four changed runtime files. Not installed: installed/user-loaded426/2.209 remains unchanged. {process_text}
Read development428/REPORT.md, REVIEW.md, TRACE.json and FINAL_VERIFICATION.json. Complete small retained-order families, canonical Smeared and irrelevant held/deck edition guards are repaired; cheap proofs remain preferred.349 new assertions and exact426 baseline. Other discard/Fool stock gaps remain. No loaded2.210 outcome or under1% claim.
Release only after fresh passive absence, newest public-log preservation, explicit backed install_slice deployment and exact-installed full gate. No further confirmation; never control game or infer normal exit.
""")
write(EVAL/'NEXT_PRIORITIES_428.md',"""# Next priorities428

Validated candidate428/2.210 is ready. Installed/user-loaded remains426/2.209. Defer installation while Balatro runs; fresh successful absence authorizes backed exact release under INSTALLATION_POLICY.md, without another question. Preserve latest public journals first. Never control the game or infer normal exit/session completion from absence.

After user loads2.210, examine public yorick_review.order_floor completeness/member count/minimum, actual discard size/counters and subsequent clear. Manufactured correctness is not a demonstrated win-rate improvement.

Immediate follow-ups: (1) RaisedFist/Blackboard conservative held floors, (2) larger noncommuting retained families and unsupported clears, (3) funded ordinary-slot consumable replacement for full World pools, including Fool/Jupiter, (4) general Fool target/use capability with fresh target->Fool->generated target sequencing. Do not only add hypothetical utility or credit Negative sales as free slots.

Completed audit427:10 loaded2.208 runs,5wins5losses;60clears left143discards,147/395fullfive. Full-rowBlueprint rerolled away despite funds; ordinary-copy threshold/uncertain finishing gates and flagger full-row blind spot need a manufactured comparison. Wraith cash wipe unpriced; Chad/OddTodd choice is valuation tension, not proven saved win. See development427/REPORT.md and FINDINGS.json.

Latest2.209 public prefix and current process state are bound by development428/LATEST.json and FINAL_VERIFICATION.json. Original files and archives untouched. No population win-rate or all-fixed claim. No game control, saves/profiles, captured replay, original execution, experiment or automation. Historical budgets CLOSED;428 review exhausted. Stop this completed slice.
""")
write(EVAL/'ARCHITECTURE_MAP_428.md',"""# Architecture delta428

- growth.lua: complete2/6 permutation floor for qualified retained2-/3-card anchors only when previous order guard would reject. Canonical selected effects and bounded nonnegative inputs protect random-floor monotonicity. Every member checks Glass/Arm and the family fits existing12calls before starting. Old additive/Chad certificates stay cheap. Canonical Smeared joins additive rows; canonical playing-card editions are neutral in held/deck qualification, with selected additive editions still restricted.
- player_journal.lua: compact yorick_review.order_floor reports scope/completeness/members/minimum/maximumGlass; no hypothetical draws or raw score lists exposed.
- advisor_small_order428.lua:349 manufactured checks including exact426 baseline, real repeated Decision discards before Tarot, every-order oracles, original cheap-proof alternateSteel, modified input and resource/capacity/budget controls.
- Core/Brainstorm.lua and steamodded_compat.lua:2.210.0-alpha.

Four runtime changes; no budget increases (ordinary140000/shop50000/consumable25000/fast70/growth12/concealed8000). Prior426 Soul fix preserved. No Fool runtime changes; existing Fool/Jupiter no-consecutiveFool test remains passed. Broader stock/capability gap traced in development428/TRACE.json.
""")
prefix=f"""FROZEN CANDIDATE428 -2026-09-27
2.210.0-alpha validated:300 Lua/458 Python;110 dependencies/349 frozen tests.
NOT INSTALLED. Installed/user-loaded426/2.209 remains unchanged. {process_text}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_428.md/.json, NEXT_PRIORITIES_428.md,
ARCHITECTURE_MAP_428.md, development428/REPORT.md, REVIEW.md, TRACE.json,
FINAL_VERIFICATION.json. Exact digest {digest}.
Complete small retained-order proofs and canonical Smeared/held-deck edition
qualification repaired; existing cheaper certificates preserved.349 assertions.
No loaded2.210 improvement, below1% unused-discard or all-fixed claim.
RaisedFist/Blackboard and broader order gaps remain. Full-slotWorld/Fool pass is
confirmed but unresolved; supportedFool/Jupiter already blocks consecutiveFools.
Completed2.208 ten-run audit: development427/REPORT.md, FINDINGS.json;
5wins5losses;60clears left143discards; affordable full-rowBlueprint pass and
unpricedWraith cash wipe found. Latest2.209 prefix: development428/LATEST.json.
INSTALLATION_POLICY.md permits release after fresh successful passive absence,
newest journal preservation, explicit backed deployment and exact-installed gate.
No confirmation question or inferred normal exit. All prior work/settings/sevenDLLs
preserved. No game control, saves, captured replay, original execution, experiment
or automation. Historical budgets CLOSED;428 review exhausted. Earlier history follows.

"""
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;old=p.read_bytes();back=HERE/'navigation_before'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(old)
 p.write_bytes(prefix.encode()+old)
artifacts=[HERE/n for n in ('REPORT.md','REVIEW.md','TRACE.json','targeted3.log','targeted5.log')]+[candidate/'freeze.json',candidate/'validation/report.json',EVAL/'development427/REPORT.md',EVAL/'development427/FINDINGS.json']
save(HERE/'FINAL_VERIFICATION.json',{**record,'candidate_gate_passed':True,'counts':counts,'config_preserved':True,'native_files_preserved':7,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in artifacts},'final_diff_sha256':file_digest(HERE/'final_changes.diff')})
print(json.dumps({'digest':digest,'counts':counts,'prior_files':len(pre['prior_files']),'candidate_gate':True,'processes':processes,'installed':base['version']}))
