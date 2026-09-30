"""Bind completed storage326 installation to fresh documentation only."""
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


prepared = EVAL / 'development326/release_notes/context.json'
candidate_path = EVAL / 'runs/storage326_candidate/validation/report.json'
installed_path = EVAL / 'runs/storage326_installed/record.json'
validation_path = EVAL / 'runs/storage326_installed_validation/report.json'
candidate, installed, validation = map(read, (candidate_path, installed_path, validation_path))
assert candidate['passed'] and validation['passed']
assert candidate['policy_digest'] == validation['policy_digest'] == installed['policy']['policy_digest']
assert candidate['test_files'] == validation['test_files']
assert installed['version'] == '2.126.0-alpha' and installed['all_repository_files_match']
lua = (validation_path.parent / 'lua.log').read_text(encoding='utf-8')
python = (validation_path.parent / 'python.log').read_text(encoding='utf-8')
counts = re.search(r'(\d+)/(\d+) fixtures passed', lua)
assert counts and counts[1] == counts[2]
lua_count = int(counts[1])
python_count = int(re.search(r'Ran (\d+) tests', python)[1])
cleanup_path = EVAL / 'development326/log_cleanup.json'
cleanup = read(cleanup_path)
assert cleanup['status'] == 'complete_directories_empty'
assert cleanup['removedFiles'] == 53 and cleanup['removedBytes'] == 134216592
assert not cleanup['remainingEntries']
value = read(prepared)
assert value['status'] == 'CLOSED' and not any(value['release_counts'].values())
value['created_at_utc'] = datetime.now(timezone.utc).isoformat()
value['summary'] = (
    'Release 326 installs the user-authorized 1 GiB combined observation-log allowance, '
    'readable persistent recording errors, and no periodic disk writes during an idle title '
    'screen. Bounded timing metrics remain in memory until activity resumes. The user also '
    'explicitly requested deletion of prior observation logs: 53 direct files totaling '
    '134,216,592 bytes were removed from the v1/v2 folders, verified empty at cleanup. '
    'Saves, checkpoints and repository evidence were not targets. Historical external log '
    'originals are therefore no longer preserved, while repository audit receipts remain. '
    f'Full candidate and exact-installed validation passed {lua_count} Lua fixtures and '
    f'{python_count} Python tests with unchanged frozen policy/test hashes. No log contents '
    'were decoded, no game was controlled and no source/captured/search/complete experiment '
    'occurred. All historical experiment authority remains CLOSED. Activation and a fresh '
    'recorder wait for the next normal restart; user-reported prior restart does not attest '
    'loaded version or hashes.')
value['preparation_status'] = 'installed_and_exact_regression_passed_activation_unconfirmed'
value['prepared_context_preserved'] = ref(prepared)
value['release_validation'] = {
    'version': installed['version'], 'installed_at': installed['installed_at'],
    'backup': installed['backup'], 'policy_digest': candidate['policy_digest'],
    'lua_fixtures': lua_count, 'python_tests': python_count,
    'candidate': ref(candidate_path), 'installed': ref(installed_path),
    'exact_installed': ref(validation_path), 'user_authorized_cleanup': ref(cleanup_path)}
destination = EVAL / 'development326/release_final'
destination.mkdir(exist_ok=False)
path = destination / 'context.json'
with path.open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
    stream.write('\n')
print(json.dumps(ref(path)))
