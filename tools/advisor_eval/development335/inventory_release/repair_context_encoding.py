"""Preserve the failed docs preparation and normalize two Windows-encoded drafts."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json

HERE = Path(__file__).resolve().parent
archive = HERE / 'context_encoding_failure1'
archive.mkdir(exist_ok=False)

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

preserved = {}
for name in ('prepare_context.py', 'COMPONENT_DRAFT.md', 'ARCHITECTURE_DRAFT.md'):
    source = HERE / name
    raw = source.read_bytes()
    with (archive / name).open('xb') as stream:
        stream.write(raw)
    preserved[name] = sha(raw)
partial = HERE / 'release_context/context.json'
record = {
    'kind': 'documentation_preparation_encoding_error',
    'created_at_utc': datetime.now(timezone.utc).isoformat(),
    'failed_command': 'python tools/advisor_eval/development335/inventory_release/prepare_context.py',
    'exit_code': 1,
    'error': "UnicodeDecodeError: utf-8 cannot decode byte 0x97 at position 33 in COMPONENT_DRAFT.md",
    'preserved_files': preserved,
    'preserved_partial_context': {'path': 'release_context/context.json', 'sha256': sha(partial.read_bytes())},
    'runtime_changes': 0,
    'regressions_failed': 0,
    'experiments_started': 0,
    'recovery': 'Normalize the two cp1252 drafts to UTF-8; preserve original preparation and partial context; write replacement context in release_context_v2.'
}
with (archive / 'record.json').open('x', encoding='utf-8') as stream:
    json.dump(record, stream, indent=2)
    stream.write('\n')
for name in ('COMPONENT_DRAFT.md', 'ARCHITECTURE_DRAFT.md'):
    source = HERE / name
    raw = source.read_bytes()
    assert sha(raw) == preserved[name]
    source.write_bytes(raw.decode('cp1252').encode('utf-8'))
script = HERE / 'prepare_context.py'
text = script.read_text(encoding='utf-8')
text = text.replace("out=HERE/'release_context';out.mkdir(exist_ok=False)", "out=HERE/'release_context_v2';out.mkdir(exist_ok=False)")
text = text.replace("'before_consumables':", "'preserved_docs_encoding_failure':HERE/'context_encoding_failure1/record.json',\n      'preserved_partial_context':HERE/'release_context/context.json',\n      'before_consumables':")
assert "out=HERE/'release_context_v2'" in text
script.write_text(text, encoding='utf-8', newline='\n')
print(json.dumps(record))
