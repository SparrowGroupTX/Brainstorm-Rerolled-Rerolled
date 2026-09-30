from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[3];EVAL=ROOT/'tools/advisor_eval'
sys.path.insert(0,str(EVAL))
from install_slice import stamp_version,VERSION_FIELDS
from paired_policy_audit import freeze_product
c=Path(__file__).with_name('nine_card_component');source=ROOT/'Brainstorm/Advisor/concealed_belief.lua'
assert source.read_bytes()==(c/'baseline.lua').read_bytes()
candidate=(c/'concealed_belief.lua').read_bytes()
assert hashlib.sha256(candidate).hexdigest()=='4d8c3d57c6eb9379fc9e5a5e91c89c8da1ba5c15e893e970da94cb999f74188f'
test=(c/'test.lua').read_text()
test=test.replace("local P='tools/advisor_eval/development328/nine_card_component/'",'''local function previous_limit()
 local f=assert(io.open('Brainstorm/Advisor/concealed_belief.lua','rb'));local text=f:read('*a');f:close()
 local a,b;text,a=text:gsub('#s%.hand>9','#s.hand>8',1);text,b=text:gsub('#state%.hand>9','#state.hand>8',1)
 assert(a==1 and b==1,'Expected two bounded nine-card admissions')
 text=text:gsub('at most nine held cards','at most eight held cards',1)
 return assert(loadstring(text,'@manufactured_previous_concealed_limit'))()
end''')
test=test.replace("dofile(P..'concealed_belief.lua')","dofile('Brainstorm/Advisor/concealed_belief.lua')").replace("dofile(P..'baseline.lua')","previous_limit()")
assert 'P..' not in test
with (ROOT/'tests/advisor_concealed_nine_card.lua').open('x',encoding='utf-8') as f:f.write(test)
source.write_bytes(candidate)
for relative in VERSION_FIELDS:stamp_version(ROOT/'Brainstorm'/relative,relative,'2.131.0-alpha')
folder=EVAL/'runs/nine331_candidate';folder.mkdir(exist_ok=False)
record=freeze_product(ROOT,folder/'policy');(folder/'freeze.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'candidate':str(folder),'policy_digest':record['policy_digest']}))
