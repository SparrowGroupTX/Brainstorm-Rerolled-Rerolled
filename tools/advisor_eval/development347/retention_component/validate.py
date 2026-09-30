from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, subprocess, sys, time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
MODULE = 'Brainstorm/Advisor/gold_retention.lua'
before = '--before' in sys.argv
label = 'before' if before else 'candidate'
n = 1
while (OUT / f'{label}_{n:02}.json').exists(): n += 1
wrapper = OUT / f'run_{label}_{n:02}.lua'
paths = {
 MODULE: str((OUT / ('before' if before else '') / MODULE).relative_to(ROOT)).replace('\\', '/'),
 'Brainstorm/Advisor/gold_order.lua': 'tools/advisor_eval/development347/order_component/Brainstorm/Advisor/gold_order.lua',
 'Brainstorm/Advisor/shop_scoring.lua': 'tools/advisor_eval/development347/preflight_component/Brainstorm/Advisor/shop_scoring.lua',
}
mapping = '{' + ','.join(f'[{json.dumps(k)}]={json.dumps(v)}' for k,v in paths.items()) + '}'
with wrapper.open('x', encoding='utf-8') as f:
 f.write('local paths=' + mapping + '\n')
 f.write("local old=dofile;dofile=function(p)return old(paths[p] or p)end\n")
 f.write("local opened=io.open;io.open=function(p,...)return opened(paths[p] or p,...)end\n")
 f.write("dofile('tools/advisor_eval/development347/retention_component/tests/advisor_gold_retention_order.lua')\n")
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
inputs = sorted((ROOT / 'Brainstorm/Advisor').glob('*.lua')) + [ROOT/p for p in paths.values()] + [OUT/'tests/advisor_gold_retention_order.lua', wrapper]
hashes = {str(p.relative_to(ROOT)): sha(p) for p in inputs}
start = time.monotonic()
command = [sys.executable, 'tests/run_lua_tests.py', str(wrapper.relative_to(ROOT))]
try:
 r = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
 result = {'exit_code': r.returncode, 'stdout': r.stdout, 'stderr': r.stderr}
except subprocess.TimeoutExpired as e:
 result = {'timeout': True, 'stdout': str(e.stdout), 'stderr': str(e.stderr)}
result.update(schema=1, created_utc=datetime.now(timezone.utc).isoformat(), command=command, seconds=time.monotonic()-start,
 max_seconds=60, scope='Manufactured public states with pure product dependencies. No source execution, captured policy evaluation, search, save/profile access or terminal attempt.',
 inputs=hashes, inputs_unchanged=all((ROOT/p).exists() and sha(ROOT/p)==h for p,h in hashes.items()))
(OUT / f'{label}_{n:02}.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k!='inputs'}))
raise SystemExit(0 if result.get('exit_code')==0 else 1)
