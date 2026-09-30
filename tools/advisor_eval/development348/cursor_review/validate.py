from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
index=1
while (OUT/f'validation{index}.json').exists():index+=1
fixture=str((OUT/'tests/advisor_collection_cursor_review.lua').relative_to(ROOT))
command=['python','tests/run_lua_tests.py',fixture]
started=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
log=OUT/f'validation{index}.log';log.write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
paths=['Brainstorm/Core/collection_search_product.lua','Brainstorm/Advisor/collection_search.lua',
 'Brainstorm/Advisor/gold_search.lua','Brainstorm/Advisor/gold_stickers.lua',fixture]
report={'schema':1,'scope':'Manufactured facade with mocked asynchronous runtime receipts only.',
 'native_loaded':False,'workers_started':False,'real_searches':0,'game_launches':0,'source_executions':0,
 'captured_policy_evaluations':0,'save_reads':0,'settings_writes':0,'command':command,
 'exit_code':r.returncode,'seconds':time.perf_counter()-started,'suite_cap_seconds':60,
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},'log':str(log.relative_to(ROOT))}
(OUT/f'validation{index}.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(r.stdout);print(r.stderr);raise SystemExit(r.returncode)
