"""Verify the installed gate, preserve navigation history, and record release409."""
from pathlib import Path
import json
import re
import subprocess

from release import HERE, EVAL, ROOT, NAV, CANDIDATE, FINAL, exact, public_unchanged, save, now
from benchmark import digest, file_digest, policy_hashes
from validate_checkpoint import test_manifest, provenance


def new_text(path, value):
    with path.open('x', encoding='utf-8') as out:
        out.write(value)


def main():
    base, frozen, installed = exact(installed_candidate=True)
    manifest = public_unchanged()
    pre = json.loads((HERE / 'prework.json').read_text())
    expected = frozen['candidate_policy_files']
    counts = []
    for directory in (CANDIDATE, FINAL):
        gate = json.loads((directory / 'validation/report.json').read_text())
        assert gate['passed'] and gate['policy_unchanged'] and gate['tests_unchanged'] and gate['provenance_unchanged']
        assert gate['policy_files'] == expected and gate['test_files'] == frozen['test_files'] == test_manifest()
        assert gate['validation_provenance'] == frozen['validation_provenance'] == provenance()
        lua = re.search(r'(\d+)/(\d+) fixtures passed', (directory / 'validation/lua.log').read_text())
        assert lua and lua.group(1) == lua.group(2)
        python = sum(int(re.search(r'Ran (\d+) tests', (directory / 'validation' / name).read_text()).group(1))
                     for name in ('python.log', 'python_1.log', 'python_2.log'))
        counts.append({'lua_fixtures': int(lua.group(1)), 'python_tests': python})
    assert counts[0] == counts[1] == {'lua_fixtures': 274, 'python_tests': 458}
    assert policy_hashes(FINAL / 'policy') == expected
    record = json.loads((FINAL / 'record.json').read_text())
    assert record['policy_files'] == expected and record['test_files'] == frozen['test_files']
    assert record['validation_provenance'] == frozen['validation_provenance']
    assert file_digest(installed / 'config.lua') == record['config_sha256'] == pre['installed_config_sha256']
    backup = Path(record['installation']['backup'])
    deployment = json.loads((backup / 'deployment.json').read_text(encoding='utf-8-sig'))
    deployed = {}
    changed = []
    for row in deployment['files']:
        rel = row['path'].replace('\\', '/')
        assert file_digest(backup / rel) == row['before'].lower() == base['deployment_files'][rel]
        assert file_digest(installed / rel) == row['after'].lower() == expected['Brainstorm/' + rel]
        deployed[rel] = row['after'].lower()
        if row['before'].lower() != row['after'].lower():
            changed.append('Brainstorm/' + rel)
    assert len(deployed) == 93 and set(changed) == set(frozen['changed_runtime_files'])
    for rel, sha in pre['navigation_before'].items():
        assert file_digest(ROOT / rel) == file_digest(HERE / 'before' / rel) == sha
    for rel, sha in pre['tracked_before'].items():
        assert file_digest(ROOT / rel) == sha, rel
    before_paths = {line[3:] for line in (HERE / 'git_status_before.txt').read_text().splitlines() if line}
    status = subprocess.run(['git', 'status', '--short', '--untracked-files=all'], cwd=ROOT,
        capture_output=True, text=True, check=True).stdout
    assert before_paths <= {line[3:] for line in status.splitlines() if line}
    public = json.loads((HERE / 'public_classification.json').read_text())
    assert public['started_runs'] == 1 and not public['recorded_endings'] and len(public['unended_run_ids']) == 1
    checkpoint = {'version': '2.196.0-alpha', 'installed_at': record['installation']['installedAt'],
        'installed': str(installed), 'backup': str(backup), 'policy_digest': digest(expected), 'policy_files': expected,
        'deployment_files': deployed, 'config_sha256': record['config_sha256'],
        'native_files_preserved': record['native_files_preserved'], 'runtime_file_count': 109,
        'deployment_file_count': 93, 'changed_runtime_files': sorted(changed),
        'candidate_validation': str(CANDIDATE / 'validation/report.json'),
        'installed_validation': str(FINAL / 'validation/report.json'), 'validation_counts': counts[0],
        'frozen_test_file_count': 320, 'latest_public_loaded_label': '2.195.0-alpha',
        'latest_public_profile': 'perkeo_yorick_win_v1', 'latest_public_session': public['session'],
        'latest_public_capture_last_sequence': public['events'], 'latest_public_capture_complete_batch': False,
        'latest_public_starts': 1, 'latest_public_endings': {}, 'latest_public_nonterminal': 1,
        'latest_public_manifest_sha256': file_digest(HERE / 'capture/manifest.json'),
        'normal_exit_confirmation_sha256': file_digest(HERE / 'normal_exit_confirmation.json'),
        'activation': 'Unconfirmed; awaits next normal user game start; no 2.196 loaded outcomes',
        'native_or_config_changed': False, 'game_process_control': False, 'saved_game_or_profile_access': False}
    save(EVAL / 'SESSION_RESET_409.json', checkpoint)
    summary = f'''# Installed checkpoint409 — 2.196.0-alpha

The exact repair408 candidate3 is installed after current user exit confirmation.
Digest `{digest(expected)}`. All109 runtime dependencies match;11 selected files
changed;93 deployment paths and their old backups are verified. The320 declared
test files and validation provenance still match the frozen candidate. Both full
candidate and exact-installed gates pass274 Lua fixtures and458 Python tests.
Settings and all7 DLLs are unchanged. Backup: `{backup}`.

Machine evidence: SESSION_RESET_409.json, development409/final_verification.json,
runs/repair408_installed/record.json and validation/report.json. Historical
candidate408 records remain immutable; they describe the earlier uninstalled state.

Two current public segments/1,062 events were copied and verified. Their2.195
version label covers one started run without a terminal result, censored at user
exit. No completed ten-run batch is inferred. An observed Ante2 Yorick sale funded
Brainstorm and the purchase physically completed; see development409/YORICK_FINDINGS.md.
The new-core exception still permits this category of trade. A distinct source
gap exists in ordinary durable Buffoon replacement admission. Neither is claimed
fixed here. Further source/fixture diagnosis needs a separate coherent slice.

Activation awaits a normal user start. No2.196 loaded-game outcome, causal win
gain or population50% win rate is established. No game control, save/profile
access, captured-state policy/scorer execution or new experiment occurred.
Read NEXT_PRIORITIES_409.md and ARCHITECTURE_MAP_409.md. Stop after this release.
'''
    new_text(EVAL / 'SESSION_RESET_409.md', summary)
    new_text(HERE / 'REPORT.md', summary + '\nAll existing tracked files were hashed before release; only the eight backed\nnavigation files receive factual prefixes. Earlier tracked/untracked paths are\npreserved, and408/407 local evidence hashes remain unchanged.\n')
    new_text(EVAL / 'NEXT_PRIORITIES_409.md', '''# Priorities after release409

1. Exact2.196 is installed and validated; no installation remains pending.
   Activation and loaded behavior await normal user play. Do not start the game.
2. First next repair candidate: rigorous Yorick sale admission and future engine
   value. Read development409/YORICK_FINDINGS.md: the observed2.195 sale completed
   its Brainstorm purchase; it was not the prior voucher-diversion failure.
   Distinguish core-for-core trade, ordinary pack replacement, rescue, expired
   rental and final-Boss exceptions. Invent complete alternative-row fixtures;
   never replay captured observations through the policy/scorer.
3. Continue qualitative Invisible/pack/Buffoon/cash/discard adjudication only as a
   coherent subsequent authorized slice. Flags are hypotheses, not automatic
   mistakes or evidence for compulsory discards/purchases.
4. The latest preserved session has one censored start, not ten completed runs.
   Earlier407 cohort remains4 wins/4 losses/2 nonterminal retirements across10
   starts. Neither cohort establishes2.196 gains or a population win rate.

All mandatory ADVISOR_RESUME_PROMPT.md preservation, release and closed-experiment
boundaries remain. New runtime edits need a new exact combined freeze/full gates.
''')
    new_text(EVAL / 'ARCHITECTURE_MAP_409.md', '''# Release409 navigation

- Runtime behavior and fixtures: ARCHITECTURE_MAP_408.md; no409 runtime changes.
- Installed checkpoint: SESSION_RESET_409.json and .md.
- Exact installed freeze/gate: runs/repair408_installed/record.json, policy/,
  validation/report.json and raw logs.
- Release/provenance/preservation: development409/release.py, complete.py,
  prework.json, preinstall_verification.json, installation.log and final_verification.json.
- Public copied bytes/frame chain: development409/logs1/, capture/manifest.json,
  capture/verification.json, events.sqlite3. Read-only extraction: classify_public.py.
- Yorick actual causal chain and source-only review: development409/YORICK_FINDINGS.md
  and public_classification.json. The guard difference is not a manufactured proof
  or fix; recorded observations are never policy/scorer inputs.

No runtime work or reviewer recheck remains pending for this exact release.
Further strategic repair is distinct from installation of the validated408 bytes.
''')
    header = '''CURRENT INSTALLED CHECKPOINT409 — 2026-09-26
2.196.0-alpha repair408 candidate3 is now installed after the user reported exiting
Balatro and explicitly authorized installation. Read tools/advisor_eval/
SESSION_RESET_409.md/.json, NEXT_PRIORITIES_409.md, ARCHITECTURE_MAP_409.md and
development409/REPORT.md/YORICK_FINDINGS.md/final_verification.json.
Digest fef67966a4056cb5028d74022189ac2753c6ce2a6935dc290c316d183029f83c;
109 runtime dependencies,11 changed files,93 verified deployment/backup paths,
320 declared tests. Candidate and exact-installed gates both pass274 Lua/458
Python tests. Runtime/tests/helper provenance match; settings and7 DLLs preserved.
Two current public segments/1,062 events show one2.195 start without a terminal
result, censored at exit, not a completed ten-run batch. The observed Yorick sale
funded Brainstorm and the purchase completed. The new-core admission exception
still permits that category; a separate ordinary-pack admission gap is unpatched.
No2.196 activation/outcome or causal/population win-rate claim. No game control,
saved-game/profile access, captured-policy/scorer replay or new experiment.
Release complete; stop this slice. All earlier histories below remain preserved;
pending408 installation and current404 wording below are historical. Further
runtime work requires a new coherent scope and exact combined freeze/full gates.

'''
    for rel in NAV:
        path = ROOT / rel
        old = path.read_bytes()
        path.write_bytes(header.encode('utf-8') + old)
        assert path.read_bytes().endswith((HERE / 'before' / rel).read_bytes())
    for rel, sha in pre['tracked_before'].items():
        if rel not in NAV:
            assert file_digest(ROOT / rel) == sha, rel
    exact(installed_candidate=True)
    public_unchanged()
    status = subprocess.run(['git', 'status', '--short', '--untracked-files=all'], cwd=ROOT,
        capture_output=True, text=True, check=True).stdout
    assert before_paths <= {line[3:] for line in status.splitlines() if line}
    (HERE / 'git_status_after.txt').write_text(status, encoding='utf-8')
    artifacts = [p for p in HERE.rglob('*') if p.is_file()]
    artifacts += [ROOT / rel for rel in NAV]
    artifacts += [EVAL / name for name in ('SESSION_RESET_409.json', 'SESSION_RESET_409.md',
        'NEXT_PRIORITIES_409.md', 'ARCHITECTURE_MAP_409.md')]
    artifacts += [CANDIDATE / 'freeze.json', CANDIDATE / 'validation/report.json',
        FINAL / 'record.json', FINAL / 'validation/report.json']
    save(HERE / 'final_verification.json', {'verified_utc': now(),
        'status': 'installed_validated_delivery_complete', 'policy_digest': digest(expected),
        'candidate_and_installed_counts': counts, 'runtime_files': 109,
        'changed_files': 11, 'deployment_and_backup_files': 93, 'frozen_test_files': 320,
        'config_sha256': record['config_sha256'], 'native_files_preserved': record['native_files_preserved'],
        'normal_exit_confirmed': True, 'public_segments_preserved': 2,
        'public_events': 1062, 'public_started_runs': 1, 'public_nonterminal_runs': 1,
        'tracked_before_count': len(pre['tracked_before']), 'tracked_preserved_except_backed_navigation_prefixes': True,
        'prior_git_status_paths_preserved': True, '407_and_408_local_artifacts_unchanged': True,
        'backup_before_and_after_hashes_verified': True, 'game_control': False,
        'save_or_profile_access': False, 'captured_state_policy_execution': False,
        'new_experiment': False, 'activation': checkpoint['activation'],
        'artifact_hashes': {p.relative_to(ROOT).as_posix(): file_digest(p) for p in artifacts}})
    print(json.dumps({'status': 'installed_validated_delivery_complete',
        'version': checkpoint['version'], 'counts': counts[0], 'backup': str(backup),
        'runtime_digest': digest(expected), 'public_nonterminal_runs': 1}))


if __name__ == '__main__':
    main()
