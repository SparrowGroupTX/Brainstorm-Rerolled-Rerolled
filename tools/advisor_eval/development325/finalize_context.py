"""Bind completed release325 validation to fresh documentation; no game access."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
EVAL = ROOT / 'tools/advisor_eval'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def ref(path):
    return {'path': path.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


prepared = EVAL / 'development325/release_notes/context.json'
candidate_path = EVAL / 'runs/resume325_candidate/validation2/report.json'
installed_path = EVAL / 'runs/resume325_installed/record.json'
validation_path = EVAL / 'runs/resume325_installed_validation/report.json'
failed_path = EVAL / 'runs/resume325_candidate/validation/report.json'
candidate, installed, validation = map(read, (candidate_path, installed_path, validation_path))
assert candidate['passed'] and validation['passed']
assert candidate['policy_digest'] == validation['policy_digest'] == installed['policy']['policy_digest']
assert candidate['test_files'] == validation['test_files']
assert installed['version'] == '2.125.0-alpha' and installed['all_repository_files_match']
assert read(failed_path)['passed'] is False
lua = (validation_path.parent / 'lua.log').read_text(encoding='utf-8')
python = (validation_path.parent / 'python.log').read_text(encoding='utf-8')
lua_counts = re.search(r'(\d+)/(\d+) fixtures passed', lua)
assert lua_counts and lua_counts[1] == lua_counts[2]
lua_count = int(lua_counts[1])
python_count = int(re.search(r'Ran (\d+) tests', python)[1])
value = read(prepared)
assert value['status'] == 'CLOSED' and not any(value['release_counts'].values())
value['created_at_utc'] = datetime.now(timezone.utc).isoformat()
value['summary'] = (
    'Release 325 preserves auto-run through ordinary input and adds explicit Stop/Resume '
    'within the same in-memory session, including verified manual checkpoint continuation. '
    'After a cancelled search drains, user-clicked Resume authorizes a distinct new product '
    'search of at most 30 seconds; the prior request remains spent. Candidate validation2 '
    f'and final exact-installed regression passed {lua_count} Lua fixtures and {python_count} '
    'Python tests with unchanged frozen policy/test hashes. The first full regression failure '
    '(two obsolete input-stop expectations) and their original fixtures remain preserved; '
    'the passing replacement validation is separate. No source, captured, search or complete '
    'experiment and no new external player-log read occurred. The original gold299 cycle '
    'remains CLOSED; every count below is historical, with zero release-325 jobs.')
value['preparation_status'] = 'installed_and_exact_regression_passed_activation_unconfirmed'
value['prepared_context_preserved'] = ref(prepared)
value['release_validation'] = {
    'version': installed['version'], 'installed_at': installed['installed_at'],
    'backup': installed['backup'], 'policy_digest': candidate['policy_digest'],
    'lua_fixtures': lua_count, 'python_tests': python_count,
    'candidate': ref(candidate_path), 'installed': ref(installed_path),
    'exact_installed': ref(validation_path), 'first_failed_validation': ref(failed_path),
    'fixture_repair': ref(EVAL / 'development325/resume_tests/behavior_fixture_addendum.json')}
destination = EVAL / 'development325/release_final'
destination.mkdir(exist_ok=False)
path = destination / 'context.json'
with path.open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
    stream.write('\n')
print(json.dumps(ref(path)))
