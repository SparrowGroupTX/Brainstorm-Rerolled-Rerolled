"""Freeze and verify release 369 without reading saves or controlling the game."""

from datetime import datetime, timezone
from pathlib import Path
import json
import shutil
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes, policy_sources  # noqa: E402

INSTALLED = Path('C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm')
OUT = EVAL / 'runs/hex369_installed'
CANDIDATE = EVAL / 'runs/hex369_candidate'
BACKUP = INSTALLED / 'deployment-backups/advisor-20260923-022408'


def main():
    pre = json.loads((OUT / 'preinstall.json').read_text(encoding='utf-8'))
    deployment = json.loads((BACKUP / 'deployment.json').read_text(encoding='utf-8'))
    assert deployment['version'] == '2.169.0-alpha'
    assert Path(deployment['backup']) == BACKUP
    assert len(deployment['files']) == 89
    deployed = {}
    for entry in deployment['files']:
        relative = entry['path'].replace('\\', '/')
        installed = (INSTALLED / relative).resolve()
        installed.relative_to(INSTALLED.resolve())
        actual = file_digest(installed)
        assert actual == entry['after'].lower(), relative
        deployed[relative] = actual
    config = INSTALLED / 'config.lua'
    assert file_digest(config) == pre['config_sha256']
    natives = {f.name: file_digest(f) for f in sorted(INSTALLED.glob('*.dll'))}
    assert len(natives) == 7 and natives == pre['native_files']
    repository = policy_hashes(ROOT)
    installed_hashes = policy_hashes(INSTALLED.parent)
    candidate_hashes = policy_hashes(CANDIDATE / 'policy')
    assert len(repository) == len(installed_hashes) == len(candidate_hashes) == 105
    assert repository == installed_hashes == candidate_hashes
    frozen = OUT / 'policy'
    frozen.mkdir(exist_ok=False)
    for source in policy_sources(INSTALLED.parent):
        relative = source.relative_to(INSTALLED.parent)
        target = frozen / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    assert policy_hashes(frozen) == repository
    result = {
        'schema': 1,
        'verified_at_utc': datetime.now(timezone.utc).isoformat(),
        'version': deployment['version'],
        'installed_at': deployment['installedAt'],
        'installed': str(INSTALLED),
        'backup': str(BACKUP),
        'config_sha256': pre['config_sha256'],
        'native_files_preserved': natives,
        'deployed_files': deployed,
        'policy_digest': digest(repository),
        'policy_files': repository,
        'all_89_deployment_files_match': True,
        'all_105_runtime_dependency_files_match': True,
        'config_unchanged': True,
        'native_unchanged': True,
        'saves': 'Not read or written',
        'game_control': 'None; activation requires a normal user restart',
    }
    (OUT / 'record.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'version': result['version'], 'policy_digest': result['policy_digest'],
                      'deployment_files': len(deployed), 'runtime_files': len(repository),
                      'config_unchanged': True, 'native_files': len(natives)}))


if __name__ == '__main__':
    main()
