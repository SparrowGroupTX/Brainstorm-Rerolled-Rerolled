"""Root-executed promotion of the reviewed scoring-only 2.136 candidate.

Refuse all production drift from the complete previous installed335 policy.
This prepares a freeze; it does not install, control the game or run searches.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parents[1]
ROOT = EVAL.parents[1]
COMPONENT = HERE.parent / 'scoring_component'
sys.path.insert(0, str(EVAL))
from benchmark import policy_hashes, digest
from install_slice import stamp_version, VERSION_FIELDS
from paired_policy_audit import freeze_product

BASELINE = 'b77a211cf2480d55008dc96e993b66d380a92e4e466d44f58b25a9e9bc0a11cf'
CANDIDATE = 'f625c294eb5ba9cf0b6da5eb8f871c58be0835aecf92396c09151becef1c80e9'
FIXTURE = '9bbe84a8b4119c82bb788792789d1cbd3896ce179c484586da8f0fd94a998fee'
CHANGED = 'Brainstorm/Advisor/scoring.lua'
TEST = 'tests/advisor_scoring_reuse.lua'
BASELINE_TEST = 'tests/fixtures/advisor_scoring_reuse336/scoring_before.lua'
VERSION = '2.136.0-alpha'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def exclusive(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream: stream.write(data)
def ref(path): return {'path': path.relative_to(ROOT).as_posix(), 'sha256': sha(path)}

previous_record = EVAL / 'runs/journal335_installed/record.json'
previous = read(previous_record)
assert previous['version'] == '2.135.0-alpha'
prior = previous['policy']
assert prior['policy_digest'] == digest(prior['policy_files'])
assert policy_hashes(EVAL / 'runs/journal335_installed/policy') == prior['policy_files']
assert policy_hashes(ROOT) == prior['policy_files'], 'Worktree must equal whole installed335 policy'
assert prior['policy_files'][CHANGED] == BASELINE
assert sha(COMPONENT / 'scoring_before.lua') == BASELINE
assert sha(COMPONENT / 'scoring.lua') == CANDIDATE
assert sha(HERE / 'advisor_scoring_reuse.lua') == FIXTURE
component_receipt = read(COMPONENT / 'fixture_receipt3.json')
standalone_receipt = read(HERE / 'standalone_validation2/receipt.json')
assert component_receipt['exit_code'] == standalone_receipt['exit_code'] == 0
assert component_receipt['sha256']['scoring.lua'] == CANDIDATE
assert standalone_receipt['files'][CHANGED] == CANDIDATE
assert standalone_receipt['files'][TEST] == FIXTURE
assert sha(HERE / 'standalone_validation2/tests/advisor_scoring_reuse.lua') == FIXTURE
assert sha(HERE / 'standalone_validation2/Brainstorm/Advisor/scoring.lua') == CANDIDATE
for relative, expression in VERSION_FIELDS.items():
    matches = list(expression.finditer((ROOT / 'Brainstorm' / relative).read_bytes()))
    assert len(matches) == 1 and matches[0].group('version') == b'2.135.0-alpha', relative
outputs = [HERE / 'integration.json', ROOT / TEST, ROOT / BASELINE_TEST,
           EVAL / 'runs/scoring336_candidate', HERE / 'before']
assert all(not path.exists() for path in outputs), 'Fresh promotion destinations required'

# Preserve all changed bytes before the first production mutation.
for relative in [CHANGED] + ['Brainstorm/' + name for name in VERSION_FIELDS]:
    exclusive(HERE / 'before' / relative, (ROOT / relative).read_bytes())
exclusive(HERE / 'before/previous_installed_record.json', previous_record.read_bytes())
exclusive(ROOT / TEST, (HERE / 'advisor_scoring_reuse.lua').read_bytes())
exclusive(ROOT / BASELINE_TEST, (COMPONENT / 'scoring_before.lua').read_bytes())
(ROOT / CHANGED).write_bytes((COMPONENT / 'scoring.lua').read_bytes())
for relative in VERSION_FIELDS:
    stamp_version(ROOT / 'Brainstorm' / relative, relative, VERSION)

current = policy_hashes(ROOT)
changed_paths = {path for path in current if current[path] != prior['policy_files'][path]}
allowed = {CHANGED} | {'Brainstorm/' + path for path in VERSION_FIELDS}
assert set(current) == set(prior['policy_files']) and changed_paths == allowed
assert sha(ROOT / CHANGED) == CANDIDATE
output = EVAL / 'runs/scoring336_candidate'
output.mkdir(exist_ok=False)
frozen = freeze_product(ROOT, output / 'policy')
exclusive(output / 'freeze.json', (json.dumps(frozen, indent=2)+'\n').encode('utf-8'))
receipt = {
    'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
    'kind': 'routine_manufactured_fixture_runtime_slice', 'release': 336, 'version': VERSION,
    'previous_release': 335, 'previous_installed_record': ref(previous_record),
    'previous_policy_digest': prior['policy_digest'], 'policy_digest': frozen['policy_digest'],
    'changed_runtime': {path: {'before': prior['policy_files'][path], 'after': current[path]}
                        for path in sorted(changed_paths)},
    'new_test': {'path': TEST, 'sha256': sha(ROOT / TEST)},
    'new_test_dependencies': [{'path': BASELINE_TEST, 'sha256': sha(ROOT / BASELINE_TEST)}],
    'fixture_dependency_scope': 'All Lua fixture dependencies are under tests and frozen by validate_checkpoint.',
    'source_workers': 0, 'captured_replays': 0, 'complete_attempts': 0, 'searches': 0,
    'game_control': False, 'saves_read': False, 'experiments': 'all historical allowances remain closed',
}
exclusive(HERE / 'integration.json', (json.dumps(receipt, indent=2)+'\n').encode('utf-8'))
print(json.dumps({'policy_digest': frozen['policy_digest'], 'policy_files': len(frozen['policy_files']),
                  'new_test': receipt['new_test'], 'test_dependencies': receipt['new_test_dependencies']}))
