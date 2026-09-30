"""Verify the exact combined424 candidate and publish preservation/navigation receipts."""
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

candidate = EVAL / 'runs/repair424_candidate1'
freeze = json.loads((candidate / 'freeze.json').read_text())
gate = json.loads((candidate / 'validation/report.json').read_text())
pre = json.loads((HERE / 'prework.json').read_text())
base = json.loads((EVAL / 'SESSION_RESET_421.json').read_text())
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
assert changed_tests == {'tests/advisor_discard_aggression424.lua'}
changed_runtime = {r for r, h in freeze['candidate_policy_files'].items() if pre['runtime_files'].get(r) != h}
assert changed_runtime == {'Brainstorm/Advisor/search.lua', 'Brainstorm/Advisor/player_journal.lua',
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
assert counts == {'lua_fixtures': 297, 'python_tests': 458}
assert len(freeze['candidate_policy_files']) == 110 and len(freeze['test_files']) == 346
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
                (ROOT / rel).read_text().splitlines(True), fromfile='before424/' + rel, tofile=rel))
write(HERE / 'final_changes.diff', ''.join(diff))
record = {'created_utc': datetime.now(timezone.utc).isoformat(), 'revision': 424, 'version': '2.207.0-alpha',
 'status': 'frozen_validated_not_installed', 'candidate': candidate.relative_to(ROOT).as_posix(),
 'policy_digest': freeze['candidate_policy_digest'], 'policy_files': freeze['candidate_policy_files'],
 'changed_runtime_files': freeze['changed_runtime_files'], 'runtime_file_count': 110,
 'incremental_runtime_files': sorted(changed_runtime), 'baseline_candidate': 423,
 'test_files': freeze['test_files'], 'test_file_count': 346, 'changed_test_files': sorted(changed_tests), 'validation_counts': counts,
 'installed_checkpoint': 421, 'installed_runtime_unchanged': True, 'installed_version': base['version'], 'installed_digest': base['policy_digest'],
 'installation_authority': 'tools/advisor_eval/INSTALLATION_POLICY.md', 'normal_exit_confirmation_required': False,
 'process_check_successful': True, 'processes': processes, 'normal_exit_inferred': False,
 'candidate_loaded_evidence': False, 'win_rate_claim': False, 'unused_discards_below_one_percent_demonstrated': False,
 'game_control': False, 'save_profile_access': False, 'captured_policy_replay': False, 'original_game_execution': False,
 'automation_created': False, 'historical_experiment_allowances': 'CLOSED', 'review_cycle_exhausted': True, 'branch': branch}
