"""Exact 408 candidate release; passive public evidence and no game control."""
from datetime import datetime, timezone
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes
from validate_checkpoint import test_manifest, provenance

CANDIDATE = EVAL / 'runs/repair408_candidate3'
FINAL = EVAL / 'runs/repair408_installed'
SOURCE = Path('C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2')
NAV = ['ADVISOR_START_HERE.md', 'ADVISOR_HANDOFF.md', 'ADVISOR_RESUME_PROMPT.md',
       *['tools/advisor_eval/' + name for name in (
           'CANDIDATE_CHECKPOINT_408.md', 'NEXT_PRIORITIES_408.md',
           'ARCHITECTURE_MAP_408.md', 'FRESH_CHAT_HANDOFF_399.md', 'WIN_RATE_RESEARCH.md')]]


def save(path, value):
    with path.open('x', encoding='utf-8') as out:
        json.dump(value, out, indent=2)
        out.write('\n')


def now():
    return datetime.now(timezone.utc).isoformat()


def processes():
    result = subprocess.run(['pwsh', '-NoProfile', '-Command',
        '@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],
        capture_output=True, text=True, check=True,
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    current = json.loads(result.stdout) if result.stdout.strip() else []
    return current


def absent():
    current = processes()
    assert not current, 'Balatro is running; installation prohibited'
    return current


def stable(path):
    before = path.stat()
    data = path.read_bytes()
    after = path.stat()
    assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns)
    assert len(data) == after.st_size
    return data


def exact(installed_candidate=False, require_absence=True):
    if require_absence:
        absent()
    base = json.loads((EVAL / 'SESSION_RESET_404.json').read_text())
    freeze = json.loads((CANDIDATE / 'freeze.json').read_text())
    gate = json.loads((CANDIDATE / 'validation/report.json').read_text())
    expected = freeze['candidate_policy_files']
    assert gate['passed'] and gate['policy_unchanged'] and gate['tests_unchanged'] and gate['provenance_unchanged']
    assert policy_hashes(ROOT) == policy_hashes(CANDIDATE / 'policy') == expected == gate['policy_files']
    assert test_manifest() == freeze['test_files'] == gate['test_files']
    assert provenance() == freeze['validation_provenance'] == gate['validation_provenance']
    for rel, sha in freeze['test_files'].items():
        assert file_digest(CANDIDATE / 'tests_source' / rel) == sha, rel
    installed = Path(base['installed'])
    assert policy_hashes(installed.parent) == (expected if installed_candidate else base['policy_files'])
    native = {p.name: file_digest(p) for p in installed.glob('*.dll')}
    assert native == base['native_files_preserved'] and len(native) == 7
    assert {p.name: file_digest(p) for p in (ROOT / 'Brainstorm').glob('*.dll')} == native
    old = json.loads((EVAL / 'development408/FINAL_VERIFICATION.json').read_text())
    assert file_digest(CANDIDATE / 'validation/report.json') == old['gate_sha256']
    for rel, sha in old['artifacts'].items():
        assert file_digest(ROOT / rel) == sha, rel
    prior = json.loads((EVAL / 'development407/FINAL_VERIFICATION.json').read_text())
    for rel, sha in prior['artifact_hashes'].items():
        if rel.startswith('tools/advisor_eval/development407/'):
            assert file_digest(ROOT / rel) == sha, rel
    return base, freeze, installed


def public_unchanged(check_source=True):
    manifest = json.loads((HERE / 'capture/manifest.json').read_text())
    expected = {r['name']: r['sha256'] for r in manifest['segments']}
    if check_source:
        assert {p.name: file_digest(p) for p in SOURCE.glob('*.brj')} == expected
    for row in manifest['segments']:
        assert file_digest(HERE / 'logs1' / row['name']) == row['sha256']
    return manifest


def prepare():
    base, freeze, installed = exact()
    files = sorted(SOURCE.glob('*.brj'))
    assert files
    sessions = {p.name.rsplit('-', 1)[0] for p in files}
    assert len(sessions) == 1, 'Classify multiple available sessions separately before release'
    session = sessions.pop()
    (HERE / 'logs1').mkdir(exist_ok=False)
    (HERE / 'capture').mkdir(exist_ok=False)
    entries = []
    for source in files:
        target = HERE / 'logs1' / source.name
        target.write_bytes(stable(source))
        assert stable(target) == stable(source)
        entries.append({'name': source.name, 'bytes': target.stat().st_size,
                        'sha256': file_digest(target), 'source_still_matched': True})
    manifest = {'captured_utc': now(), 'source': str(SOURCE), 'session': session,
        'scope': 'All currently available public BRJ2 segments after user exit; no ten-run completion inferred.',
        'segments': entries, 'total_bytes': sum(r['bytes'] for r in entries),
        'all_source_still_matched': True}
    save(HERE / 'capture/manifest.json', manifest)
    copied = {}
    for rel in NAV:
        target = HERE / 'before' / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        copied[rel] = file_digest(target)
    git = subprocess.run(['git', 'status', '--short', '--untracked-files=all'], cwd=ROOT,
        capture_output=True, text=True, check=True).stdout
    (HERE / 'git_status_before.txt').write_text(git, encoding='utf-8')
    tracked = subprocess.run(['git', 'ls-files', '-z'], cwd=ROOT,
        capture_output=True, text=True, check=True).stdout.split('\0')
    tracked_hashes = {rel: file_digest(ROOT / rel) for rel in tracked if rel and (ROOT / rel).is_file()}
    save(HERE / 'normal_exit_confirmation.json', {'received_utc': now(),
        'confirmed': True, 'public_session': session,
        'user_message': "You're right. I just exited Balatro so you can install the update.",
        'interpretation': 'User reports own exit and explicitly authorizes installation; accepted as normal closure.',
        'completed_ten_run_batch_inferred': False, 'process_absence_is_not_confirmation': True})
    save(HERE / 'prework.json', {'created_utc': now(), 'runtime_files': freeze['candidate_policy_files'],
        'installed_baseline': base['policy_files'], 'installed_config_sha256': file_digest(installed / 'config.lua'),
        'native_files': base['native_files_preserved'], 'navigation_before': copied,
        'tracked_before': tracked_hashes, 'candidate_freeze_sha256': file_digest(CANDIDATE / 'freeze.json'),
        'prior408_verification_sha256': file_digest(EVAL / 'development408/FINAL_VERIFICATION.json'),
        'passive_processes': absent(), 'public_session': session})
    # Reuse the passive decoder/indexer exactly; no captured policy/scorer evaluation.
    target = HERE / 'index_public.py'
    assert not target.exists()
    shutil.copy2(EVAL / 'development407/index_public.py', target)
    public_unchanged()
    print(json.dumps({'prepared': True, 'session': session, 'segments': len(entries),
        'bytes': manifest['total_bytes'], 'candidate_digest': freeze['candidate_policy_digest']}))


def install():
    base, freeze, installed = exact()
    manifest = public_unchanged()
    confirmation = json.loads((HERE / 'normal_exit_confirmation.json').read_text())
    assert confirmation['confirmed'] and confirmation['public_session'] == manifest['session']
    verification = json.loads((HERE / 'capture/verification.json').read_text())
    assert not verification['failures'] and verification['session'] == manifest['session']
    pre = json.loads((HERE / 'prework.json').read_text())
    assert file_digest(installed / 'config.lua') == pre['installed_config_sha256']
    delta = {p for p in freeze['candidate_policy_files'].keys() | base['policy_files'].keys()
             if freeze['candidate_policy_files'].get(p) != base['policy_files'].get(p)}
    assert delta == set(freeze['changed_runtime_files']) and len(delta) == 11
    files = [p.removeprefix('Brainstorm/') for p in sorted(delta)]
    assert all(p.endswith('.lua') for p in files)
    command = [sys.executable, str(EVAL / 'install_slice.py'), '--version', '2.196.0-alpha', *files]
    save(HERE / 'preinstall_verification.json', {'verified_utc': now(),
        'candidate_digest': freeze['candidate_policy_digest'], 'command': command,
        'candidate_and_inputs_exact': True, 'installed_matches_baseline404': True,
        'normal_exit_confirmed': True, 'public_journals_preserved_and_classified': True,
        'config_sha256': pre['installed_config_sha256'], 'native_files': pre['native_files'],
        'passive_processes': absent()})
    log = HERE / 'installation.log'
    assert not log.exists() and not FINAL.exists()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    log.write_text(result.stdout + '\n' + result.stderr, encoding='utf-8')
    assert result.returncode == 0, result.stderr
    receipt = json.loads(result.stdout.splitlines()[0])
    exact(installed_candidate=True)
    assert file_digest(installed / 'config.lua') == pre['installed_config_sha256'] == receipt['configSHA256'].lower()
    public_unchanged()
    FINAL.mkdir(exist_ok=False)
    for rel, sha in freeze['candidate_policy_files'].items():
        target = FINAL / 'policy' / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(installed.parent / rel, target)
        assert file_digest(target) == sha
    assert policy_hashes(FINAL / 'policy') == freeze['candidate_policy_files']
    save(FINAL / 'record.json', {'created_utc': now(), 'installation': receipt,
        'installed': str(installed), 'command': command,
        'policy_digest': freeze['candidate_policy_digest'], 'policy_files': freeze['candidate_policy_files'],
        'test_files': test_manifest(), 'validation_provenance': provenance(),
        'candidate_freeze_sha256': file_digest(CANDIDATE / 'freeze.json'),
        'normal_exit_confirmation_sha256': file_digest(HERE / 'normal_exit_confirmation.json'),
        'preflight_sha256': file_digest(HERE / 'preinstall_verification.json'),
        'config_sha256': pre['installed_config_sha256'], 'native_files_preserved': pre['native_files'],
        'activation': 'Unconfirmed; awaits normal user start', 'game_process_control': False})
    print(json.dumps({'version': '2.196.0-alpha', 'backup': receipt['backup'],
        'digest': freeze['candidate_policy_digest'], 'installed_full_gate': 'pending'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('prepare', 'install'))
    args = parser.parse_args()
    {'prepare': prepare, 'install': install}[args.mode]()
