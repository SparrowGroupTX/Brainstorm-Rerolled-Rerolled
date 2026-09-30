"""Each invocation runs one manufactured fixture with a sixty-second outer cap."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[4];HERE=Path(__file__).resolve().parent
kind,label=sys.argv[1:];assert kind in ('baseline','candidate','pair','margin') and label.replace('_','').isalnum()
wrapper=HERE/('run_'+kind+'.lua');output=HERE/label;output.mkdir(exist_ok=False)
fixture=(ROOT/'tools/advisor_eval/development350/yorick_component/tests/advisor_yorick_margin.lua' if kind=='margin' else
 HERE/'tests'/('advisor_yorick_pair.lua' if kind=='pair' else 'advisor_burnt_pair_inert.lua'))
runtime=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Balatro\lua51.dll')
paths=[wrapper,fixture,HERE/'before/growth.lua',HERE/'Brainstorm/Advisor/growth.lua',ROOT/'tests/run_lua_tests.py']
paths += [ROOT/'Brainstorm/Advisor'/p for p in ('scoring.lua','strategy.lua','search.lua','decision.lua','snapshot.lua')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
hashes={p.relative_to(ROOT).as_posix():sha(p) for p in paths}
(output/'input_fixture.lua').write_bytes(fixture.read_bytes())
command=[sys.executable,'tests/run_lua_tests.py','--lua-library',str(runtime),wrapper.relative_to(ROOT).as_posix()]
start=time.monotonic()
try:
 result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=60,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 status='passed' if result.returncode==0 else 'failed';code=result.returncode;log=result.stdout+'\n'+result.stderr
except subprocess.TimeoutExpired as exc:
 status='timeout';code=None;log=str(exc.stdout)+'\n'+str(exc.stderr)
elapsed=time.monotonic()-start
(output/'output.log').write_text(log,encoding='utf-8')
report={'scope':'Manufactured fixture only; no captured/source/search/complete jobs or game/save/executable access.',
 'kind':kind,'command':command,'status':status,'exit_code':code,'seconds':elapsed,'cap_seconds':60,
 'input_hashes':hashes,'runtime':{'path':str(runtime),'sha256':sha(runtime)},
 'inputs_unchanged':all(sha(ROOT/p)==h for p,h in hashes.items()),'log_sha256':sha(output/'output.log')}
(output/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(log);print(json.dumps({'kind':kind,'label':label,'status':status,'seconds':elapsed,'inputs_unchanged':report['inputs_unchanged']}))
sys.exit(0 if status=='passed' else 1)
