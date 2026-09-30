"""Seal installed qualification while preserving the candidate evidence."""
from pathlib import Path
import json, re
from release import HERE, EVAL, ROOT, CANDIDATE, FINAL, exact, journals, read, save, now, processes
from benchmark import file_digest, policy_hashes

def write(path, value):
    with Path(path).open('x', encoding='utf-8') as stream:
        stream.write(value)

def counts(folder):
    gate = read(folder / 'validation/report.json')
    assert all(gate[k] for k in ('passed', 'policy_unchanged', 'tests_unchanged', 'provenance_unchanged'))
    match = re.search(r'(\d+)/(\d+) fixtures passed', (folder / 'validation/lua.log').read_text())
    assert match and match[1] == match[2] == '328'
    python = sum(int(re.search(r'Ran (\d+) tests', (folder / 'validation' / name).read_text())[1])
                 for name in ('python.log', 'python_1.log', 'python_2.log'))
    assert python == 494
    return {'lua_fixtures': 328, 'python_tests': 494}

base, installed, freeze, pre = exact(True)
capture, manifest, summary = journals(False)
record = read(FINAL / 'record.json')
backup = Path(record['installation']['backup'])
assert counts(CANDIDATE) == counts(FINAL)
for folder in (CANDIDATE, FINAL):
    gate = read(folder / 'validation/report.json')
    assert gate['policy_files'] == freeze['candidate_policy_files']
    assert gate['test_files'] == freeze['test_files']
    assert gate['validation_provenance'] == freeze['validation_provenance']
assert policy_hashes(FINAL / 'policy') == freeze['candidate_policy_files'] == record['policy_files']
deployment = json.loads((backup / 'deployment.json').read_text(encoding='utf-8-sig'))
deployed, changed = {}, []
for row in deployment['files']:
    rel = row['path'].replace('\\', '/')
    assert row['before'] and file_digest(backup / rel) == row['before'].lower() == base['deployment_files'][rel]
    assert file_digest(installed / rel) == row['after'].lower() == freeze['candidate_policy_files']['Brainstorm/' + rel]
    deployed[rel] = row['after'].lower()
    if row['before'].lower() != row['after'].lower():
        changed.append('Brainstorm/' + rel)
