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
    assert result == {'lua_fixtures': 322, 'python_tests': 494}
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
assert len(deployed) == 94 and set(changed) == set(freeze['changed_from_installed440']) and len(changed) == 7
digest = freeze['candidate_policy_digest']
config = read(HERE / 'preinstall_verification.json')['config_sha256']
public_bytes = sum(r['bytes'] for r in manifest['segments'])
current = processes()
checkpoint = {
    'version': '2.219.0-alpha', 'revision': 444, 'installed_at': record['installation']['installedAt'],
    'installed': str(installed), 'backup': str(backup), 'policy_digest': digest, 'policy_files': freeze['candidate_policy_files'],
    'deployment_files': deployed, 'config_sha256': config, 'native_files_preserved': pre['native_files'],
    'runtime_file_count': 110, 'deployment_file_count': 94, 'backed_existing_file_count': 94,
    'changed_runtime_files': sorted(changed), 'frozen_test_file_count': 375, 'validation_counts': gate_counts,
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
save(EVAL / 'INSTALLED_CHECKPOINT_444.json', checkpoint)
report = f'''# Installed444 /2.219.0-alpha

The update is installed. Both exact full gates passed322 Lua fixtures and494
Python tests.110runtime dependencies/375frozen test files; digest `{digest}`.
Seven changed runtime files;94files backed and deployed. Configuration and seven
DLLs remain unchanged. Backup: `{backup}`. Activation awaits your next launch.

The runtime is byte-identical to reviewed442 candidate2. Its automatic future-hand
sort, physical Bell constraint and Death metadata fixes, plus Glass/population/Arm
resource preservation, are included. No new gameplay optimization was guessed.
The previous blocker was serial suite wall time: all322fixtures passed a diagnostic
in74.687seconds. Validation now runs the exact same fixture family in two isolated
DLL processes with one shared55-second deadline; outer60-second gate unchanged.
Every fixture executes once; failure, timeout or incomplete accounting fails the
whole gate. Production scoring budgets and runtime safeguards remain unchanged.

Latest copied loaded2.218 marathon: `{capture.relative_to(ROOT).as_posix()}`;
{len(manifest['segments'])}segments, {public_bytes}bytes, {summary['events']}events,
{len(summary['starts'])}starts/{len(summary['endings'])}endings;
{summary['outcomes']}. No unended runs or archive errors. Source and copy hashes
matched before and after deployment. These outcomes predate this update; there is
no loaded2.219 win-rate or complete discard-fix claim. Unsupported Acorn retirements
and remaining four-discard shortfalls require later analysis.

Fresh passive absence authorized installation. No normal-exit inference or game
control; no saves/profiles read. All{len(pre['prior_files'])} prior hashes preserved.
Offline tooling443 remains available. Historic experiment budgets stay CLOSED.
'''
write(EVAL / 'INSTALLED_CHECKPOINT_444.md', report)
save(EVAL / 'SESSION_RESET_444.json', checkpoint)
write(EVAL / 'SESSION_RESET_444.md', '''# Resume 444

2.219.0-alpha is installed. Read INSTALLED_CHECKPOINT_444.md/.json and
development444/install/INSTALLED_VERIFICATION.json. Candidate and exact-installed
full gates passed 322 Lua fixtures and 494 Python tests. Runtime bytes equal
reviewed 442 candidate2; 444 resolves validation scheduling without runtime edits.
Settings, seven DLLs, all prior artifacts and the latest ten-run public journals
are preserved. Activation awaits a user-started launch; no loaded 2.219 evidence.

Read ADVISOR_RESUME_PROMPT.md and INSTALLATION_POLICY.md for continuing boundaries.
Fresh passive process absence permits installation without another confirmation.
Never control Balatro or infer normal exit from absence. Preserve tracked and
untracked work and public journals. No saves/profiles or original-source execution.
All historical captured experiments remain CLOSED; review 444 is exhausted.

Offline tooling 443 is available via DECISION_REVIEW.md. Latest preserved session:
development443/log_copy/captures/001, 25,523 events, ten endings: four wins, four
losses, two unsupported, loaded 2.218. Reports and structural alternatives are
triage evidence, not proof of optimal choices or better win rate. Continue using
NEXT_PRIORITIES_444.md; do not treat a priority as an experiment authorization.
''')
write(EVAL / 'NEXT_PRIORITIES_444.md', '''# Priorities 444

1. Establish the next user-started session's loaded version passively. Preserve
   new public journals before clearing or a later deployment. Installation alone
   does not establish activation or effectiveness.
2. Adjudicate representative offline review packets and reason groups against
   public state, candidates, valuation, admission, budget, arbitration and settled
   action. Require a legal demonstrated alternative and a falsifying control.
3. Trace the latest two Acorn Public Joker advice unavailable retirements. Keep
   these unsupported outcomes separate from terminal losses.
4. Investigate four-discard shortfalls and short-discard signals without assuming
   every larger subset preserves survival. Current structural enumeration does
   not certify scores, resources or future outcomes.
5. Add qualified score/resource witnesses and expand settlement coverage for
   non-clearing plays, consumables and packs using manufactured attribution tests.

No new experiment is authorized by this list. All prior budgets remain closed.
The full validation timing blocker is resolved; do not reopen it without a new
failure or material change. Any runtime repair needs a new exact combined freeze,
review within its scope and full candidate/installed qualification.
''')
write(EVAL / 'ARCHITECTURE_MAP_444.md', '''# Architecture 444

Runtime 2.219 is byte-identical to reviewed 442 candidate2. Snapshot/journal
capture public hand-sort mode and physical tie identity. Draw adapters apply
source-qualified rank/suit sorting, select Bell's forced physical card before
sorting and reject invalid declared metadata. Death retains physical tie and
original-suit metadata; Strength/suit transforms refresh nominal values.
Sampled Yorick clear admission preserves already computed Glass, population and
Arm costs across complete common worlds. Production scoring budgets are unchanged.

validate_checkpoint invokes run_lua_tests with two workers only for the qualified
DLL path. The runner partitions the full fixture list exactly once into isolated
DLL-only subprocesses under one shared 55-second deadline. Nonzero exit, timeout,
spawn failure or invalid completion accounting fails the gate. The outer Lua
gate remains 60 seconds; external executable/default runner paths stay serial.
Seven manufactured scheduler controls cover failure and accounting semantics.

Offline tooling 443 remains described by ARCHITECTURE_MAP_443.md and
DECISION_REVIEW.md: verified copied-journal passes, receipt contradictions,
qualitative signals, structural alternatives, reason groups and independent
legacy-unflagged samples. These do not establish optimal strategy or win rate.

Release evidence: runs/repair444_candidate1 and repair444_installed bind exact
runtime bytes, tests and validator provenance. install_slice backs all deployed
paths; development444/install records passive absence, journal preservation,
deployment and both full gates. Historical evidence remains immutable.
''')
prefix = f'''INSTALLED REVISION444 /2.219.0-alpha —{now()[:10]}
Read tools/advisor_eval/INSTALLED_CHECKPOINT_444.md/.json,
SESSION_RESET_444.md/.json, NEXT_PRIORITIES_444.md, ARCHITECTURE_MAP_444.md,
development444/REPORT.md, REVIEW.md, FINAL_VERIFICATION.json and
install/INSTALLED_VERIFICATION.json. Both exact gates:322Lua/494Python;
110runtime/375tests. Digest {digest}.
Unchanged reviewed442 runtime now fully qualified and installed. Validation uses
2isolated DLL workers/shared55s deadline; outer60s cap and all assertions unchanged.
94backed/deployed files; settings/seven DLLs preserved. Latest copied2.218
marathon in development443/log_copy/captures/001:25523events,10ends,
4wins/4losses/2unsupported. No loaded2.219 efficacy or win-rate claim.
No game control, save/profile access or reopened experiments;444review exhausted.
Earlier uninstalled/blocker records below are preserved history.

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
paths = [EVAL / 'INSTALLED_CHECKPOINT_444.json', EVAL / 'INSTALLED_CHECKPOINT_444.md',
    EVAL / 'SESSION_RESET_444.json', EVAL / 'SESSION_RESET_444.md',
    EVAL / 'NEXT_PRIORITIES_444.md', EVAL / 'ARCHITECTURE_MAP_444.md',
    HERE / 'preinstall_verification.json', HERE / 'installation.log', CANDIDATE / 'freeze.json',
    CANDIDATE / 'validation/report.json', FINAL / 'record.json', FINAL / 'validation/report.json',
    capture / 'manifest.json', capture / 'summary.json', EVAL / 'development439/CLOSED.json', HERE.parent / 'FINAL_VERIFICATION.json']
save(HERE / 'INSTALLED_VERIFICATION.json', {
    'verified_utc': now(), 'version': '2.219.0-alpha', 'digest': digest, 'counts': gate_counts,
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
