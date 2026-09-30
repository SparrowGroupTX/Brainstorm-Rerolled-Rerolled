"""One bounded manufactured-suite timing diagnosis; not a release gate."""
from pathlib import Path
import importlib.util,json,subprocess,sys,time
H=Path(__file__).resolve().parent;R=H.parents[2]
if sys.argv[1:]==['--child']:
 spec=importlib.util.spec_from_file_location('fixture_runner444',R/'tests/run_lua_tests.py')
 runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
 original=runner.LuaLibrary.run
 def timed(self,path):
  start=time.perf_counter();passed=original(self,path)
  with(H/'fixture_times.jsonl').open('a',encoding='utf-8')as f:
   f.write(json.dumps({'fixture':path.relative_to(R).as_posix(),'seconds':time.perf_counter()-start,'passed':passed})+'\n')
  return passed
 runner.LuaLibrary.run=timed
 sys.argv=['run_lua_tests.py','--lua-library',str(runner.BALATRO_DLL)]
 raise SystemExit(runner.main())
assert not(H/'PROFILE_STARTED.json').exists()
(H/'PROFILE_STARTED.json').write_text(json.dumps({'fixtures':322,'total_wall_cap_seconds':120,'manufactured_only':True,'one_use':True}))
start=time.monotonic()
with(H/'profile_raw.log').open('x',encoding='utf-8')as out:
 try:
  p=subprocess.run([sys.executable,'-B',str(Path(__file__).resolve()),'--child'],cwd=R,stdout=out,stderr=subprocess.STDOUT,timeout=120,creationflags=subprocess.CREATE_NO_WINDOW)
  status=p.returncode
 except subprocess.TimeoutExpired:status='timeout'
rows=[json.loads(line)for line in(H/'fixture_times.jsonl').read_text().splitlines()]if(H/'fixture_times.jsonl').exists()else[]
report={'status':status,'seconds':time.monotonic()-start,'completed':len(rows),'fixtures_passed':sum(r['passed']for r in rows),'slowest':sorted(rows,key=lambda r:-r['seconds'])[:20],'release_qualification':False,'remaining_diagnostic_runs':0}
(H/'PROFILE_CLOSED.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
