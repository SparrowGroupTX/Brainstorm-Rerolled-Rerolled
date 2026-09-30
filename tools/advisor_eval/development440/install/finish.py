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
    assert result == {'lua_fixtures': 321, 'python_tests': 458}
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
assert len(deployed) == 94 and set(changed) == set(freeze['changed_from_installed437']) and len(changed) == 7
digest = freeze['candidate_policy_digest']
config = read(HERE / 'preinstall_verification.json')['config_sha256']
public_bytes = sum(r['bytes'] for r in manifest['segments'])
current = processes()
checkpoint = {
    'version': '2.218.0-alpha', 'revision': 440, 'installed_at': record['installation']['installedAt'],
    'installed': str(installed), 'backup': str(backup), 'policy_digest': digest, 'policy_files': freeze['candidate_policy_files'],
    'deployment_files': deployed, 'config_sha256': config, 'native_files_preserved': pre['native_files'],
    'runtime_file_count': 110, 'deployment_file_count': 94, 'backed_existing_file_count': 94,
    'changed_runtime_files': sorted(changed), 'frozen_test_file_count': 372, 'validation_counts': gate_counts,
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
save(EVAL / 'INSTALLED_CHECKPOINT_440.json', checkpoint)
report = f'''# Installed440 /2.218.0-alpha

The combined update is installed and both exact gates pass321 Lua fixtures and
458 Python tests:110 runtime dependencies,372 frozen test files,2969 new
manufactured assertions. Digest `{digest}`. Seven changed runtime files;
94 files deployed and backed. Settings and seven DLLs are unchanged.
Backup: `{backup}`. Activation awaits the user's next launch.

Repairs address mature/final Yorick comparisons, enhancement discard progress,
safe smaller batches, larger retained one-play arbitration and narrowly inert
Matador transitions. The previously uninstalled438 retained-two-play and Heart
repairs are included. Detached Bell/Acorn helpers remain exactly as qualified438.
See development440/REPORT.md and REVIEW.md for evidence, preserved failures and
scope. Review440 is exhausted. No new captured-policy evaluation was performed.

Latest public journals are preserved at `{capture.relative_to(ROOT).as_posix()}`:
{len(manifest['segments'])} segments, {public_bytes:,} bytes, {summary['events']:,}
verified events. Loaded2.216 recorded {len(summary['starts'])} starts and
{len(summary['endings'])} endings: {summary['outcomes']};
{len(summary['unended_run_ids'])} unended runs and {len(summary['errors'])} archive
errors. These outcomes predate this update and are not a population win-rate
estimate. Original journal bytes matched the capture before and after deployment.

Fresh successful passive process absence authorized installation under the user's
standing instruction. Normal exit was not inferred. No game process was launched,
stopped or controlled; no saves/profiles accessed. All {len(pre['prior_files'])}
prior hashes and before-work copies were preserved. Candidate records remain
unchanged, and this installed checkpoint supersedes their installation status.

The discard problem is not completely solved. Complete common-world samples
support new choices but cannot guarantee future draws. Last-hand progress,
broader resource/order rows and other Matador/Lucky transitions remain limited.
The closed439 experiment still has17 completed rounds averaging11.18 cards
against12.71 required; its20 attempts were not rerun. No new12-card benchmark
success or loaded2.218 win-rate improvement is claimed. Historical experiments
remain CLOSED; new captured evaluations require fresh prospective authorization.
'''
write(EVAL / 'INSTALLED_CHECKPOINT_440.md', report)
prefix = f'''INSTALLED REVISION440 /2.218.0-alpha —{now()[:10]}
Read tools/advisor_eval/INSTALLED_CHECKPOINT_440.md/.json and
 development440/install/INSTALLED_VERIFICATION.json for current installation;
 CANDIDATE_CHECKPOINT_440, SESSION_RESET_440, NEXT_PRIORITIES_440,
 ARCHITECTURE_MAP_440 and development440/REPORT.md/REVIEW.md for repair scope.
Candidate3 and exact-installed full gates passed321Lua/458Python;
110 dependencies/372 frozen tests. Digest {digest}.
Seven changed runtime files;94 deployed/backed; settings/seven DLLs preserved.
Latest copied loaded2.216 session: development440/install/captures/001,
{summary['events']:,} verified events;{len(summary['starts'])} starts,
{len(summary['endings'])} endings, outcomes {summary['outcomes']}.
{len(summary['unended_run_ids'])} unended runs/{len(summary['errors'])} archive errors.
2.218 activation/effectiveness unconfirmed.439 benchmark remains unmet;
no new captured evaluations or win-rate claim. Fresh passive absence authorized
installation; no normal-exit inference or game control. Review440 exhausted;
historical experiments CLOSED. Earlier records below are preserved history.

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
paths = [EVAL / 'INSTALLED_CHECKPOINT_440.json', EVAL / 'INSTALLED_CHECKPOINT_440.md',
    HERE / 'preinstall_verification.json', HERE / 'installation.log', CANDIDATE / 'freeze.json',
    CANDIDATE / 'validation/report.json', FINAL / 'record.json', FINAL / 'validation/report.json',
    capture / 'manifest.json', capture / 'summary.json', EVAL / 'development439/CLOSED.json', HERE.parent / 'FINAL_VERIFICATION.json']
save(HERE / 'INSTALLED_VERIFICATION.json', {
    'verified_utc': now(), 'version': '2.218.0-alpha', 'digest': digest, 'counts': gate_counts,
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
