"""Root-only execution after reviewed 336 install: preserve, integrate and freeze 337.
This script performs no installation, game control or source/captured experiments.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, sys
HERE=Path(__file__).resolve().parent
EVAL=HERE.parents[1]
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import policy_hashes, digest
from install_slice import stamp_version, VERSION_FIELDS
from paired_policy_audit import freeze_product

def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def exclusive(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(data)
def main():
    manifest=read(HERE/'payload_manifest.json')
    previous=read(ROOT/manifest['previous_record'])['policy']
    expected=previous['policy_files']
    assert digest(expected)==previous['policy_digest']
    assert policy_hashes(ROOT)==expected, 'Every current runtime/dependency must still match installed 336'
    for relative,expected_sha in manifest['files'].items():assert sha(HERE/'payload'/relative)==expected_sha,relative
    for relative,expected_sha in manifest['evidence'].items():assert sha(ROOT/relative)==expected_sha,relative
    changed=['Brainstorm/Advisor/strategy.lua','Brainstorm/Advisor/consumables.lua']
    for relative in changed:
        baseline=HERE/'payload/tests/fixtures/inventory337'/ (Path(relative).stem+'.base.lua')
        assert sha(baseline)==expected[relative],relative+' changed after component baseline'
    new_tests=[p for p in manifest['files'] if p.startswith('tests/')]
    output=EVAL/'runs/inventory337_candidate'
    assert not output.exists() and not (HERE/'integration.json').exists() and not (HERE/'before').exists()
    for relative in new_tests:assert not (ROOT/relative).exists(),relative+' must be new'
    # Preflight completes before the first production write. Each old byte is preserved.
    for relative in changed:exclusive(HERE/'before'/relative,(ROOT/relative).read_bytes())
    for relative in VERSION_FIELDS:exclusive(HERE/'before/Brainstorm'/relative,(ROOT/'Brainstorm'/relative).read_bytes())
    for relative in new_tests:exclusive(ROOT/relative,(HERE/'payload'/relative).read_bytes())
    for relative in changed:(ROOT/relative).write_bytes((HERE/'payload'/relative).read_bytes())
    for relative in VERSION_FIELDS:stamp_version(ROOT/'Brainstorm'/relative,relative,'2.137.0-alpha')
    after=policy_hashes(ROOT)
    allowed=set(changed)|{'Brainstorm/'+p for p in VERSION_FIELDS}
    assert set(after)==set(expected)
    for relative in expected:
        if relative not in allowed:assert after[relative]==expected[relative],relative
    output.mkdir(exist_ok=False)
    frozen=freeze_product(ROOT,output/'policy')
    exclusive(output/'freeze.json',(json.dumps(frozen,indent=2)+'\n').encode())
    receipt={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
      'kind':'routine_manufactured_fixture_runtime_slice','release':337,'version':'2.137.0-alpha',
      'previous_policy_digest':previous['policy_digest'],'policy_digest':frozen['policy_digest'],
      'changed_runtime':{p:{'before':expected[p],'after':after[p]} for p in changed},
      'new_tests':{p:sha(ROOT/p) for p in new_tests},
      'source_workers':0,'captured_replays':0,'complete_attempts':0,'searches':0,
      'game_control':False,'saves_read':False,'experiments':'all historical allowances remain closed'}
    exclusive(HERE/'integration.json',(json.dumps(receipt,indent=2)+'\n').encode())
    print(json.dumps({'policy_digest':frozen['policy_digest'],'policy_files':len(frozen['policy_files']),'new_tests':len(new_tests)}))
if __name__=='__main__':main()
