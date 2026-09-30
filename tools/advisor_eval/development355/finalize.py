"""Read-only provenance verification and durable records for the closed pilot."""
import datetime as dt
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n', encoding='utf-8')


def main():
    closed = json.loads((HERE / 'CLOSED.json').read_text())
    if closed['status'] != 'CLOSED':
        raise RuntimeError('Closure required')
    test = json.loads((HERE / 'test_receipt.json').read_text())
    if test['returncode'] != 0:
        raise RuntimeError('Manufactured regression must pass')
    prior = json.loads((ROOT / 'tools/advisor_eval/SESSION_RESET_354.json').read_text())
    installed = prior['installed']
    install_root = Path(installed['installed'])
    runtime = []
    for item in installed['runtime_files']:
        relative = Path(item['path'])
        if relative.parts[0] != 'Brainstorm':
            raise RuntimeError('Unexpected runtime path')
        repo_hash = sha(ROOT / relative)
        install_hash = sha(install_root.joinpath(*relative.parts[1:]))
        runtime.append({'path': relative.as_posix(), 'repository_sha256': repo_hash,
                        'installed_sha256': install_hash,
                        'matches_frozen354': repo_hash == install_hash == item['installed_sha256']})
    if not all(item['matches_frozen354'] for item in runtime):
        raise RuntimeError('Runtime bytes differ from354; inspect before recording')
    jobs = {}
    for name, status in closed['jobs'].items():
        if status['status'] == 'closed_unused':
            jobs[name] = dict(status)
            continue
        directory = HERE / 'jobs' / name
        provenance = json.loads((directory / 'provenance.json').read_text())
        errors = [key for key, value in provenance['files'].items()
                  if sha(directory / 'frozen' / key) != value]
        if errors:
            raise RuntimeError(f'Frozen bytes changed: {name}: {errors}')
        if sha(directory / 'receipt.json') != status['receipt_sha256']:
            raise RuntimeError('Closed receipt changed')
        jobs[name] = {**status, 'frozen_files_reverified': len(provenance['files']),
                      'provenance_sha256': sha(directory / 'provenance.json')}
        summary = directory / 'summary.json'
        if summary.exists():
            jobs[name]['summary_sha256'] = sha(summary)
            jobs[name]['summary'] = json.loads(summary.read_text())
        checkpoint = directory / 'policy.pt'
        if checkpoint.exists():
            jobs[name]['checkpoint_sha256'] = sha(checkpoint)
    package = ROOT / 'tools/advisor_learning'
    sources = {p.relative_to(ROOT).as_posix(): sha(p) for p in package.glob('*') if p.is_file()}
    evidence = {p.relative_to(ROOT).as_posix(): sha(p) for p in HERE.glob('*')
                if p.is_file() and p.name != 'final_verification.json'}
    state = {
        'schema': 'learning355-final-state-v1',
        'verified_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'installed_version': installed['version'], 'new_runtime_release': False,
        'prior_runtime_checkpoint': 'tools/advisor_eval/SESSION_RESET_354.json',
        'prior_checkpoint_sha256': sha(ROOT / 'tools/advisor_eval/SESSION_RESET_354.json'),
        'policy_digest': installed['policy']['policy_digest'],
        'runtime_files': runtime, 'runtime_matches354': True,
        'settings': 'Not read, restored or written by this finalizer; no runtime install occurred.',
        'public_loaded_version_evidence': 'Existing opt-in public snapshot at2026-09-16T15:10:48Z reports2.154.0-alpha; current live game not inspected.',
        'experiment': closed, 'jobs': jobs, 'manufactured_tests': test,
        'learning_source_hashes': sources, 'top_level_evidence_hashes': evidence,
        'model_promoted': False, 'qualifying_simulator_wins': 0,
        'actual_player_awards': 0, 'simulator_qualified': False,
        'complete_player_win_rate': None, 'human_level_claim': False,
        'goal': 'Red Deck Gold Stake Perkeo/Yorick; average distinct new Gold stickers per game',
        'scope': 'Constructed post-Soul public scaffold, frozen initial collection; not supplied-seed/source equivalence or player campaign.',
        'worker_pending': False, 'no_further_experiment_authority': True}
    checkpoint = ROOT / 'tools/advisor_eval/SESSION_RESET_355.json'
    write(checkpoint, state)
    doc_paths = ['ADVISOR_START_HERE.md', 'ADVISOR_HANDOFF.md', 'ADVISOR_RESUME_PROMPT.md',
                 'tools/advisor_eval/SESSION_RESET_355.md', 'tools/advisor_eval/SESSION_RESET_355.json',
                 'tools/advisor_eval/NEXT_PRIORITIES_355.md', 'tools/advisor_eval/ARCHITECTURE_MAP_355.md']
    artifact_bytes = sum(p.stat().st_size for p in HERE.rglob('*') if p.is_file())
    if artifact_bytes > 2 * 2**30:
        raise RuntimeError('Artifact cap exceeded')
    final = {'verified_utc': state['verified_utc'], 'experiment_status': 'CLOSED',
             'runtime_unchanged': True, 'runtime_file_count': len(runtime),
             'policy_digest': state['policy_digest'], 'jobs': {k: {x: v[x] for x in
                 ('status','actual_coordinator_seconds','reserved_seconds')} for k,v in jobs.items()},
             'manufactured_tests': test,
             'documents': {name: sha(ROOT / name) for name in doc_paths},
             'learning_source_hashes': sources, 'evidence_hashes': evidence,
             'artifact_bytes': artifact_bytes,
             'model_promoted': False, 'settings_written': False,
             'native_files_preserved': [r for r in runtime if r['path'].lower().endswith('.dll')]}
    write(HERE / 'final_verification.json', final)
    print(json.dumps({'runtime_files_unchanged': len(runtime), 'artifact_bytes': artifact_bytes,
                      'jobs_reverified': len(jobs)-1, 'experiment_status': 'CLOSED',
                      'manufactured_tests': test}, indent=2))


if __name__ == '__main__':
    main()
