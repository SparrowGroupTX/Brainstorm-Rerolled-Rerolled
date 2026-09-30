from pathlib import Path
import subprocess,sys,json,hashlib,time
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).resolve().parent/'root_component'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(paths):
    cmd=[sys.executable,'tests/run_lua_tests.py',*paths];start=time.monotonic()
    p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=60)
    return dict(command=cmd,exit_code=p.returncode,seconds=time.monotonic()-start,stdout=p.stdout,stderr=p.stderr)
baseline=HERE/'baseline_budget.lua'
with baseline.open('x',encoding='utf-8') as f:
    f.write((ROOT/'tests/advisor_gold_acquisition_budget.lua').read_text().replace('Brainstorm/Advisor/decision.lua','tools/advisor_eval/development344/root_component/before/Brainstorm/Advisor/decision.lua'))
before=run([str(baseline.relative_to(ROOT))]);assert before['exit_code']!=0
after=run(['tests/advisor_gold_acquisition_budget.lua','tests/advisor_gold_tarot_hold.lua','tests/advisor_gold_acquisition.lua'])
result={'scope':'Manufactured fixtures only, no captured policy replay or source/terminal experiments.',
 'cap_seconds_per_command':60,'before':before,'after':after,
 'files':{str(p.relative_to(ROOT)):sha(p) for p in [ROOT/'Brainstorm/Advisor/decision.lua',ROOT/'Brainstorm/Advisor/runtime.lua',ROOT/'Brainstorm/Advisor/snapshot.lua',ROOT/'tests/advisor_gold_acquisition_budget.lua']}}
with (HERE/'validation.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2)
assert after['exit_code']==0
print(json.dumps({'before_expected_failure':True,'after_passed':True,'path':str(HERE/'validation.json')}))
