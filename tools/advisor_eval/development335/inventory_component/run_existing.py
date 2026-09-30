import json, subprocess, sys, time
from pathlib import Path
root=Path(__file__).resolve().parent
started=time.perf_counter()
cmd=[sys.executable,'tests/run_lua_tests.py',str(root/'existing_*.lua')]
result=subprocess.run(cmd,capture_output=True,text=True,timeout=60)
record={'returncode':result.returncode,'timeout_seconds':60,'elapsed_seconds':time.perf_counter()-started,'command':cmd,'stdout':result.stdout,'stderr':result.stderr}
number=1
while (root/f'existing_receipt{number}.json').exists(): number+=1
path=root/f'existing_receipt{number}.json'
path.write_text(json.dumps(record,indent=2),encoding='utf-8')
print(result.stdout)
print(result.stderr)
raise SystemExit(result.returncode)
