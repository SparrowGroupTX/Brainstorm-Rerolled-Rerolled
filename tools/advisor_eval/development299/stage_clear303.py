"""Stage reviewed303 draft only when all original runtime inputs still match."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
DRAFT=Path(__file__).resolve().parent/'drafts/clear_budget303'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ready=json.loads((DRAFT/'READY_SHA256.json').read_text())
base=json.loads((DRAFT/'integration_base_sha256.json').read_text())
for name,want in ready['files'].items():
    assert sha(DRAFT/name)==want,name
for name,want in base.items():
    assert sha(ROOT/name)==want,name
for name in base:
    path=ROOT/name
    path.write_bytes((DRAFT/path.name).read_bytes())
for name in ('advisor_clear_budget.lua','advisor_fast_clear.lua','advisor_retry_policy.lua'):
    (ROOT/'tests'/name).write_bytes((DRAFT/('install_'+name)).read_bytes())
print('Staged four guarded runtime modules and three reviewed fixtures.')
