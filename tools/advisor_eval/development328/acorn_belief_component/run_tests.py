"""Manufactured-only fixture; never a captured decision or original-source run."""
from pathlib import Path
import sys,time,json,hashlib
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'captured_compare'))
from compare_public import Lua
source=b"return dofile('tools/advisor_eval/development328/acorn_belief_component/test_acorn_belief.lua')"
result=Lua(Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/lua51.dll'),time.perf_counter()+10).evaluate(source)
print(result.decode())
report={'schema':1,'kind':'manufactured_public_belief_fixture','result':result.decode(),'source_execution':False,'captured_policy_evaluation':False,
 'files':{str(p.relative_to(HERE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in HERE.glob('*.lua')}}
(HERE/'manufactured_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
