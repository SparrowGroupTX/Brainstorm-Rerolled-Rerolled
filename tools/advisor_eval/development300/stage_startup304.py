"""Stage only the reviewed shared-start readiness repair."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]
DRAFT=Path(__file__).resolve().parent/'startup_loading_fix'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base=json.loads((DRAFT/'original_hashes.json').read_text())
for name,want in base.items():assert sha(ROOT/name)==want,name
for name in ('collection_search_product.lua','auto_run_product.lua'):
    (ROOT/'Brainstorm/Core'/name).write_bytes((DRAFT/'Brainstorm/Core'/name).read_bytes())
prefix=b'tools/advisor_eval/development300/startup_loading_fix/'
for name in ('advisor_collection_product.lua','advisor_auto_run_product.lua'):
    data=(DRAFT/'tests'/name).read_bytes()
    data=data.replace(prefix,b'')
    assert b'development300/startup_loading_fix' not in data
    (ROOT/'tests'/name).write_bytes(data)
print('Staged two guarded Core modules and two corresponding fixtures.')
