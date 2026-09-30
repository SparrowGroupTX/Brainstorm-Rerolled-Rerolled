"""Compose the cash-copy slice on top of the verified inventory337 installation."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, sys
HERE=Path(__file__).resolve().parent
DEV=HERE.parent;EVAL=DEV.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from install_slice import stamp_version,VERSION_FIELDS
from paired_policy_audit import freeze_product
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,raw):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(raw)
prior=read(EVAL/'runs/inventory337_installed/record.json')['policy']
assert policy_hashes(ROOT)==prior['policy_files'],'Current work differs from the preceding exact installation'
component=DEV/'economy_component'
assert read(component/'fixture_receipt2.json')['exit_code']==0
assert read(component/'comparison_receipt1.json')['exit_code']==0
assert sha(component/'test_economy_reuse.lua')==read(component/'fixture_receipt2.json')['fixture_sha256']
for name in ('economy.lua','consumables.lua','before_economy.lua','compare.lua'):
    assert sha(component/name)==read(component/'comparison_receipt1.json')['files'][name]
economy=ROOT/'Brainstorm/Advisor/economy.lua'
consumables=ROOT/'Brainstorm/Advisor/consumables.lua'
assert economy.read_text(encoding='utf-8')==(component/'before_economy.lua').read_text(encoding='utf-8')
assert consumables.read_bytes()==(DEV/'inventory_component/consumables.lua').read_bytes()
text=consumables.read_text(encoding='utf-8')
anchor='local function joker_name(j)'
assert text.count(anchor)==1 and 'M.equivalent_owned=' not in text
text=text.replace(anchor,'-- Shared by the shop cash planner; no grouping mutates the actual inventory.\nM.equivalent_owned=equivalent_owned\n'+anchor)
fixture=(component/'test_economy_reuse.lua').read_text(encoding='utf-8')
fixture=fixture.replace('tools/advisor_eval/development335/economy_component/economy.lua','Brainstorm/Advisor/economy.lua')
fixture=fixture.replace('tools/advisor_eval/development335/economy_component/consumables.lua','Brainstorm/Advisor/consumables.lua')
assert 'development335' not in fixture
payload={'Brainstorm/Advisor/economy.lua':(component/'economy.lua').read_bytes(),
         'Brainstorm/Advisor/consumables.lua':text.encode('utf-8'),
         'tests/advisor_economy_reuse.lua':fixture.encode('utf-8')}
before={}
for relative in payload:
    p=ROOT/relative
    if relative.startswith('tests/'):assert not p.exists()
    else:before[relative]=sha(p);write(HERE/'before'/relative,p.read_bytes())
for relative in VERSION_FIELDS:
    p=ROOT/'Brainstorm'/relative;write(HERE/'before/Brainstorm'/relative,p.read_bytes())
for relative,raw in payload.items():
    p=ROOT/relative
    if relative in before:assert sha(p)==before[relative];p.write_bytes(raw)
    else:write(p,raw)
for relative in VERSION_FIELDS:stamp_version(ROOT/'Brainstorm'/relative,relative,'2.138.0-alpha')
folder=EVAL/'runs/cash338_candidate';folder.mkdir(exist_ok=False)
frozen=freeze_product(ROOT,folder/'policy')
write(folder/'freeze.json',(json.dumps(frozen,indent=2)+'\n').encode('utf-8'))
receipt={'schema':1,'kind':'routine_manufactured_cash_reuse_slice','created_utc':datetime.now(timezone.utc).isoformat(),
 'previous_policy_digest':prior['policy_digest'],'policy_digest':frozen['policy_digest'],
 'files':{r:{'before':before.get(r),'after':sha(ROOT/r)} for r in payload},
 'new_experiments':0,'historical_authority':'closed','game_control':False,'save_reads':False}
write(HERE/'integration.json',(json.dumps(receipt,indent=2)+'\n').encode('utf-8'))
print(json.dumps({'policy_digest':frozen['policy_digest'],'policy_files':len(frozen['policy_files'])}))
