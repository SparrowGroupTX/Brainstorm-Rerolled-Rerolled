"""Integrate the reviewed adaptive quota on verified305 while preserving304 fixes."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]
DRAFT=Path(__file__).resolve().parent/'adaptive_quota_rebased'
record=json.loads((ROOT/'tools/advisor_eval/runs/journal305_installed/record.json').read_text())
validation=json.loads((ROOT/'tools/advisor_eval/runs/journal305_installed_validation/report.json').read_text())
test_hashes={name.replace('\\','/'):value for name,value in validation['test_files'].items()}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
runtime=('Brainstorm/Advisor/collection_search.lua','Brainstorm/Core/auto_run_product.lua','Brainstorm/UI/collection_run.lua')
tests=('advisor_collection_query.lua','advisor_auto_run_product.lua','advisor_adaptive_quota.lua')
for name in runtime:assert sha(ROOT/name)==record['policy']['policy_files'][name],name
for name in tests:
    path=ROOT/'tests'/name
    if name=='advisor_adaptive_quota.lua':assert not path.exists(),name
    else:assert sha(path)==test_hashes['tests/'+name],name
for name in runtime:(ROOT/name).write_bytes((DRAFT/name).read_bytes())
for name in tests:
    data=(DRAFT/'tests'/name).read_bytes().replace(b'tools/advisor_eval/development300/adaptive_quota_rebased/',b'')
    assert b'adaptive_quota_rebased' not in data
    (ROOT/'tests'/name).write_bytes(data)
print('Staged three quota runtime files and three reviewed fixtures; startup guards retained.')
