"""Stage reviewed journal archive without altering existing logs or settings."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
DRAFT=Path(__file__).resolve().parent/'drafts/journal_v2'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
package=json.loads((DRAFT/'package.json').read_text())
for name,want in package['base_files_sha256'].items():assert sha(ROOT/name)==want,name
for item in package['files']:
    assert sha(DRAFT/item['source'])==item['sha256'],item['source']
    dest=item['destination']
    if dest=='tests/test_player_log_archive.py':dest='tests/test_advisor_player_log_archive.py'
    target=ROOT/dest
    if item['source']!='player_journal.lua':assert not target.exists(),dest
for item in package['files']:
    dest=item['destination']
    if dest=='tests/test_player_log_archive.py':dest='tests/test_advisor_player_log_archive.py'
    (ROOT/dest).write_bytes((DRAFT/item['source']).read_bytes())
runtime=ROOT/'Brainstorm/Advisor/runtime.lua';data=runtime.read_bytes()
old=b"A.player_journal=module('player_journal')"
assert data.count(old)==1
runtime.write_bytes(data.replace(old,b"A.player_log_archive=module('player_log_archive')\r\n"+old))
print('Staged archive/journal/runtime, exact reader, and discoverable regression test.')
