"""Freeze the manufactured terminal-screen repair; grants no experiment jobs."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import policy_hashes
from install_slice import stamp_version, VERSION_FIELDS
from paired_policy_audit import freeze_product

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream: stream.write(data)

prior = read(EVAL / 'runs/acorn340_installed/record.json')['policy']
changed = {'Brainstorm/Advisor/auto_run.lua', 'Brainstorm/Core/auto_run_product.lua'}
current = policy_hashes(ROOT)
assert current.keys() == prior['policy_files'].keys()
for name, digest in prior['policy_files'].items():
    if name not in changed: assert current[name] == digest, name
for entry in read(HERE / 'terminal_component/before.json'):
    assert sha(HERE / 'terminal_component/before' / entry['path']) == entry['sha256'], entry['path']
    if entry['path'] in changed: assert entry['sha256'] == prior['policy_files'][entry['path']]

versions = {}
for name in VERSION_FIELDS:
    path = ROOT / 'Brainstorm' / name
    versions['Brainstorm/' + name] = sha(path)
    write(HERE / 'before' / 'Brainstorm' / name, path.read_bytes())
    stamp_version(path, name, '2.141.0-alpha')
out = EVAL / 'runs/terminal341_candidate'
out.mkdir(exist_ok=False)
policy = freeze_product(ROOT, out / 'policy')
write(out / 'freeze.json', (json.dumps(policy, indent=2) + '\n').encode())
integration = {
    'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
    'previous_policy_digest': prior['policy_digest'], 'policy_digest': policy['policy_digest'],
    'changed_runtime': {name: {'before': prior['policy_files'][name], 'after': sha(ROOT / name)} for name in sorted(changed)},
    'version_before': versions,
    'new_experiments': 0, 'source_search_attempt_authority': 'closed',
    'game_control': False, 'save_or_profile_reads': False,
}
write(HERE / 'integration.json', (json.dumps(integration, indent=2) + '\n').encode())
print(json.dumps({'policy_digest': policy['policy_digest'], 'policy_files': len(policy['policy_files'])}))
