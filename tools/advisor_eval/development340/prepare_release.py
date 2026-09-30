"""Freeze the manufactured Acorn Lucky-card repair without opening experiments."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import sys

HERE=Path(__file__).resolve().parent
EVAL=HERE.parent
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes
from install_slice import stamp_version,VERSION_FIELDS
from paired_policy_audit import freeze_product

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,raw):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(raw)

prior=read(EVAL/'runs/speed339_installed/record.json')['policy']
before=read(HERE/'before.json')
assert before['previous_policy_digest']==prior['policy_digest']
current=policy_hashes(ROOT)
changed={'Brainstorm/Advisor/acorn_ordering.lua','Brainstorm/Advisor/decision.lua'}
assert current.keys()==prior['policy_files'].keys()
for name,digest in prior['policy_files'].items():
    if name not in changed:assert current[name]==digest,name
for name,digest in before['files'].items():assert sha(HERE/'before'/name)==digest,name
fixture=HERE/'lucky_component/test_acorn_lucky.lua'
receipt=HERE/'lucky_component/validation_attempt_02.json'
validation=read(receipt)
assert validation['returncode']==0 and validation['fixture_sha256']==sha(fixture)
target=ROOT/'tests/advisor_acorn_lucky.lua'
assert not target.exists()
write(target,fixture.read_bytes())
for name in VERSION_FIELDS:stamp_version(ROOT/'Brainstorm'/name,name,'2.140.0-alpha')
out=EVAL/'runs/acorn340_candidate';out.mkdir(exist_ok=False)
policy=freeze_product(ROOT,out/'policy')
write(out/'freeze.json',(json.dumps(policy,indent=2)+'\n').encode('utf-8'))
integration={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
 'previous_policy_digest':prior['policy_digest'],'policy_digest':policy['policy_digest'],
 'changed_runtime':{name:{'before':prior['policy_files'][name],'after':sha(ROOT/name)} for name in sorted(changed)},
 'fixture':{'path':target.relative_to(ROOT).as_posix(),'sha256':sha(target)},
 'component_receipt':{'path':receipt.relative_to(ROOT).as_posix(),'sha256':sha(receipt)},
 'new_experiments':0,'source_search_attempt_authority':'closed','game_control':False,'save_or_profile_reads':False}
write(HERE/'integration.json',(json.dumps(integration,indent=2)+'\n').encode('utf-8'))
print(json.dumps({'policy_digest':policy['policy_digest'],'policy_files':len(policy['policy_files'])}))
