"""Stage reviewed Certificate comparison over the verified308 bytes."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DRAFT=HERE/'drafts/certificate_opening'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((DRAFT/'integration_manifest.json').read_text())
record=json.loads((ROOT/'tools/advisor_eval/runs/gold308_installed/record.json').read_text())
assert json.loads((ROOT/'tools/advisor_eval/runs/gold308_installed_validation/report.json').read_text())['passed']
changes={}
for item in manifest['drafts']:
    source=ROOT/item['draft'];assert sha(source)==item['sha256'],str(source)
    if not item['target']:continue
    target=ROOT/item['target']
    if item['base_sha256']:
        assert sha(target)==item['base_sha256']==record['policy']['policy_files'][item['target']]
    else:assert not target.exists(),str(target)
    data=source.read_text()
    if item['target'].startswith('tests/'):
        data=data.replace(DRAFT.relative_to(ROOT).as_posix()+'/', 'Brainstorm/Advisor/')
        assert 'development299/drafts/' not in data
    changes[item['target']]=data
name='Brainstorm/Advisor/runtime.lua'
assert sha(ROOT/name)==record['policy']['policy_files'][name]
runtime=(ROOT/name).read_text()
old="A.bell_opening = module('bell_opening')"
assert runtime.count(old)==1
runtime=runtime.replace(old,old+"\nA.certificate=module('certificate')\nA.snapshot.certificate=A.certificate")
old='A.shop_scoring.bell_opening=A.bell_opening'
assert runtime.count(old)==1
runtime=runtime.replace(old,old+'\nA.shop_scoring.certificate=A.certificate')
changes[name]=runtime
receipt=HERE/'certificate309_stage.json';assert not receipt.exists()
result={p:{'before_sha256':sha(ROOT/p) if (ROOT/p).exists() else None,
           'after_sha256':hashlib.sha256(data.encode()).hexdigest()} for p,data in changes.items()}
for p,data in changes.items():
    with (ROOT/p).open('w',encoding='utf-8',newline='\n') as stream:stream.write(data)
with receipt.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
print(json.dumps({'staged':len(changes),'receipt':str(receipt)}))
