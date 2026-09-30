"""Stage the reviewed whole Perkeo Planet slice over verified311."""
from pathlib import Path
import hashlib,json

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
DRAFT=HERE/'drafts/perkeo_planets'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report=json.loads((DRAFT/'focused_report.json').read_text())
assert report['exit_code']==0 and report['fixtures_passed']==10
for p,h in report['files_sha256'].items():assert sha(ROOT/p)==h,p
record=json.loads((ROOT/'tools/advisor_eval/runs/pack311_installed/record.json').read_text())
assert json.loads((ROOT/'tools/advisor_eval/runs/pack311_installed_validation/report.json').read_text())['passed']
assert (ROOT/'tools/advisor_eval/runs/pack311_final/final_verification.json').exists()
changes={}
for name in ('perkeo_inventory','gold_planet_policy','gold_goal','gold_perkeo','snapshot','decision'):
    target=ROOT/'Brainstorm/Advisor'/f'{name}.lua'
    key=str(target.relative_to(ROOT));base=report['base_sha256'].get(key)
    if base:assert sha(target)==base==record['policy']['policy_files'][key.replace('\\','/')]
    else:assert not target.exists(),str(target)
    changes[key]=(DRAFT/f'{name}.lua').read_bytes()
name='Brainstorm/Advisor/runtime.lua';target=ROOT/name
assert sha(target)==record['policy']['policy_files'][name]
text=target.read_text();old="A.gold_perkeo = module('gold_perkeo')"
assert text.count(old)==1
text=text.replace(old,old+"\nA.perkeo_inventory = module('perkeo_inventory')\nA.gold_planet_policy = module('gold_planet_policy')\nA.snapshot.perkeo_inventory = A.perkeo_inventory")
changes[name]=text.encode()
for name in ('advisor_perkeo_inventory.lua','advisor_gold_planet_policy.lua'):
    target=ROOT/'tests'/name;assert not target.exists()
    changes[str(target.relative_to(ROOT))]=(DRAFT/('install_'+name)).read_bytes()
receipt=HERE/'perkeo312_stage.json';assert not receipt.exists()
result={p:{'before_sha256':sha(ROOT/p) if (ROOT/p).exists() else None,
           'after_sha256':hashlib.sha256(data).hexdigest()} for p,data in changes.items()}
for p,data in changes.items():(ROOT/p).write_bytes(data)
with receipt.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
print(json.dumps({'staged':len(changes),'receipt':str(receipt)}))
