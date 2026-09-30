from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
index=1
while (OUT/f'validation{index}.json').exists():index+=1
command=['python','tests/run_lua_tests.py',str((OUT/'run.lua').relative_to(ROOT))]
started=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
log=OUT/f'validation{index}.log';log.write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
paths=['Brainstorm/Advisor/gold_goal.lua','Brainstorm/Advisor/gold_perkeo.lua',
 str((OUT/'Brainstorm/Advisor/gold_order.lua').relative_to(ROOT)),str((OUT/'tests/advisor_gold_order.lua').relative_to(ROOT))]
record={'schema':1,'scope':'Manufactured pure row enumeration fixture only; no score calls, RNG, source execution, captured replay, search or full attempt.',
 'command':command,'exit_code':r.returncode,'seconds':time.perf_counter()-started,'suite_cap_seconds':60,
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'log':str(log.relative_to(ROOT))}
(OUT/f'validation{index}.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(r.stdout);print(r.stderr);raise SystemExit(r.returncode)
