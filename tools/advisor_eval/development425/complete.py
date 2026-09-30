"""Verify the exact 425 candidate and publish preservation/navigation receipts."""
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

candidate = EVAL / 'runs/repair425_candidate1'
freeze = json.loads((candidate / 'freeze.json').read_text())
gate = json.loads((candidate / 'validation/report.json').read_text())
pre = json.loads((HERE / 'prework.json').read_text())
base = json.loads((EVAL / 'SESSION_RESET_424.json').read_text())
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
assert changed_tests == {'tests/advisor_discard_development425.lua'}
changed_runtime = {r for r, h in freeze['candidate_policy_files'].items() if pre['runtime_files'].get(r) != h}
assert changed_runtime == {'Brainstorm/Advisor/decision.lua', 'Brainstorm/Advisor/player_journal.lua',
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
assert counts == {'lua_fixtures': 298, 'python_tests': 458}
assert len(freeze['candidate_policy_files']) == 110 and len(freeze['test_files']) == 347
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
                (ROOT / rel).read_text().splitlines(True), fromfile='before425/' + rel, tofile=rel))
write(HERE / 'final_changes.diff', ''.join(diff))
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':425,'version':'2.208.0-alpha',
 'status':'frozen_validated_not_installed','candidate':candidate.relative_to(ROOT).as_posix(),
 'policy_digest':freeze['candidate_policy_digest'],'policy_files':freeze['candidate_policy_files'],
 'changed_runtime_files':freeze['changed_runtime_files'],'runtime_file_count':110,
 'test_files':freeze['test_files'],'test_file_count':347,'changed_test_files':sorted(changed_tests),'validation_counts':counts,
 'installed_checkpoint':424,'installed_runtime_unchanged':True,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installation_authority':'tools/advisor_eval/INSTALLATION_POLICY.md','normal_exit_confirmation_required':False,
 'process_check_successful':True,'processes':processes,'normal_exit_inferred':False,
 'candidate_loaded_evidence':False,'win_rate_claim':False,'unused_discards_below_one_percent_demonstrated':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,'original_game_execution':False,
 'automation_created':False,'historical_experiment_allowances':'CLOSED','review_cycle_exhausted':True,'branch':branch}
save(EVAL/'CANDIDATE_CHECKPOINT_425.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_425.md',f"""# Candidate425 — 2.208.0-alpha

Exact digest `{record['policy_digest']}`. Passed298 Lua fixtures /458 Python tests.
110 runtime dependencies /347 frozen test files; four changed runtime files.
Not installed. Installed remains424/2.207. {process_text}
Read development425/REPORT.md, REVIEW.md, TRACE.json, FINAL_VERIFICATION.json.
Loaded2.207 public receipts confirm Hierophant displaced selected full discards;
this candidate preserves qualified Search incumbents through optional development.
Held-Death fallback and final action telemetry are covered.143 new manufactured
assertions plus unchanged regressions pass. No loaded2.208 effectiveness claim.
INSTALLATION_POLICY.md permits installation after fresh passive absence, newest
journal preservation, explicit backed deployment and exact installed gate.
""")
write(EVAL/'NEXT_PRIORITIES_425.md',"""# Next priorities425

Candidate425/2.208 is exact-frozen and fully validated; installed424/2.207 remains.
Finish release after a fresh successful passive query shows no Balatro process.
Preserve newer public journals, deploy explicit tested files with backed
install_slice.py, then freeze/validate installed bytes. INSTALLATION_POLICY.md
requires no further closure confirmation. Absence never proves normal exit.

After user loading, trace development_deferred_for_discard against final selected
action and settled physical discards. The flag describes proposal arbitration;
phase-copy/retry may still replace or remove the action. Confirm optional
Hierophant/Empress/Planet development waits behind an admitted Search discard.
Other unsupported order/held-card/concealed cases can still end with discards;
do not turn those missing proofs into forced actions or claim<1% globally.

Latest active prefix: development425/captures/001,1,825 verified loaded2.207
events, no ended run. TRACE.json documents two actual three-discard round ends.
Previous complete ten-run2.205 archive remains development424/captures/002:
4 wins/5 losses/1 unsupported; deep cohort analysis remains pending.
No captured-state policy/scorer execution, game control, saves/profiles, original
execution, new experiment or automation. Historical budgets CLOSED. Sole425
review cycle exhausted. Stop after this focused delivery.
""")
write(EVAL/'ARCHITECTURE_MAP_425.md',"""# Architecture delta425

- decision.lua: binds optional-development deferral to the current complete
  Search-selected Yorick discard in the teacher profile, after continuation.
  Incumbent action must be absent or match; nondevelopment rescue and later
  specialists remain. Compared consumable work is still charged. Held Death
  cannot send that incumbent through a retained-clear shortcut's play fallback.
  Other Death preparation remains unchanged. No new score/budget/proof scope.
- decision.lua: original search_selected and private proposal_indices survive
  ordinary arbitration; final risk status is stamped again after phase-copy,
  retry and discard_preference. A different discard cannot claim the proposal.
- player_journal.lua: compact risk includes development_deferred_for_discard;
  scalar only, excluding internal proposal indices and hypothetical state.
- advisor_discard_development425.lua:143 manufactured checks with real module
  integrations and small routing doubles. Exact424 baseline reproduces override.
- Core/Brainstorm.lua and steamodded_compat.lua: version2.208.0-alpha.

See ARCHITECTURE_MAP_424/423 for preceding installed changes and boundaries.
""")
prefix=f"""FROZEN CANDIDATE425 — 2026-09-27
2.208.0-alpha validated:298 Lua/458 Python;110 dependencies/347 frozen tests.
NOT INSTALLED. Installed/user-loaded remains424/2.207.0-alpha.
{process_text}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_425.md/.json, NEXT_PRIORITIES_425.md,
ARCHITECTURE_MAP_425.md and development425/REPORT.md, REVIEW.md, TRACE.json,
FINAL_VERIFICATION.json. Exact digest {record['policy_digest']}.
Confirmed Hierophant displaced admitted five-card discards in loaded2.207.
425 preserves that incumbent through optional development and held-Death fallback;
final telemetry follows phase-copy/retry overrides. No forced new discard proofs,
budget changes, loaded2.208 win-rate or<1% unused-discard claim.
Latest active prefix development425/captures/001:1,825 events, incomplete run.
Previous completed ten-run2.205 archive: development424/captures/002; never clear.
INSTALLATION_POLICY.md authorizes release after fresh successful process absence;
preserve newer logs, explicit backed install, exact installed gate. No further
confirmation or inferred normal exit. Preserve settings/seven DLLs/all prior work.
No game control, saves/profiles, captured replay, original execution, new
experiment or automation. Historical budgets CLOSED;425 review exhausted.
Earlier records follow as history. Stop after this coherent delivery.

"""
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;old=p.read_bytes();back=HERE/'navigation_before'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(old)
 p.write_bytes(prefix.encode()+old)
artifacts=[HERE/n for n in ('REPORT.md','REVIEW.md','TRACE.json','targeted3.log','baseline.log')]+[candidate/'freeze.json',candidate/'validation/report.json']
save(HERE/'FINAL_VERIFICATION.json',{**record,'candidate_gate_passed':True,'counts':counts,'config_preserved':True,'native_files_preserved':7,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in artifacts},'final_diff_sha256':file_digest(HERE/'final_changes.diff')})
print(json.dumps({'digest':record['policy_digest'],'counts':counts,'prior_files':len(pre['prior_files']),
 'candidate_gate':True,'processes':processes,'installed':base['version']}))
