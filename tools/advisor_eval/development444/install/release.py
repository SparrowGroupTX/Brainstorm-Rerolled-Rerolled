"""Mechanically deploy the already validated combined 444 candidate."""
from pathlib import Path
from datetime import datetime, timezone
import json, shutil, subprocess, sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import file_digest, policy_hashes
from validate_checkpoint import test_manifest, provenance

CANDIDATE = EVAL / 'runs/repair444_candidate1'
FINAL = EVAL / 'runs/repair444_installed'

def now(): return datetime.now(timezone.utc).isoformat()
def read(p): return json.loads(Path(p).read_text(encoding='utf-8'))
def save(p, value):
    with Path(p).open('x', encoding='utf-8') as f:
        json.dump(value, f, indent=2, allow_nan=False)
        f.write('\n')

def processes():
    r = subprocess.run(['pwsh', '-NoProfile', '-Command',
        "@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],
        capture_output=True, text=True, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
    return json.loads(r.stdout) if r.stdout.strip() else []

def absent(): assert not processes(), 'Balatro is running; defer installation'

def journals(source=False):
    latest = read(EVAL / 'development443/log_copy/LATEST.json')
    folder = ROOT / latest['capture']
    manifest, summary = read(folder / 'manifest.json'), read(folder / 'summary.json')
    assert file_digest(folder / 'summary.json') == latest['summary_sha256']
    expected = {row['name']: row['sha256'] for row in manifest['segments']}
    assert {p.name: file_digest(p) for p in (folder / 'logs').glob('*.brj')} == expected
    assert file_digest(folder / 'events.sqlite3') == summary['database_sha256']
    assert summary['session'] == manifest['session']
    if source:
        paths = list(Path(manifest['source']).glob('*.brj'))
        assert max(paths, key=lambda p: p.stat().st_mtime).name.startswith(manifest['session']+'-'), 'New session needs preservation'
        assert {p.name: file_digest(p) for p in paths if p.name.startswith(manifest['session']+'-')} == expected, 'New journal bytes need preservation'
    return folder, manifest, summary

def exact(deployed=False):
    base = read(EVAL / 'INSTALLED_CHECKPOINT_440.json')
    installed = Path(base['installed'])
    freeze = read(CANDIDATE / 'freeze.json')
    gate = read(CANDIDATE / 'validation/report.json')
    pre = read(HERE.parent / 'prework.json')
    assert all(gate[k] for k in ('passed', 'policy_unchanged', 'tests_unchanged', 'provenance_unchanged'))
    expected = freeze['candidate_policy_files']
    assert policy_hashes(ROOT) == policy_hashes(CANDIDATE / 'policy') == expected == gate['policy_files']
    assert test_manifest() == freeze['test_files'] == gate['test_files']
    assert provenance() == freeze['validation_provenance'] == gate['validation_provenance']
    for rel, h in freeze['evaluation_helpers'].items(): assert file_digest(ROOT / rel) == file_digest(CANDIDATE / 'helpers' / rel) == h
    assert file_digest(HERE.parent / 'SCOPE.md') == freeze['scope_sha256']
    for rel, digest in freeze['test_files'].items():
        assert file_digest(CANDIDATE / 'tests_source' / rel) == digest, rel
    assert policy_hashes(installed.parent) == (expected if deployed else base['policy_files'])
    for root in (ROOT / 'Brainstorm', installed):
        assert {p.name: file_digest(p) for p in root.glob('*.dll')} == pre['native_files']
    for rel, digest in pre['prior_files'].items(): assert file_digest(ROOT / rel) == digest, rel
    for rel, digest in pre['before_files'].items(): assert file_digest(HERE.parent / 'before' / rel) == digest, rel
    assert file_digest(EVAL / 'INSTALLATION_POLICY.md') == pre['before_files']['tools/advisor_eval/INSTALLATION_POLICY.md']
    if (HERE / 'preinstall_verification.json').exists():
        assert file_digest(installed / 'config.lua') == read(HERE / 'preinstall_verification.json')['config_sha256']
    return base, installed, freeze, pre

def main():
    assert (HERE.parent / 'REVIEW.md').is_file() and (HERE.parent / 'FINAL_VERIFICATION.json').is_file()
    absent()
    base, installed, freeze, pre = exact()
    folder, manifest, summary = journals(True)
    expected = freeze['candidate_policy_files']
    delta = {r for r in expected.keys() | base['policy_files'].keys() if expected.get(r) != base['policy_files'].get(r)}
    assert delta == set(freeze['changed_from_installed440']) and len(delta) == 7
    assert len(expected) == 110 and len(freeze['test_files']) == 375
    assert subprocess.run(['git', 'branch', '--show-current'], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip() == 'codex/exact-search-speedups'
    command = [sys.executable, '-B', '-X', 'utf8', str(EVAL / 'install_slice.py'), '--version', '2.219.0-alpha',
        *[r.removeprefix('Brainstorm/') for r in sorted(delta)]]
    save(HERE / 'preinstall_verification.json', {
        'verified_utc': now(), 'command': command, 'candidate_digest': freeze['candidate_policy_digest'],
        'exact_candidate_gate_passed': True, 'authorization': 'User: Analyze and fix; standing instruction to install after passive process absence.',
        'installation_policy_sha256': file_digest(EVAL / 'INSTALLATION_POLICY.md'),
        'normal_exit_inferred': False, 'passive_processes': processes(), 'public_capture': str(folder),
        'public_segments_preserved': len(manifest['segments']), 'config_sha256': file_digest(installed / 'config.lua'),
        'native_files': pre['native_files'], 'prior_files_preserved': len(pre['prior_files'])})
    assert not FINAL.exists() and not (HERE / 'installation.log').exists()
    absent()
    r = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', creationflags=subprocess.CREATE_NO_WINDOW)
    (HERE / 'installation.log').write_text(r.stdout+'\n'+r.stderr, encoding='utf-8')
    assert r.returncode == 0, r.stdout+r.stderr
    receipt = json.loads(r.stdout.splitlines()[0])
    exact(True)
    journals(True)
    FINAL.mkdir()
    for rel, digest in expected.items():
        target = FINAL / 'policy' / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(installed.parent / rel, target)
        assert file_digest(target) == digest
    assert policy_hashes(FINAL / 'policy') == expected
    save(FINAL / 'record.json', {
        'created_utc': now(), 'installation': receipt, 'installed': str(installed), 'command': command,
        'policy_digest': freeze['candidate_policy_digest'], 'policy_files': expected, 'test_files': test_manifest(),
        'validation_provenance': provenance(), 'config_sha256': file_digest(installed / 'config.lua'),
        'native_files_preserved': pre['native_files'], 'candidate_freeze_sha256': file_digest(CANDIDATE / 'freeze.json'),
        'normal_exit_inferred': False, 'post_install_processes': processes(), 'activation': 'Unconfirmed; awaits user-started loading'})
    print(json.dumps({'version': '2.219.0-alpha', 'backup': receipt['backup'], 'digest': freeze['candidate_policy_digest'], 'installed_gate': 'pending'}))

if __name__ == '__main__': main()
