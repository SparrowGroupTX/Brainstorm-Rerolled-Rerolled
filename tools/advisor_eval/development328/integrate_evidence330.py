from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[3];EVAL=ROOT/'tools/advisor_eval'
sys.path.insert(0,str(EVAL))
from install_slice import stamp_version,VERSION_FIELDS
from paired_policy_audit import freeze_product
component=Path(__file__).with_name('replacement_evidence_component')
source=ROOT/'Brainstorm/Advisor/strategy.lua'
assert source.read_bytes()==(component/'baseline.lua').read_bytes()
candidate=(component/'strategy.lua').read_bytes()
assert hashlib.sha256(candidate).hexdigest()=='0766b5cfca986d4adeb88568e5a5231db6f1b47239e5eaff46904f3b1a895292'
test=(component/'test.lua').read_text()
test=test.replace("local P='tools/advisor_eval/development328/replacement_evidence_component/'",'''local function load_strategy(role)
 local f=assert(io.open('Brainstorm/Advisor/strategy.lua','rb'));local text=f:read('*a');f:close()
 if role=='baseline' then
  local count;text,count=text:gsub('scoring_evidence=sale%.scoring_evidence,','',1)
  assert(count==1,'Expected the single evidence forwarding field')
 end
 return assert(loadstring(text,'@manufactured_replacement_strategy'))()
end''')
test=test.replace('local strategy=dofile(path);','local strategy=load_strategy(path);').replace("P..'baseline.lua'","'baseline'").replace("P..'strategy.lua'","'candidate'").replace("dofile('candidate')","load_strategy('candidate')")
assert 'P..' not in test
target=ROOT/'tests/advisor_replacement_evidence.lua'
with target.open('x',encoding='utf-8') as stream:stream.write(test)
source.write_bytes(candidate)
for relative in VERSION_FIELDS:stamp_version(ROOT/'Brainstorm'/relative,relative,'2.130.0-alpha')
folder=EVAL/'runs/evidence330_candidate'
folder.mkdir(exist_ok=False)
record=freeze_product(ROOT,folder/'policy')
(folder/'freeze.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'candidate':str(folder),'policy_digest':record['policy_digest']}))
