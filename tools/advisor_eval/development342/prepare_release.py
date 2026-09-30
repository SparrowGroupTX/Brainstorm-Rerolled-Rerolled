"""Integrate only the reviewed staged presentation repair, then freeze it."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = EVAL.parents[1]
STAGE = HERE / 'presentation_component'
sys.path.insert(0, str(EVAL))
from benchmark import policy_hashes
from install_slice import stamp_version, VERSION_FIELDS
from paired_policy_audit import freeze_product

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream: stream.write(data)

prior = read(EVAL / 'runs/terminal341_installed/record.json')['policy']
assert policy_hashes(ROOT) == prior['policy_files']
entries = read(STAGE / 'before_hashes.json')['files']
receipt_path = STAGE / 'result.json'
receipt = read(receipt_path)
assert receipt['status'] == 'staged_review_ready' and receipt['production_paths_written'] is False
sealed = {entry['destination']: entry for entry in receipt['files']}
allowed = {'Brainstorm/Advisor/acorn_public.lua', 'Brainstorm/Advisor/snapshot.lua',
           'Brainstorm/Advisor/gold_stickers.lua', 'tests/advisor_acorn_public.lua',
           'tests/advisor_gold_stickers.lua'}
assert {entry['path'] for entry in entries} == allowed
assert set(sealed) == allowed
for entry in entries:
    name, digest = entry['path'], entry['sha256']
    assert sha(ROOT / name) == sha(STAGE / 'before' / name) == digest, name
    assert sealed[name]['before_sha256'] == digest
    assert sha(STAGE / name) == sealed[name]['after_sha256']
passed = False
for validation in receipt['validation']['receipts']:
    path = ROOT / validation['path']
    assert sha(path) == validation['sha256']
    if validation['exit_code'] == 0:
        assert read(path)['exit_code'] == 0
        passed = True
assert passed
for name, evidence in receipt['source_provenance'].items(): assert sha(ROOT / name) == evidence['sha256']

integration = {'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
    'previous_policy_digest': prior['policy_digest'], 'files': {},
    'new_experiments': 0, 'game_control': False, 'save_or_profile_reads': False,
    'source_search_attempt_authority': 'closed',
    'staged_result': {'path': receipt_path.relative_to(ROOT).as_posix(), 'sha256': sha(receipt_path)}}
for entry in entries:
    name = entry['path']
    integration['files'][name] = {'before': entry['sha256'], 'after': sha(STAGE / name)}
    (ROOT / name).write_bytes((STAGE / name).read_bytes())
for name in VERSION_FIELDS:
    path = ROOT / 'Brainstorm' / name
    write(HERE / 'before' / 'Brainstorm' / name, path.read_bytes())
    stamp_version(path, name, '2.142.0-alpha')
out = EVAL / 'runs/presentation342_candidate'
out.mkdir(exist_ok=False)
policy = freeze_product(ROOT, out / 'policy')
integration['policy_digest'] = policy['policy_digest']
write(out / 'freeze.json', (json.dumps(policy, indent=2) + '\n').encode())
write(HERE / 'integration.json', (json.dumps(integration, indent=2) + '\n').encode())
print(json.dumps({'policy_digest': policy['policy_digest'], 'policy_files': len(policy['policy_files'])}))
