from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,subprocess,sys,time
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
files=['Brainstorm/Advisor/decision.lua','Brainstorm/Advisor/gold_retention.lua','Brainstorm/Advisor/runtime.lua',
       'Brainstorm/Advisor/player_journal.lua','tests/advisor_gold_retention_budget.lua']
inputs={p:sha(ROOT/p)for p in files}
assert not (OUT/'budget_integration_report.json').exists()
command=[sys.executable,'tests/run_lua_tests.py','tests/advisor_gold_retention_budget.lua']
start=time.monotonic();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,
  creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
record={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),'scope':'Manufactured Decision budget/postprocessor fixture only.',
 'command':command,'max_seconds':60,'seconds':time.monotonic()-start,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr,
 'inputs':inputs,'inputs_unchanged':all(sha(ROOT/p)==h for p,h in inputs.items()),
 'review':'Actual-call accounting shares the total shop cap across acquisition, ordinary and retention work. The reserved8000 is subtracted before ordinary work; remainingactual allowance is computed afterordinary/fallback. Only a complete retained leave_shop proof suppresses later phase_copy reordering; ordinary, optedout and invalidproof postprocessing is unchanged.',
 'tests':'51 checks: allthreeworkstages, reserve, unusedordinarycapacity, truncationfallback, actualcallmismatch/exhaustion, lowercallercaps, acquisitionexhaustion, optout/noheldtargets, protectedexit and unprotectedpostprocessor sentinels.',
 'source_execution':False,'captured_policy_replay':False,'save_or_profile_reads':False,'live_game_control':False}
with (OUT/'budget_integration_report.json').open('x',encoding='utf-8')as f:json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({k:v for k,v in record.items()if k!='inputs'}));assert r.returncode==0 and record['inputs_unchanged']
