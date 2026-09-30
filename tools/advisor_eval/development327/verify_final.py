"""Read-only final file/hash verification; no log decoding or game interaction."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
EVAL = ROOT / 'tools/advisor_eval'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


final_path = EVAL / 'runs/log327_final/final_verification.json'
final = read(final_path)
for relative, expected in final['documents'].items():
    assert sha(ROOT / relative) == expected, relative
for relative, expected in final['preserved_documents'].items():
    assert sha(ROOT / relative) == expected, relative
record = read(EVAL / 'runs/log327_installed/record.json')
installed = Path(record['installed'])
for relative, expected in record['policy']['policy_files'].items():
    assert sha(ROOT / relative) == expected == sha(installed.parent / relative), relative
capture = read(EVAL / 'development327/capture.json')
for item in capture['files']:
    assert sha(Path(item['captured_path'])) == item['sha256'], item['captured_path']
assert final['native_unchanged'] and final['config_restored_or_modified_by_finalizer'] is False
assert record['all_repository_files_match']
receipt = {
    'at_utc': datetime.now(timezone.utc).isoformat(),
    'status': 'passed', 'version': final['version'],
    'final_verification_sha256': sha(final_path),
    'documents_checked': len(final['documents']),
    'previous_documents_checked': len(final['preserved_documents']),
    'repository_and_installed_files_checked': len(record['policy']['policy_files']),
    'captured_original_files_unchanged': len(capture['files']),
    'native_files_preserved': len(final['existing_native_files_preserved']),
    'config_changed_since_install': final['config_changed_since_install'],
    'source_search_simulation_game_control_save_access': False,
}
output = EVAL / 'development327/post_finalize_verification.json'
with output.open('x', encoding='utf-8') as stream:
    json.dump(receipt, stream, indent=2)
    stream.write('\n')
print(json.dumps(receipt))
