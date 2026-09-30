"""Preserve the blocked preflight and choose a genuinely new production test."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
old_test = ROOT / 'tests/advisor_scoring_reuse.lua'
record = {
    'kind': 'root_reported_prepare_preflight_block',
    'reason': 'Planned test path already exists in prior frozen tests; no preparation writes occurred.',
    'existing_test': str(old_test.relative_to(ROOT)),
    'existing_test_sha256': hashlib.sha256(old_test.read_bytes()).hexdigest(),
    'new_test': 'tests/advisor_scoring_work336.lua',
    'before_exists': (HERE / 'before').exists(),
    'integration_exists': (HERE / 'integration.json').exists(),
    'candidate_freeze_exists': (ROOT / 'tools/advisor_eval/runs/scoring336_candidate').exists(),
}
assert not any(record[key] for key in ('before_exists', 'integration_exists', 'candidate_freeze_exists'))
with (HERE / 'blocked_test_path_preflight.json').open('x', encoding='utf-8') as stream:
    json.dump(record, stream, indent=2)
    stream.write('\n')
for name in ('prepare_release.py', 'prepare_context.py', 'run_staged_fixture.py', 'README.md',
             'notes/COMPONENT_DRAFT.md', 'notes/ARCHITECTURE_DRAFT.md'):
    path = HERE / name
    prior = path.read_bytes()
    preserved = HERE / 'before_fixture_rename' / name
    preserved.parent.mkdir(parents=True, exist_ok=True)
    with preserved.open('xb') as stream:
        stream.write(prior)
    text = prior.decode('utf-8').replace('tests/advisor_scoring_reuse.lua', 'tests/advisor_scoring_work336.lua')
    if name in ('prepare_release.py', 'prepare_context.py', 'README.md', 'notes/COMPONENT_DRAFT.md'):
        text = text.replace('standalone_validation2', 'standalone_validation3')
    path.write_bytes(text.encode('utf-8'))
print(json.dumps(record, indent=2))
