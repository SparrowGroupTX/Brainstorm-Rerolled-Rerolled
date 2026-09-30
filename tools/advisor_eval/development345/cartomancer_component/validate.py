from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
index=1
while (OUT/f'validation{index}.json').exists():index+=1
command=['python','tests/run_lua_tests.py',str((OUT/'run_staged.lua').relative_to(ROOT))]
started=time.perf_counter()
r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
log=OUT/f'validation{index}.log';log.write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
paths=['Brainstorm/Advisor/gold_goal.lua','Brainstorm/Advisor/gold_acquisition.lua','Brainstorm/Advisor/shop_scoring.lua','Brainstorm/Advisor/runtime.lua',
 str((OUT/'tests/advisor_gold_cartomancer.lua').relative_to(ROOT)),
 'tools/advisor_eval/development345/row_component/Brainstorm/Advisor/gold_tarot_hold.lua']
record={'schema':1,'scope':'Manufactured fixtures only; no source execution, captured replay, search or terminal attempt.',
 'command':command,'exit_code':r.returncode,'suite_cap_seconds':60,'seconds':time.perf_counter()-started,
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
 'log':str(log.relative_to(ROOT)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()}
(OUT/f'validation{index}.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(r.stdout);print(r.stderr)
raise SystemExit(r.returncode)
