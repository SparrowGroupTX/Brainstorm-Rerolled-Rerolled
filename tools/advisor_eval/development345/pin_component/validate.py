"""Before/after manufactured Lua validation, without source or player replay."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys
import time

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
MODULE='Brainstorm/Advisor/gold_tarot_hold.lua'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT/'validation.json').exists(), 'One-use validation receipt already exists'
inputs={str(p.relative_to(ROOT)):sha(p) for p in sorted((ROOT/'Brainstorm/Advisor').glob('*.lua'))}
fixtures=sorted((OUT/'tests').glob('*.lua'))
inputs.update({str(p.relative_to(ROOT)):sha(p) for p in fixtures})
inputs[str((OUT/MODULE).relative_to(ROOT))]=sha(OUT/MODULE)
results=[]
for phase in ('before','after'):
    for test in fixtures:
        target=(OUT/('before/'+MODULE if phase=='before' else MODULE)).relative_to(ROOT).as_posix()
        wrapper=OUT/f'{phase}_{test.name}'
        with wrapper.open('x',encoding='utf-8') as f:
            f.write("local original_open=io.open\nlocal original_dofile=dofile\n")
            f.write(f"local module={target!r}\n")
            f.write("io.open=function(path,...) if path=='Brainstorm/Advisor/gold_tarot_hold.lua' then path=module end;return original_open(path,...) end\n")
            f.write("dofile=function(path) if path=='Brainstorm/Advisor/gold_tarot_hold.lua' then path=module end;return original_dofile(path) end\n")
            f.write(f"dofile({test.relative_to(ROOT).as_posix()!r})\n")
        command=[sys.executable,'tests/run_lua_tests.py',str(wrapper.relative_to(ROOT))]
        start=time.monotonic()
        try:
            result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,
                creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            row={'phase':phase,'fixture':test.name,'exit_code':result.returncode,'stdout':result.stdout,'stderr':result.stderr}
        except subprocess.TimeoutExpired as error:
            row={'phase':phase,'fixture':test.name,'timeout':True,'stdout':str(error.stdout),'stderr':str(error.stderr)}
        row.update(command=command,seconds=time.monotonic()-start,max_seconds=60)
        results.append(row)
        print(json.dumps(row))
unchanged=all(sha(ROOT/p)==v for p,v in inputs.items())
report={'schema':1,'created_utc':datetime.now(timezone.utc).isoformat(),
        'scope':'Manufactured constructor, Snapshot and production Decision dependency fixtures only.',
        'original_source_execution':False,'captured_policy_replay':False,'search':False,'complete_attempts':0,
        'live_game_control':False,'saves_or_profiles_read':False,'inputs':inputs,'inputs_unchanged':unchanged,'runs':results,
        'passed':unchanged and all(r.get('exit_code')==(1 if r['phase']=='before' else 0) for r in results)}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
raise SystemExit(0 if report['passed'] else 1)
