"""One-use composition of reviewed callback cooperation; no game/source execution."""
from pathlib import Path
from datetime import datetime, timezone
import json,hashlib,sys
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).parent; EVAL=HERE.parent
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def exclusive(path,raw):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('xb') as stream:stream.write(raw)
seals={'logger_component':'b4dc7c888a279d6ff5acd4de8133b3bebf91b04c5b9ce5a0929f3e4c6aab4b36',
       'observer_component':'5e5e3bd28b53f0953fe5c45fdabc6a7ea87ece648f017686b4c2248997a19713'}
for name,digest in seals.items():
    manifest=HERE/name/'manifest.json';assert sha(manifest)==digest
    for relative,item in read(manifest)['files'].items():
        assert sha(manifest.parent/relative)==(item if isinstance(item,str) else item['sha256']),relative
baseline=read(EVAL/'runs/acorn332_candidate/freeze.json')
assert baseline['policy_digest']=='1f27a0d0952ed090c95289f8112e5957f067e95d56a589a7684ae67024ddcec5'
for relative,digest in baseline['policy_files'].items():assert sha(ROOT/relative)==digest,relative
payload={}
for name,component in [('callback_hooks.lua','observer_component'),('acorn_public_hooks.lua','observer_component'),('player_journal.lua','logger_component')]:
    payload['Brainstorm/Advisor/'+name]=(HERE/component/name).read_bytes()
runtime=(ROOT/'Brainstorm/Advisor/runtime.lua').read_text(encoding='utf-8')
old="A.player_journal.attach(A,Brainstorm)"
assert runtime.count(old)==1
runtime=runtime.replace(old,"A.callback_hooks=module('callback_hooks').new()\n"+old)
old='A.public_joker_hooks=A.acorn_public_hooks.attach(A.public_joker_tracker)'
assert runtime.count(old)==1
runtime=runtime.replace(old,'A.public_joker_hooks=A.acorn_public_hooks.attach(A.public_joker_tracker,{callback_hooks=A.callback_hooks})')
payload['Brainstorm/Advisor/runtime.lua']=runtime.encode('utf-8')
for source,target in [('logger_component/test_logger_hooks.lua','advisor_logger_hooks.lua'),('observer_component/test_callback_hooks.lua','advisor_callback_hooks.lua')]:
    raw=(HERE/source).read_text(encoding='utf-8')
    raw=raw.replace("local base='tools/advisor_eval/development333/'","local base='Brainstorm/Advisor/'")
    for name,component in [('player_journal.lua','logger_component'),('callback_hooks.lua','observer_component'),('acorn_public_hooks.lua','observer_component')]:
        raw=raw.replace("base..'"+component+'/'+name+"'","base..'"+name+"'")
    assert 'development333' not in raw and 'component/' not in raw
    payload['tests/'+target]=raw.encode('utf-8')
before={}
for relative in payload:
    p=ROOT/relative
    if relative in baseline['policy_files']:assert sha(p)==baseline['policy_files'][relative]
    else:assert not p.exists(),relative
    before[relative]=sha(p) if p.exists() else None
folder=HERE/'integration';folder.mkdir(exist_ok=False)
for relative in payload:
    if before[relative]:exclusive(folder/'before'/relative,(ROOT/relative).read_bytes())
for relative,raw in payload.items():
    p=ROOT/relative
    assert (sha(p) if p.exists() else None)==before[relative]
    if before[relative]:p.write_bytes(raw)
    else:exclusive(p,raw)
sys.path.insert(0,str(EVAL))
from install_slice import stamp_version,VERSION_FIELDS
from paired_policy_audit import freeze_product
for relative in VERSION_FIELDS:
    p=ROOT/'Brainstorm'/relative
    exclusive(folder/'before'/'Brainstorm'/relative,p.read_bytes())
    stamp_version(p,relative,'2.133.0-alpha')
candidate=EVAL/'runs/hooks333_candidate';candidate.mkdir(exist_ok=False)
frozen=freeze_product(ROOT,candidate/'policy')
exclusive(candidate/'freeze.json',(json.dumps(frozen,indent=2)+'\n').encode('utf-8'))
receipt={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),'status':'composed_and_frozen_for_regression',
 'component_seals':seals,'previous_policy_digest':baseline['policy_digest'],'policy_digest':frozen['policy_digest'],
 'files':{r:{'before_sha256':before[r],'after_sha256':sha(ROOT/r)} for r in payload},
 'source_workers':0,'policy_evaluations':0,'game_control':False,'installed':False}
exclusive(folder/'receipt.json',(json.dumps(receipt,indent=2)+'\n').encode('utf-8'))
print(json.dumps({'policy_digest':frozen['policy_digest'],'files':len(frozen['policy_files']),'production_paths':list(payload)}))
