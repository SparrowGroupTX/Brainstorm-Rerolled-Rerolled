"""Stage reviewed fallback and start-status fixes over verified306, no experiment."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
DRAFT=Path(__file__).resolve().parent/'burnt_fallback'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
record=json.loads((ROOT/'tools/advisor_eval/runs/quota306_installed/record.json').read_text())
validation=json.loads((ROOT/'tools/advisor_eval/runs/quota306_installed_validation/report.json').read_text())
assert validation['passed']
known={k.replace('\\','/'):v for k,v in validation['test_files'].items()}
runtime=('Brainstorm/Advisor/collection_search.lua','Brainstorm/Core/collection_search_product.lua',
         'Brainstorm/Core/auto_run_product.lua','Brainstorm/UI/collection_run.lua')
fixtures=('advisor_collection_query.lua','advisor_adaptive_quota.lua','advisor_auto_run_product.lua',
          'advisor_collection_product.lua','advisor_burnt_fallback.lua','advisor_collection_status.lua')
changes={}
for name in runtime:
    assert sha(ROOT/name)==record['policy']['policy_files'][name],name
    changes[name]=(DRAFT/name).read_bytes()
for name in fixtures:
    path=ROOT/'tests'/name
    if name in ('advisor_burnt_fallback.lua','advisor_collection_status.lua'):assert not path.exists(),name
    else:assert sha(path)==known['tests/'+name],name
    data=(DRAFT/'tests'/name).read_bytes()
    data=data.replace(b'tools/advisor_eval/development300/burnt_fallback/',b'')
    assert b'burnt_fallback/' not in data,name
    changes['tests/'+name]=data
# Preflight every input before changing anything. Existing dirty work is the
# installed306 baseline, not a Git checkout to restore.
receipt={name:{'before_sha256':sha(ROOT/name) if (ROOT/name).exists() else None,
               'after_sha256':hashlib.sha256(data).hexdigest()} for name,data in changes.items()}
target=DRAFT/'root_stage307.json'
assert not target.exists()
for name,data in changes.items():(ROOT/name).write_bytes(data)
with target.open('x') as stream:json.dump(receipt,stream,indent=2);stream.write('\n')
print(json.dumps({'runtime_files':len(runtime),'fixtures':len(fixtures),'receipt':str(target)}))
