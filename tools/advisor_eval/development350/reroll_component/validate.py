"""One bounded manufactured fixture invocation; never runs game/source/replays."""
from pathlib import Path
import hashlib, json, subprocess, sys, time
ROOT=Path(__file__).resolve().parents[4]
HERE=Path(__file__).resolve().parent
label=sys.argv[1]
assert label.replace('_','').isalnum()
wrapper=HERE/('run_baseline.lua' if label.startswith('baseline') else 'run_candidate.lua')
out=HERE/label
out.mkdir(exist_ok=False)
paths=[wrapper,HERE/'tests/advisor_gold_reroll.lua',HERE/'Brainstorm/Advisor/paid_reroll.lua']
paths += [ROOT/'Brainstorm/Advisor'/p for p in ['strategy.lua','paid_reroll.lua','catalog_joker.lua','snapshot.lua','shop_scoring.lua','scoring.lua','liquidity.lua']]
paths += [ROOT/'tools/advisor_eval/runs/chicot_order_source1/source'/p for p in ['card.lua','functions/common_events.lua']]
hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
command=[sys.executable,'tests/run_lua_tests.py',wrapper.relative_to(ROOT).as_posix()]
start=time.monotonic()
try:
    process=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,
        creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    status='passed' if process.returncode==0 else 'failed'
    code=process.returncode;log=process.stdout+'\n'+process.stderr
except subprocess.TimeoutExpired as e:
    status='timeout';code=None;log=str(e.stdout)+'\n'+str(e.stderr)
elapsed=time.monotonic()-start
(out/'output.log').write_text(log,encoding='utf-8')
(out/'report.json').write_text(json.dumps({'scope':'Manufactured fixture only; no source execution, captured policy, search or complete attempt',
    'command':command,'status':status,'exit_code':code,'seconds':elapsed,'cap_seconds':60,
    'input_hashes':hashes,'inputs_unchanged':all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items()),
    'log_sha256':hashlib.sha256((out/'output.log').read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8')
print(log)
sys.exit(0 if status=='passed' else 1)
