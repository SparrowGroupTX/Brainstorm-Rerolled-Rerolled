"""Record the separately authored current snapshot dependency after review."""
from pathlib import Path
import hashlib
import json
import difflib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
manifest_path = HERE / 'base_manifest.json'
base = json.loads(manifest_path.read_text(encoding='utf-8'))
key = 'Brainstorm/Advisor/snapshot.lua'
prior_path = ROOT / 'tools/advisor_eval/runs/pace322_installed/policy' / key
current_path = ROOT / key
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(prior_path) == base['files'][key]
expected = 'bfabf63f93db6d5ccb74f7976298ebfa3be7f9cca01494e90478617b070278c5'
assert sha(current_path) == expected
rebind = {
    'schema': 1, 'kind': 'separate_root_dependency_change', 'file': key,
    'before_sha256': sha(prior_path), 'after_sha256': expected,
    'preserved_before': str(prior_path.relative_to(ROOT)),
    'review': 'Only excludes current_round.current_hand HUD aggregate during snapshot capture; copy and fingerprint implementations unchanged. Root owns qualification of that separate runtime change.',
    'diff': ''.join(difflib.unified_diff(prior_path.read_text().splitlines(True), current_path.read_text().splitlines(True))),
    'requires_repeat_manufactured_validation': True,
}
(HERE / 'dependency_rebind.json').write_text(json.dumps(rebind, indent=2) + '\n', encoding='utf-8')
base['files'][key] = expected
base['dependency_rebind'] = 'dependency_rebind.json'
manifest_path.write_text(json.dumps(base, indent=2) + '\n', encoding='utf-8')
(HERE / 'guard_errors.json').write_text(json.dumps({
    'schema': 1, 'kind': 'preparation_integrity_guards', 'fixture_failure': False, 'staged': False,
    'errors': [
        {'command': 'finalize.py', 'exit_code': 1, 'reason': 'Original snapshot dependency hash changed concurrently; all production dependency assertion rejected finalization.'},
        {'command': 'stage.py', 'exit_code': 1, 'reason': 'Old v1 manifest correctly rejected revised candidate hash; no production writes.'},
    ],
    'resolution': 'Explicit dependency review/rebind and fresh fixture validation before revised manifest; original v1 inputs remain preserved.',
}, indent=2) + '\n', encoding='utf-8')
