"""Stage auto-only Legendary fallback over verified312, preserving manual routes."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DRAFT=ROOT/'tools/advisor_eval/development300/legendary_opening312'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((DRAFT/'integration_manifest.json').read_text())
record=json.loads((ROOT/'tools/advisor_eval/runs/perkeo312_installed/record.json').read_text())
assert json.loads((ROOT/'tools/advisor_eval/runs/perkeo312_installed_validation/report.json').read_text())['passed']
assert (ROOT/'tools/advisor_eval/runs/perkeo312_final/final_verification.json').exists()
changes={}
for item in manifest['runtime_files']+manifest['fixtures']:
    source=ROOT/item['draft'];target=ROOT/item['target']
    assert sha(source)==item['sha256'],str(source)
    if item.get('base_sha256'):
        assert sha(target)==item['base_sha256']==record['policy']['policy_files'][item['target']]
    else:assert not target.exists(),str(target)
    changes[item['target']]=source.read_bytes()
receipt=HERE/'legendary313_stage.json';assert not receipt.exists()
result={p:{'before_sha256':sha(ROOT/p) if (ROOT/p).exists() else None,
           'after_sha256':hashlib.sha256(data).hexdigest()} for p,data in changes.items()}
for p,data in changes.items():(ROOT/p).write_bytes(data)
with receipt.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
print(json.dumps({'staged':len(changes),'receipt':str(receipt)}))
