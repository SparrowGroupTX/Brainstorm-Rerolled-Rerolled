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

candidate = EVAL / 'runs/repair426_candidate1'
freeze = json.loads((candidate / 'freeze.json').read_text())
gate = json.loads((candidate / 'validation/report.json').read_text())
pre = json.loads((HERE / 'resume_prework.json').read_text())
base = json.loads((EVAL / 'SESSION_RESET_425.json').read_text())
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
assert changed_tests == {'tests/advisor_soul_vacancy426.lua'}
changed_runtime = {r for r, h in freeze['candidate_policy_files'].items() if pre['runtime_files'].get(r) != h}
assert changed_runtime == {'Brainstorm/Advisor/strategy.lua', 'Brainstorm/Advisor/joker_retirement.lua',
                           'Brainstorm/Core/Brainstorm.lua', 'Brainstorm/steamodded_compat.lua'}
allowed = changed_runtime | changed_tests
for rel, sha in pre['before_files'].items():
    assert file_digest(HERE / 'before_resume' / rel) == sha, rel
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
assert counts == {'lua_fixtures': 299, 'python_tests': 458}
assert len(freeze['candidate_policy_files']) == 110 and len(freeze['test_files']) == 348
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
    old = HERE / 'before_resume' / rel
    diff.extend(difflib.unified_diff(old.read_text().splitlines(True) if old.exists() else [],
                (ROOT / rel).read_text().splitlines(True), fromfile='before426/' + rel, tofile=rel))
write(HERE / 'final_changes.diff', ''.join(diff))
record={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':426,'version':'2.209.0-alpha',
 'status':'frozen_validated_not_installed','candidate':candidate.relative_to(ROOT).as_posix(),
 'policy_digest':freeze['candidate_policy_digest'],'policy_files':freeze['candidate_policy_files'],
 'changed_runtime_files':freeze['changed_runtime_files'],'runtime_file_count':110,
 'test_files':freeze['test_files'],'test_file_count':348,'changed_test_files':sorted(changed_tests),'validation_counts':counts,
 'installed_checkpoint':425,'installed_runtime_unchanged':True,'installed_version':base['version'],'installed_digest':base['policy_digest'],
 'installation_authority':'tools/advisor_eval/INSTALLATION_POLICY.md','normal_exit_confirmation_required':False,
 'process_check_successful':True,'processes':processes,'normal_exit_inferred':False,
 'candidate_loaded_evidence':False,'win_rate_claim':False,'unused_discards_below_one_percent_demonstrated':False,
 'game_control':False,'save_profile_access':False,'captured_policy_replay':False,'original_game_execution':False,
 'automation_created':False,'historical_experiment_allowances':'CLOSED','review_cycle_exhausted':True,'branch':branch}
