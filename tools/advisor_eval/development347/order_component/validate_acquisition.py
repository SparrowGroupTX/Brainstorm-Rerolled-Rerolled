from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
index=1
while (OUT/f'acquisition_validation{index}.json').exists():index+=1
fixture=str((OUT/'tests/advisor_gold_acquisition_order.lua').relative_to(ROOT))
command=['python','tests/run_lua_tests.py',fixture]
started=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
log=OUT/f'acquisition_validation{index}.log';log.write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
paths=['Brainstorm/Advisor/runtime.lua','Brainstorm/Advisor/gold_goal.lua','Brainstorm/Advisor/gold_order.lua',
 'Brainstorm/Advisor/gold_acquisition.lua','Brainstorm/Advisor/shop_scoring.lua','Brainstorm/Advisor/gold_tarot_hold.lua',
 'Brainstorm/Advisor/scoring.lua','Brainstorm/Advisor/shop_sequences.lua','tests/fixtures/gold_tarot_hold_support.lua',fixture]
record={'schema':1,'scope':'Manufactured production-wired acquisition fixture; no captured replay, source execution, search or full attempt.',
 'command':command,'exit_code':r.returncode,'seconds':time.perf_counter()-started,'suite_cap_seconds':60,
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'log':str(log.relative_to(ROOT))}
(OUT/f'acquisition_validation{index}.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(r.stdout);print(r.stderr);raise SystemExit(r.returncode)
