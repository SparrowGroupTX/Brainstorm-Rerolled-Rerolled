"""Record the exact installed gate without rewriting closed candidate evidence."""
import re
from pathlib import Path
from release import HERE, EVAL, ROOT, CANDIDATE, FINAL, exact, journals, read, save, now, processes
from benchmark import file_digest, policy_hashes

def counts(folder):
    gate = read(folder / 'validation/report.json')
    assert all(gate[k] for k in ('passed', 'policy_unchanged', 'tests_unchanged', 'provenance_unchanged'))
    text = (folder / 'validation/lua.log').read_text(encoding='utf-8')
    m = re.search(r'(\d+)/(\d+) fixtures passed', text)
    assert m and m[1] == m[2]
    python = sum(int(re.search(r'Ran (\d+) tests', (folder / 'validation' / name).read_text(encoding='utf-8'))[1])
        for name in ('python.log', 'python_1.log', 'python_2.log'))
    result = {'lua_fixtures': int(m[1]), 'python_tests': python}
    assert result == {'lua_fixtures': 316, 'python_tests': 458}
    return result

def write(path, text):
    with Path(path).open('x', encoding='utf-8') as f: f.write(text)

base, installed, freeze, pre = exact(True)
capture, manifest, summary = journals(False)
record = read(FINAL / 'record.json')
backup = Path(record['installation']['backup'])
gate_counts = counts(CANDIDATE)
assert counts(FINAL) == gate_counts
for folder in (CANDIDATE, FINAL):
    gate = read(folder / 'validation/report.json')
    assert gate['policy_files'] == freeze['candidate_policy_files']
    assert gate['test_files'] == freeze['test_files']
    assert gate['validation_provenance'] == freeze['validation_provenance']
assert policy_hashes(FINAL / 'policy') == freeze['candidate_policy_files'] == record['policy_files']
deployment = __import__('json').loads((backup / 'deployment.json').read_text(encoding='utf-8-sig'))
deployed, changed = {}, []
for row in deployment['files']:
    rel = row['path'].replace('\\', '/')
    assert row['before'] and file_digest(backup / rel) == row['before'].lower() == base['deployment_files'][rel]
    assert file_digest(installed / rel) == row['after'].lower() == freeze['candidate_policy_files']['Brainstorm/' + rel]
    deployed[rel] = row['after'].lower()
    if row['before'].lower() != row['after'].lower(): changed.append('Brainstorm/' + rel)
assert len(deployed) == 94 and set(changed) == set(freeze['changed_from_installed434']) and len(changed) == 10
digest = freeze['candidate_policy_digest']
config = read(HERE / 'preinstall_verification.json')['config_sha256']
public_bytes = sum(r['bytes'] for r in manifest['segments'])
current = processes()
checkpoint = {
    'version': '2.216.0-alpha', 'revision': 437, 'installed_at': record['installation']['installedAt'],
    'installed': str(installed), 'backup': str(backup), 'policy_digest': digest, 'policy_files': freeze['candidate_policy_files'],
    'deployment_files': deployed, 'config_sha256': config, 'native_files_preserved': pre['native_files'],
    'runtime_file_count': 110, 'deployment_file_count': 94, 'backed_existing_file_count': 94,
    'changed_runtime_files': sorted(changed), 'frozen_test_file_count': 367, 'validation_counts': gate_counts,
    'candidate_validation': str(CANDIDATE / 'validation/report.json'), 'installed_validation': str(FINAL / 'validation/report.json'),
    'installation_policy_sha256': file_digest(EVAL / 'INSTALLATION_POLICY.md'), 'normal_exit_inferred': False,
    'activation': 'Unconfirmed; installation is not loaded-game evidence', 'post_gate_processes': current,
    'native_or_config_changed': False, 'game_process_control': False, 'saved_game_or_profile_access': False,
    'all_discard_cases_fixed': False, 'review_cycle_exhausted': True, 'prior_preserved_hashes': len(pre['prior_files']),
    'latest_public_session': summary['session'], 'latest_public_loaded_labels': list(summary['versions']),
    'latest_public_capture': capture.relative_to(ROOT).as_posix(), 'latest_public_capture_last_sequence': summary['events'],
    'latest_public_recorded_starts': len(summary['starts']), 'latest_public_recorded_outcomes': summary['outcomes'],
    'latest_public_unended_runs': len(summary['unended_run_ids']), 'latest_public_capture_errors': summary['errors'],
    'latest_public_manifest_sha256': file_digest(capture / 'manifest.json'), 'historical_experiments': 'CLOSED',
    'new_experiment_or_replay': False}