save(EVAL / 'CANDIDATE_CHECKPOINT_424.json', record)
write(EVAL / 'CANDIDATE_CHECKPOINT_424.md', f"""# Candidate424 — 2.207.0-alpha

Exact digest `{record['policy_digest']}`. Passed 297 Lua fixtures / 458 Python tests.
110 runtime dependencies / 346 frozen test files; seven combined runtime changes
against installed421, four incremental files against uninstalled423 candidate2.
Not installed. Installed remains421/2.205. {process_text}
Read development424/REPORT.md, REVIEW.md, PUBLIC_DIAGNOSTICS.json and
FINAL_VERIFICATION.json. Includes all423/2.206 fixes plus modest full-five
admission when every complete sampled redraw clears with at least105% margin.
Resource guards, positive growth horizon, existing eligibility and continuation
veto remain. Public full_batch_preference describes a proposal, not execution.
No loaded2.207 evidence or measured win-rate/unused-discard frequency claim.
Release policy permits fresh passive process absence without further confirmation,
then preserve current journals, explicit backed install and exact installed gate.
""")
write(EVAL / 'NEXT_PRIORITIES_424.md', """# Next priorities424

Candidate424/2.207 is frozen and fully validated; installed remains421/2.205.
It includes uninstalled423/2.206. Release this combined candidate only after a
fresh successful passive process query finds Balatro absent. Preserve newer
public journals first; install exact bytes with install_slice.py, explicit files
and backups, then freeze and run the exact installed full gate. Follow
INSTALLATION_POLICY.md; no additional normal-exit confirmation is required.
Absence does not prove normal exit or a completed marathon.

Future user-loaded evidence should distinguish full_batch_preference proposals
from final selected actions and settled unused discards. Audit veto reasons,
actual five-card counts, physical Yorick progress, and round outcomes. Combine
this with423 Planet/Judgement stock, source-search and cash-buffer receipts.
Do not execute policies/scorers against captured states or claim causal wins from
these descriptive receipts. Sample support is not guaranteed unseen-draw safety.

Latest preserved prefix is development424/captures/001,21462 verified events;
the session is incomplete, loaded2.205, and not a complete ten-run cohort.
Order-sensitive/concealed gaps and broader cohort causal work remain. Do not
broaden this delivery. No game control, saves/profiles, original execution,
captured replay, new experiment or automation. Historical budgets CLOSED.
Sole424 substantive and focused reviews are exhausted. Stop at this delivery.
""")
write(EVAL / 'ARCHITECTURE_MAP_424.md', """# Architecture delta424

Includes ARCHITECTURE_MAP_423.md in full. Incremental behavior:

- search.lua: qualifying neutral five-card Yorick growth can bypass only the
  utility taper when a complete family of at least24 samples all clears and its
  minimum certified sampled score reaches105% of the remaining target. Existing
  resource/population/conflict guards, positive growth, eligibility, caller caps,
  fast-clear choices and remaining-blind continuation veto remain unchanged.
- player_journal.lua: bounded full_batch_preference scalar in risk receipts.
  It describes admission of a search proposal; selected/final_action_kind/matches
  distinguish a final discard from a later veto. No extra score work or worlds.
- advisor_discard_aggression424.lua:93 manufactured assertions, synthetic score
  surfaces with actual after_discard transitions and production arbitration.
  Baseline423 decline reproduced; positive margin and negative boundary cases.
- Core/Brainstorm.lua and steamodded_compat.lua: combined version2.207.0-alpha.
""")
prefix = f"""FROZEN CANDIDATE424 — 2026-09-27
2.207.0-alpha validated:297 Lua/458 Python;110 dependencies/346 frozen tests.
NOT INSTALLED. Installed/user-loaded remains421/2.205.0-alpha.
{process_text}
Read tools/advisor_eval/CANDIDATE_CHECKPOINT_424.md/.json, NEXT_PRIORITIES_424.md,
ARCHITECTURE_MAP_424.md and development424/REPORT.md, REVIEW.md,
PUBLIC_DIAGNOSTICS.json, FINAL_VERIFICATION.json. Exact digest:
{record['policy_digest']}.
Includes all423/2.206 fixes plus modest full-five Yorick growth preference when
every complete sampled redraw clears at105% or more. Survival/resource guards
and continuation veto remain. No loaded2.207 win-rate or <1% waste claim.
Latest public prefix development424/captures/001 has21462 verified events;
session remains incomplete. Never infer normal exit or finished play from absence.
INSTALLATION_POLICY.md authorizes release after fresh successful process absence,
without another confirmation. Preserve newer logs, explicit backed install and
exact installed gate; preserve settings/seven DLLs/all tracked/untracked work.
No game control, saves/profiles, original execution, captured replay, experiment
or automation. Historical budgets CLOSED. Sole424 review cycle exhausted.
Earlier history follows; this supersedes candidate423 navigation, not installed421
or binding preservation/execution boundaries. Stop after this coherent delivery.

"""
for rel in [r for r in pre['navigation'] if not r.endswith('INSTALLATION_POLICY.md')] + ['tools/advisor_eval/README.md']:
    p = ROOT / rel
    old = p.read_bytes()
    back = HERE / 'navigation_before' / rel
    back.parent.mkdir(parents=True, exist_ok=True)
    with back.open('xb') as f:
        f.write(old)
    p.write_bytes(prefix.encode() + old)
artifacts = [HERE / n for n in ('REPORT.md', 'REVIEW.md', 'PUBLIC_DIAGNOSTICS.json', 'targeted3.log', 'baseline.log')]
artifacts += [candidate / 'freeze.json', candidate / 'validation/report.json']
save(HERE / 'FINAL_VERIFICATION.json', {**record, 'candidate_gate_passed': True, 'counts': counts,
 'config_preserved': True, 'native_files_preserved': 7, 'prior_files_preserved': len(pre['prior_files']),
 'before_files_preserved': len(pre['before_files']),
 'artifact_hashes': {p.relative_to(ROOT).as_posix(): file_digest(p) for p in artifacts},
 'final_diff_sha256': file_digest(HERE / 'final_changes.diff')})
print(json.dumps({'digest': record['policy_digest'], 'counts': counts, 'prior_files': len(pre['prior_files']),
                  'candidate_gate': True, 'processes': processes, 'installed': base['version']}))
