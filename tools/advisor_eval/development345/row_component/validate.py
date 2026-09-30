from pathlib import Path
import hashlib
import json
import subprocess
import time

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
results=[]
for mode in ('before','candidate'):
    command=['python','tests/run_lua_tests.py',str((OUT/f'run_{mode}.lua').relative_to(ROOT))]
    started=time.perf_counter()
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60)
    log=OUT/f'{mode}.log'
    assert not log.exists(), 'preserve earlier validation evidence'
    log.write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
    results.append({'mode':mode,'command':command,'exit_code':r.returncode,'seconds':time.perf_counter()-started,
                    'log':str(log.relative_to(ROOT)),'sha256':hashlib.sha256(log.read_bytes()).hexdigest()})
    print(mode,r.returncode,r.stdout[-300:],r.stderr[-500:])
(OUT/'validation.json').write_text(json.dumps({'schema':1,'suite_cap_seconds':60,'results':results,
    'scope':'Manufactured fixtures only; no source execution, captured policy replay, search or complete attempt.'},indent=2)+'\n',encoding='utf-8')
raise SystemExit(0 if results[0]['exit_code']!=0 and results[1]['exit_code']==0 else 1)