assert len(deployed) == 94 and set(changed) == set(freeze['changed_from_installed446']) and len(changed) == 4
assert len(summary['starts']) == len(summary['endings']) == 10 and not summary['errors'] and not summary['unended_run_ids']
assert summary['events'] == 33136 and summary['outcomes'] == {'win': 8, 'loss': 2}
public_bytes = sum(row['bytes'] for row in manifest['segments'])
assert len(manifest['segments']) == 30 and public_bytes == 88237163
digest = freeze['candidate_policy_digest']
config = read(HERE / 'preinstall_verification.json')['config_sha256']
current = processes()
checkpoint = {
    'version': '2.224.0-alpha', 'revision': 449, 'installed_at': record['installation']['installedAt'],
    'installed': str(installed), 'backup': str(backup), 'policy_digest': digest,
    'policy_files': freeze['candidate_policy_files'], 'deployment_files': deployed,
    'config_sha256': config, 'native_files_preserved': pre['native_files'],
    'runtime_file_count': 110, 'deployment_file_count': 94, 'backed_existing_file_count': 94,
    'changed_runtime_files': sorted(changed), 'frozen_test_file_count': 381, 'validation_counts': counts(FINAL),
    'candidate_validation': str(CANDIDATE / 'validation/report.json'),
    'installed_validation': str(FINAL / 'validation/report.json'),
    'installation_policy_sha256': file_digest(EVAL / 'INSTALLATION_POLICY.md'),
    'normal_exit_inferred': False, 'activation': 'Unconfirmed; awaits user-started loading',
    'post_gate_processes': current, 'native_or_config_changed': False,
    'game_process_control': False, 'saved_game_or_profile_access': False,
    'all_discard_cases_fixed': False, 'review_cycle_exhausted': True,
    'reviewer_visibility_correction': 'Applied and primary-tested; no further reviewer inspection',
    'prior_preserved_hashes': len(pre['prior_files']),
    'latest_public_session': summary['session'], 'latest_public_loaded_labels': list(summary['versions']),
    'latest_public_capture': capture.relative_to(ROOT).as_posix(),
    'latest_public_capture_last_sequence': summary['events'],
    'latest_public_recorded_starts': 10, 'latest_public_recorded_outcomes': summary['outcomes'],
    'latest_public_unended_runs': 0, 'latest_public_capture_errors': [],
    'latest_public_manifest_sha256': file_digest(capture / 'manifest.json'),
    'historical_experiments': 'CLOSED', 'new_experiment_or_replay': False,
    'candidate1_qualified': False, 'candidate2_qualified': True,
}
save(EVAL / 'INSTALLED_CHECKPOINT_449.json', checkpoint)
save(EVAL / 'SESSION_RESET_449_INSTALLED.json', checkpoint)
report = f'''# Installed449 / 2.224.0-alpha

Installed successfully. Candidate2 and exact-installed full gates both pass
**328 Lua fixtures and 494 Python tests**. There are110 runtime dependencies and
381 frozen test files; digest `{digest}`. Four runtime files changed;94 files
were backed and deployed. Settings and all seven DLLs remain unchanged.
Backup: `{backup}`.

The combined release includes447 Astronomer/Photograph discard eligibility,
448 expired Riff-raff shop comparison (missed rental Brainstorm), and449 public
canonical Idol product-order retained-discard proof. The new fixture has23,712
manufactured assertions, including fresh physical sequences discarding12/15
cards with eight/nine-card hands. This does not establish historical rescues or
loaded-game effectiveness. Candidate1 is preserved unqualified history; the
reviewer's visibility blocker was corrected and primary-tested in candidate2.

The complete loaded2.221 ten-run session is safely preserved at
`{capture.relative_to(ROOT).as_posix()}`:30 segments,88,237,163 bytes,33,136 verified
events,10 starts/10 endings, **8 wins and2 losses**, no unended runs/archive errors.
Source and copy hashes matched before and after deployment. These outcomes predate
this release and do not establish a population win rate.

Both discard benchmarks remain unmet in that session:11.51/12 cards per round
with three discards;15.62/16 with four. Twenty clears leave47 discards. Only the
strictly qualified Idol family is repaired here; other proof, resource and search
gaps remain. See development449/REPORT.md and NEXT_PRIORITIES_449_INSTALLED.md.

Installation used fresh successful passive absence checks under standing user
authorization. No normal-exit inference, game control, save/profile access or
captured execution. Prior tracked/untracked work and exact candidate evidence
remain preserved. Activation/effectiveness awaits the next user-started load.
Historical experiments and runtime review449 remain CLOSED.
'''
write(EVAL / 'INSTALLED_CHECKPOINT_449.md', report)
write(EVAL / 'SESSION_RESET_449_INSTALLED.md', '''# Installed resume449

2.224.0-alpha is installed. Read INSTALLED_CHECKPOINT_449.md/.json,
development449/install/INSTALLED_VERIFICATION.json, development449/REPORT.md,
NEXT_PRIORITIES_449_INSTALLED.md and ARCHITECTURE_MAP_449.md. Both exact gates pass
328Lua/494Python,110 runtime dependencies/381 frozen tests. Candidate2 is installed;
candidate1 remains unqualified history. Closed candidate checkpoint449 is unchanged.

Full loaded2.221 marathon is preserved in development449/captures/001:33,136events,
10 starts/10 endings,8 wins/2 losses, no unended runs/archive errors. This full
session analysis supersedes448's partial18,890-event cutoff without overwriting it.
Both discard targets remain unmet;20 clears leave47 discards. No all-fixed claim.

Activation/effectiveness awaits user-started loading. Preserve newer public logs
and check version passively; never control Balatro or infer normal exit. The
installation policy permits fresh passive absence without a confirmation question.
Keep preservation, legality/resource, execution and exact qualification boundaries.
Historical experiments and runtime review449 remain CLOSED.
''')
write(EVAL / 'NEXT_PRIORITIES_449_INSTALLED.md', '''# Installed priorities449

1. Establish loaded2.224 passively in user-started journals. Check actual qualified
   Idol retained-discard behavior and447/448 exposures; lack of exposure is not
   evidence of effectiveness. Do not infer population win rate from ten outcomes.
2. Target required-Steel spare ordering: the bounded shortlist may miss the
   largest safe partial discard. Prove complete bounded alternatives while keeping
   real held resources and the12-call ceiling. Do not force unsafe discards.
3. Other gaps remain: Castle/hidden Idol held floors, conditional Blackboard,
   changing final-boss conditions, Chad/mixed +Mult/fractional card order. Inspect
   UNUSED_CLEAR_TRACE.json. The new Idol proof does not repair all20 unused clears.
4. Continue unsupported full-row replacement screening, Invisible future value
   and early Yorickx1 copy acquisition with explicit survival/reserve/horizon
   comparisons. Heuristic flags and outcomes alone do not establish regret.

No simulation, captured-execution budget, automation or review renewal is created
by this list. New runtime repairs need prospective scope and exact qualification.
''')
prefix = f'''INSTALLED REVISION449 /2.224.0-alpha —{now()[:10]}
Read tools/advisor_eval/INSTALLED_CHECKPOINT_449.md/.json,
SESSION_RESET_449_INSTALLED.md/.json, NEXT_PRIORITIES_449_INSTALLED.md,
ARCHITECTURE_MAP_449.md and development449/install/INSTALLED_VERIFICATION.json.
Candidate2 and exact-installed full gates:328Lua/494Python;110runtime/381tests.
Digest {digest}.
Combined447/448/449 fixes; four runtime changes;94backed/deployed files;
settings/seven DLLs preserved. Full loaded2.221 session copied and analyzed:
33,136events,10starts/10endings,8wins/2losses;0unended/0archiveerrors.
Both discard targets remain unmet;20clears leave47. New Idol proof is narrowly
qualified; loaded2.224 efficacy unconfirmed. No all-fixed or win-rate claim.
No game control or reopened experiments. Runtime review449 remains CLOSED.
Earlier candidate/install records follow as preserved history.

'''
navigation = {}
for rel in pre['navigation']:
    if rel.endswith('INSTALLATION_POLICY.md'):
        continue
    path = ROOT / rel
    old = path.read_bytes()
    dest = HERE / 'navigation_before_install' / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open('xb') as stream:
        stream.write(old)
    navigation[rel] = file_digest(dest)
    path.write_bytes(prefix.encode('utf-8') + old)
    assert path.read_bytes().endswith(old)
