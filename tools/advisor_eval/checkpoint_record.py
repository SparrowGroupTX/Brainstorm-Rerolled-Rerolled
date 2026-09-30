"""Record and freeze the installed advisor without reading saves or controlling the game."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import json
import subprocess
from paired_policy_audit import freeze_product
from benchmark import file_digest

ROOT = Path(__file__).resolve().parents[2]
INSTALLED = Path('C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm')

def record(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    manifests = sorted((INSTALLED / 'deployment-backups').glob('*/deployment.json'),
                       key=lambda path: path.stat().st_mtime_ns)
    manifest_path = manifests[-1]
    manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    policy = freeze_product(INSTALLED.parent, output / 'policy')
    files = []
    for relative, installed_hash in policy['policy_files'].items():
        source = ROOT / relative
        files.append({'path': relative, 'installed_sha256': installed_hash,
                      'repository_sha256': file_digest(source) if source.exists() else None,
                      'matches': source.exists() and file_digest(source) == installed_hash})
    result = {'schema': 1, 'verified_at_utc': datetime.now(timezone.utc).isoformat(),
              'version': manifest['version'], 'installed_at': manifest['installedAt'],
              'installed': str(INSTALLED), 'backup': str(manifest_path.parent),
              'deployment_manifest': str(manifest_path),
              'config_sha256': file_digest(INSTALLED / 'config.lua'),
              'saves': 'Not read or written', 'game_control': 'None; loaded version unknown',
              'policy': policy, 'runtime_files': files,
              'all_repository_files_match': all(entry['matches'] for entry in files),
              'git_status': subprocess.check_output(['git','status','--short'], cwd=ROOT, text=True),
              'branch': subprocess.check_output(['git','branch','--show-current'], cwd=ROOT, text=True).strip()}
    (output / 'record.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: result[key] for key in ('version','backup','all_repository_files_match')}))
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    record(parser.parse_args().output)
