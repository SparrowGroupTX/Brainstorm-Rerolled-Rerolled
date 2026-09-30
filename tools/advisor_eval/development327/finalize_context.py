"""Bind the completed diagnostic release to fresh, immutable documentation facts."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
EVAL = ROOT / 'tools/advisor_eval'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def ref(path):
    return {'path': path.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


prepared = EVAL / 'development327/release_notes/context.json'
candidate_path = EVAL / 'runs/log327_candidate/validation/report.json'
installed_path = EVAL / 'runs/log327_installed/record.json'
validation_path = EVAL / 'runs/log327_installed_validation/report.json'
candidate, installed, validation = map(read, (candidate_path, installed_path, validation_path))
assert candidate['passed'] and validation['passed']
assert candidate['policy_digest'] == validation['policy_digest'] == installed['policy']['policy_digest']
assert candidate['test_files'] == validation['test_files']
assert installed['version'] == '2.127.0-alpha' and installed['all_repository_files_match']
lua = (validation_path.parent / 'lua.log').read_text(encoding='utf-8')
python = (validation_path.parent / 'python.log').read_text(encoding='utf-8')
counts = re.search(r'(\d+)/(\d+) fixtures passed', lua)
assert counts and counts[1] == counts[2]
lua_count = int(counts[1])
python_count = int(re.search(r'Ran (\d+) tests', python)[1])
audit_path = EVAL / 'development327/audit.json'
audit = read(audit_path)
assert not audit['errors'] and audit['actual']['events'] == 1831
value = read(prepared)
assert value['status'] == 'CLOSED' and not any(value['release_counts'].values())
value['created_at_utc'] = datetime.now(timezone.utc).isoformat()
value['preparation_status'] = 'installed_and_exact_regression_passed_activation_unconfirmed'
value['prepared_context_preserved'] = ref(prepared)
value['summary'] += (
    f' Full candidate and exact-installed validation passed {lua_count} Lua fixtures and '
    f'{python_count} Python tests, with unchanged frozen policy/test hashes. '
    'Release 2.127.0-alpha is installed; activation waits for the user\'s normal restart. '
    'No live post-install speedup is measured.')
value['release_validation'] = {
    'version': installed['version'], 'installed_at': installed['installed_at'],
    'backup': installed['backup'], 'policy_digest': candidate['policy_digest'],
    'lua_fixtures': lua_count, 'python_tests': python_count,
    'candidate': ref(candidate_path), 'installed': ref(installed_path),
    'exact_installed': ref(validation_path), 'selected_public_log_audit': ref(audit_path)}
destination = EVAL / 'development327/release_final'
destination.mkdir(exist_ok=False)
path = destination / 'context.json'
with path.open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
    stream.write('\n')
print(json.dumps(ref(path)))
