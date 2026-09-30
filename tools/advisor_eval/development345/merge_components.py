from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return p.read_text(encoding='utf-8')
def putnew(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(v if isinstance(v,bytes) else v.encode())
target=ROOT/'Brainstorm/Advisor/gold_tarot_hold.lua'
assert sha(target)==sha(HERE/'root_component/before/Brainstorm/Advisor/gold_tarot_hold.lua')
scope=HERE/'tarot_scope_component/Brainstorm/Advisor/gold_tarot_hold.lua'
rows=HERE/'row_component/Brainstorm/Advisor/gold_tarot_hold.lua'
assert sha(rows)=='ae523d33cbb2fc9287bc27093b8ade4a537c046e9ad8e946dd0cf2f54eb0b18f'
text=read(scope);catalog=read(rows)
start,end=catalog.index('local row_names='),catalog.index('local function finite(')
text=text[:text.index('local row_names=')]+catalog[start:end]+text[text.index('local function finite('):]
target.write_text(text,encoding='utf-8',newline='\n')
for component,name in [('pin_component','advisor_gold_tarot_hold_pin.lua'),('tarot_scope_component','advisor_gold_tarot_hold_scope.lua'),('row_component','advisor_gold_tarot_rows.lua')]:
    p=HERE/component/'tests'/name
    putnew(ROOT/'tests'/name,p.read_bytes())
p=ROOT/'tests/advisor_gold_acquisition_runtime.lua'
putnew(HERE/'root_component/before/tests/advisor_gold_acquisition_runtime.lua',p.read_bytes())
p.write_bytes((HERE/'pin_component/tests/advisor_gold_acquisition_runtime.lua').read_bytes())
p=ROOT/'tests/advisor_gold_acquisition.lua'
putnew(HERE/'root_component/before/tests/advisor_gold_acquisition.lua',p.read_bytes())
p.write_text(read(p).replace("s.next_blind.key='bl_final_vessel'","s.next_blind.key='bl_final_heart'"),encoding='utf-8',newline='\n')
putnew(HERE/'root_component/merge.json',json.dumps({'inputs':{str(p.relative_to(ROOT)):sha(p) for p in (scope,rows)},'output':{'path':str(target.relative_to(ROOT)),'sha256':sha(target)}},indent=2)+'\n')
print('Merged source-shaped pin and unused Tarot proof with the source identity catalog.')
