from pathlib import Path
import hashlib,json,subprocess,time,sys
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
index=1
while (OUT/f'validation{index}.json').exists():index+=1
fixture=OUT/'tests/advisor_gold_tarot_lifecycle_shape.lua'
if len(sys.argv)>1:
    staged=Path(sys.argv[1]).as_posix()
    wrapper=OUT/f'run{index}.lua'
    wrapper.write_text("local old=dofile\ndofile=function(p) if p=='Brainstorm/Advisor/gold_tarot_hold.lua' then p="+repr(staged)+" end;return old(p)end\ndofile("+repr(fixture.relative_to(ROOT).as_posix())+")\n",encoding='utf-8')
    fixture=wrapper
command=['python','tests/run_lua_tests.py',str(fixture.relative_to(ROOT))]
started=time.perf_counter();r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
log=OUT/f'validation{index}.log';log.write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
files=['Brainstorm/Advisor/gold_tarot_hold.lua','Brainstorm/Advisor/snapshot.lua',str((OUT/'tests/advisor_gold_tarot_lifecycle_shape.lua').relative_to(ROOT))]
if len(sys.argv)>1:files.append(sys.argv[1])
record={'schema':1,'scope':'Manufactured fixture only; no source execution, captured policy replay, search or full attempt.',
 'command':command,'exit_code':r.returncode,'seconds':time.perf_counter()-started,'suite_cap_seconds':60,
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in files},'log':str(log.relative_to(ROOT))}
(OUT/f'validation{index}.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(r.stdout);print(r.stderr);raise SystemExit(r.returncode)