save(EVAL/'CANDIDATE_CHECKPOINT_426.json',record)
write(EVAL/'CANDIDATE_CHECKPOINT_426.md',f"""# Candidate426 — 2.209.0-alpha

Exact digest `{record['policy_digest']}`. Passed299 Lua fixtures /458 Python tests.
110 runtime dependencies /348 frozen test files; four changed runtime files.
Not installed. Installed425/2.208 remains unchanged and is user-loaded according
to public captures/003. {process_text}
Read development426/REPORT.md, IMPLEMENTATION_REVIEW.md, TRACE.json and
FINAL_VERIFICATION.json. Original prework/review are preserved history;
resume_prework.json is the post425-install baseline.
Soul capacity now admits a supported expired-Joker sale only after structural
preservation and fresh strategic choice preflight. No predicted legendary or
score claim.85 manufactured assertions and exact425 baseline evidence.
INSTALLATION_POLICY.md permits release after fresh passive absence, newest
journal preservation, explicit backed deployment and exact-installed gate.
""")
write(EVAL/'NEXT_PRIORITIES_426.md',"""# Next priorities426

Candidate426/2.209 is frozen and fully validated; installed425/2.208 is user-loaded.
Release when a fresh successful passive process check shows Balatro absent.
Preserve newest public journals; use explicit backed install_slice.py deployment,
then freeze and fully validate installed bytes. No further confirmation is needed.
Never control the game or infer normal exit/session completion from absence.

After loading, join expired_sale_for_soul receipts to actual sale, fresh Soul
advice and settled use. Keep structural sale completion separate from scored pack
comparison coverage and never infer the generated legendary before it is public.

Remaining unused-discard cases include Raised Fist held-floor and scoring-order
proof gaps, plus real score-rescue Tarot usage. Choose a concrete supported slice;
do not turn incomplete guarantees into forced discards or claim all cases fixed.
Observe installed425's development_deferred_for_discard receipts passively.

Preserved older2.207 session: development426/captures/002 (3 wins,1 loss,one unended).
Current2.208 prefix: captures/003,4771 events,one win,one unended; incomplete session.
Completed ten-run2.205 archive remains development424/captures/002; deep cohort
analysis is still pending. These observations establish no population win rate.
No game control, captured replay, saves/profiles, original execution, new experiment
or automation. Historical budgets CLOSED.426 review exhausted. Stop this delivery.
""")
write(EVAL/'ARCHITECTURE_MAP_426.md',"""# Architecture delta426

- joker_retirement.lua: soul_sales proves sale-only preservation for a visible
  canonical pack Soul in a full teacher row. Reuses exact removal, copy endpoint,
  inventory and resource safeguards. Optional row scope admits expired Mail and
  canonical Stencil; other retirement behavior is unchanged. No generated identity.
- strategy.lua: Soul pack capacity represents its Joker-slot dependency. A supported
  structural vacancy is preflighted with ordinary strategic pack choice; only the
  sale is emitted before reobservation. Legacy Omelette funding excludes pack Soul.
  Structural-only receipts do not claim complete scored pack coverage; existing
  compact public pack diagnostics carry admission, victim and reason.
- advisor_soul_vacancy426.lua:85 manufactured assertions, real Decision/Shop context
  and execution adapter, exact425 baseline, rejection and legacy Egg bypass tests.
- Core/Brainstorm.lua and steamodded_compat.lua: version2.209.0-alpha.

Four runtime changes; ordinary140000/shop50000/consumable25000/fast70/growth12 and
concealed8000 budgets unchanged. See425/424/423 architecture maps for earlier work.
""")
prefix=f"""FROZEN CANDIDATE426 — 2026-09-27
2.209.0-alpha validated:299 Lua/458 Python;110 dependencies/348 frozen tests.
NOT INSTALLED. Installed425/2.208 remains unchanged; public captures/003 confirms
user-loaded2.208 activation. {process_text}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_426.md/.json, NEXT_PRIORITIES_426.md,
ARCHITECTURE_MAP_426.md, development426/REPORT.md, IMPLEMENTATION_REVIEW.md,
TRACE.json and FINAL_VERIFICATION.json. Digest {record['policy_digest']}.
Visible Soul can make room through a structurally safe expired-Joker sale,
followed by fresh choice. No hypothetical legendary or complete tactical score
claim; legacy Egg bypass blocked. Other unused-discard proof gaps remain.
426 original prework/review predate425 install; resume_prework.json governs edits.
Current2.208 prefix: development426/captures/003,4771 events,one win,one unended.
Older2.207 archive captures/002 and completed2.205 development424/captures/002
remain preserved. No win-rate claim or inferred completed session/normal exit.
INSTALLATION_POLICY.md permits release after fresh passive absence, newest log
preservation, explicit backed deployment and exact-installed gate. No confirmation
question. Preserve settings/seven DLLs/all prior work. No game control, saves/profiles,
captured replay, original execution, new experiment or automation. Historical
budgets CLOSED;426 review exhausted. Earlier navigation follows as history.

"""
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')]+['tools/advisor_eval/README.md']:
 p=ROOT/rel;old=p.read_bytes();back=HERE/'navigation_before'/rel;back.parent.mkdir(parents=True,exist_ok=True)
 with back.open('xb') as f:f.write(old)
 p.write_bytes(prefix.encode()+old)
artifacts=[HERE/n for n in ('REPORT.md','REVIEW.md','IMPLEMENTATION_REVIEW.md','TRACE.json','targeted6.log','targeted8.log')]+[candidate/'freeze.json',candidate/'validation/report.json']
save(HERE/'FINAL_VERIFICATION.json',{**record,'candidate_gate_passed':True,'counts':counts,'config_preserved':True,'native_files_preserved':7,
 'prior_files_preserved':len(pre['prior_files']),'before_files_preserved':len(pre['before_files']),
 'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in artifacts},'final_diff_sha256':file_digest(HERE/'final_changes.diff')})
print(json.dumps({'digest':record['policy_digest'],'counts':counts,'prior_files':len(pre['prior_files']),
 'candidate_gate':True,'processes':processes,'installed':base['version']}))