paths = [EVAL / name for name in ('INSTALLED_CHECKPOINT_449.json', 'INSTALLED_CHECKPOINT_449.md',
    'SESSION_RESET_449_INSTALLED.json', 'SESSION_RESET_449_INSTALLED.md', 'NEXT_PRIORITIES_449_INSTALLED.md')]
paths += [HERE / 'preinstall_verification.json', HERE / 'installation.log', CANDIDATE / 'freeze.json',
    CANDIDATE / 'validation/report.json', FINAL / 'record.json', FINAL / 'validation/report.json',
    capture / 'manifest.json', capture / 'summary.json', HERE.parent / 'FINAL_VERIFICATION.json']
save(HERE / 'INSTALLED_VERIFICATION.json', {
    'verified_utc': now(), 'version': '2.224.0-alpha', 'digest': digest, 'counts': counts(FINAL),
    'candidate_and_installed_gates_passed': True, 'installed_runtime_exact': True,
    'config_preserved': True, 'native_files_preserved': 7, 'deployed_paths': 94, 'backed_existing_paths': 94,
    'prior_files_preserved': len(pre['prior_files']), 'before_files_preserved': len(pre['before_files']),
    'public_segments_preserved': 30, 'public_bytes_preserved': public_bytes, 'public_capture': str(capture),
    'public_outcomes': summary['outcomes'], 'public_events': summary['events'],
    'normal_exit_inferred': False, 'activation_confirmed': False, 'passive_processes': current,
    'backup': str(backup), 'navigation_backups': navigation,
    'navigation_hashes': {rel: file_digest(ROOT / rel) for rel in navigation},
    'artifact_hashes': {path.relative_to(ROOT).as_posix(): file_digest(path) for path in paths},
})
exact(True)
print(json.dumps({'version': '2.224.0-alpha', 'counts': counts(FINAL), 'public_events': summary['events'],
                  'outcomes': summary['outcomes'], 'backup': str(backup), 'passive_processes': current}))
