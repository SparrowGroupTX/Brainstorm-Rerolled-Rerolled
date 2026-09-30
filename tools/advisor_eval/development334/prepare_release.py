"""Preserve current work and freeze the duplicate-consumable regression candidate."""
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

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def exclusive(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('xb') as f: f.write(data)

prior = read(EVAL / 'runs/hooks333_installed/record.json')['policy']
assert prior['policy_digest'] == 'ed30472fb2227912e521a692afb9152206a5e90918e1d972a321857c269bcfea'
changed = 'Brainstorm/Advisor/consumables.lua'
current = policy_hashes(ROOT)
assert set(current) == set(prior['policy_files'])
for path, digest in prior['policy_files'].items():
    if path != changed: assert current[path] == digest, path
assert sha(HERE / 'before/consumables.lua') == prior['policy_files'][changed]
fixture = HERE / 'test_duplicates.lua'
assert fixture.is_file()
exclusive(ROOT / 'tests/advisor_consumable_duplicates.lua', fixture.read_bytes())
for path in VERSION_FIELDS:
    file = ROOT / 'Brainstorm' / path
    exclusive(HERE / 'before' / path, file.read_bytes())
    stamp_version(file, path, '2.134.0-alpha')
output = EVAL / 'runs/duplicates334_candidate'
output.mkdir(exist_ok=False)
frozen = freeze_product(ROOT, output / 'policy')
exclusive(output / 'freeze.json', (json.dumps(frozen, indent=2) + '\n').encode('utf-8'))
receipt = {
    'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
    'kind': 'routine_manufactured_fixture_runtime_slice',
    'previous_policy_digest': prior['policy_digest'], 'policy_digest': frozen['policy_digest'],
    'changed_runtime': {changed: {'before': prior['policy_files'][changed], 'after': sha(ROOT / changed)}},
    'new_test': {'path': 'tests/advisor_consumable_duplicates.lua', 'sha256': sha(fixture)},
    'source_workers': 0, 'captured_replays': 0, 'complete_attempts': 0, 'searches': 0,
    'game_control': False, 'saves_read': False, 'experiments': 'all historical allowances remain closed',
}
exclusive(HERE / 'integration.json', (json.dumps(receipt, indent=2) + '\n').encode('utf-8'))
print(json.dumps({'policy_digest': frozen['policy_digest'], 'policy_files': len(frozen['policy_files'])}))
