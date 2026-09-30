import json, subprocess, sys, time
from pathlib import Path
root=Path(__file__).resolve().parent
started=time.perf_counter()
cmd=[sys.executable,'tests/run_lua_tests.py',str(root/'test_inventory_reuse.lua')]
try:
    result=subprocess.run(cmd,capture_output=True,text=True,timeout=60)
    record={'returncode':result.returncode,'timeout_seconds':60,'elapsed_seconds':time.perf_counter()-started,'command':cmd,'stdout':result.stdout,'stderr':result.stderr}
except subprocess.TimeoutExpired as error:
    record={'returncode':None,'timeout_seconds':60,'elapsed_seconds':time.perf_counter()-started,'command':cmd,'timed_out':True,'stdout':str(error.stdout),'stderr':str(error.stderr)}
number=1
while (root/f'fixture_receipt{number}.json').exists(): number+=1
path=root/f'fixture_receipt{number}.json'
path.write_text(json.dumps(record,indent=2),encoding='utf-8')
print(record.get('stdout',''))
print(record.get('stderr',''))
raise SystemExit(record['returncode'] if record['returncode'] is not None else 124)