save(EVAL / 'INSTALLED_CHECKPOINT_437.json', checkpoint)
report = f'''# Installed 437 / 2.216.0-alpha

The exact combined candidate is installed and fully validated: 316 Lua fixtures
and 458 Python tests, 110 runtime dependencies and 367 frozen test files.
Digest: `{digest}`. Ten changed runtime files; 94 deployed and backed files.
Settings and all seven DLLs are preserved. Backup: `{backup}`.
The user can start Balatro. Activation and effectiveness require user-loaded evidence.

This includes the 436 conditional scoring, expiry and diagnostic repairs, plus
437 five-card continuation admission and the owned-Yorick comparison guard.
The discard problem is not completely fixed: the closed ten-round test completed
six rounds averaging 10.17 cards discarded against the 12-card target; four were
unsupported. The Vessel retained-two-play gap and unsupported transition families
remain. No improved population win-rate claim is made.

Latest public journals are safely preserved at `{capture.relative_to(ROOT).as_posix()}`:
{len(manifest['segments'])} segments / {public_bytes:,} bytes / {summary['events']:,} verified events.
Loaded 2.214 recorded {len(summary['starts'])} starts and {len(summary['endings'])} endings:
{summary['outcomes']}; {len(summary['unended_run_ids'])} unended runs;
{len(summary['errors'])} archive verification errors. These outcomes predate this update.

Fresh passive process absence authorized installation; normal exit was not inferred.
Original journals matched the copy before and after deployment. No game control,
save/profile access, runtime editing, captured replay, simulation or automation
was performed for this installation. All {len(pre['prior_files'])} prework historical
hashes and before-work copies were verified. Closed experiment437 and candidate
records remain unchanged. Reviews and prior experiments remain closed.

This installed checkpoint supersedes the installation status in the historical
SESSION_RESET_437 and CANDIDATE_CHECKPOINT_437 records; those remain preserved.
See development437/install/INSTALLED_VERIFICATION.json and runs/repair437_installed.
'''
write(EVAL / 'INSTALLED_CHECKPOINT_437.md', report)
prefix = f'''INSTALLED REVISION437 /2.216.0-alpha —{now()[:10]}
Read tools/advisor_eval/INSTALLED_CHECKPOINT_437.md/.json and
development437/install/INSTALLED_VERIFICATION.json for current installation.
Candidate2 and exact-installed full gates passed316Lua/458Python;
110 dependencies/367 frozen tests. Digest {digest}.
Ten changed files;94 deployed/94 backed; settings/seven DLLs preserved.
Latest copied loaded2.214 session: development437/install/captures/001,
29,132 verified events;10 starts/10 endings,5wins/2losses/3unsupported.
No unended runs or archive errors. Loaded2.216 effectiveness unconfirmed.
437 discard benchmark remains unmet; see preserved development437/REPORT.md,
EXPERIMENT_REPORT.md, RESULTS.json and CLOSED.json. No all-fixed/win-rate claim.
Fresh passive absence authorized deployment; no normal-exit inference/game control.
All prior reviews and experiments remain CLOSED. Earlier status is preserved history.

'''
navigation_backups = {}
for rel in pre['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'): continue
    path = ROOT / rel
    prior = path.read_bytes()
    target = HERE / 'navigation_before_install' / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as f: f.write(prior)
    navigation_backups[rel] = file_digest(target)
    path.write_bytes(prefix.encode('utf-8') + prior)
    assert path.read_bytes().endswith(prior)
paths = [EVAL / 'INSTALLED_CHECKPOINT_437.json', EVAL / 'INSTALLED_CHECKPOINT_437.md',
    HERE / 'preinstall_verification.json', HERE / 'installation.log', CANDIDATE / 'freeze.json',
    CANDIDATE / 'validation/report.json', FINAL / 'record.json', FINAL / 'validation/report.json',
    capture / 'manifest.json', capture / 'summary.json', HERE.parent / 'CLOSED.json', HERE.parent / 'FINAL_VERIFICATION.json']
save(HERE / 'INSTALLED_VERIFICATION.json', {
    'verified_utc': now(), 'version': '2.216.0-alpha', 'digest': digest, 'counts': gate_counts,
    'candidate_and_installed_gates_passed': True, 'installed_runtime_exact': True,
    'config_preserved': True, 'native_files_preserved': 7, 'deployed_paths': 94, 'backed_existing_paths': 94,
    'prior_files_preserved': len(pre['prior_files']), 'before_files_preserved': len(pre['before_files']),
    'public_segments_preserved': len(manifest['segments']), 'public_bytes_preserved': public_bytes,
    'public_capture': str(capture), 'public_outcomes': summary['outcomes'], 'public_events': summary['events'],
    'normal_exit_inferred': False, 'activation_confirmed': False, 'passive_processes': current,
    'backup': str(backup), 'navigation_backups': navigation_backups,
    'artifact_hashes': {p.relative_to(ROOT).as_posix(): file_digest(p) for p in paths}})
print(__import__('json').dumps({'version': checkpoint['version'], 'counts': gate_counts,
    'backup': str(backup), 'public_events': summary['events'], 'passive_processes': current}))
