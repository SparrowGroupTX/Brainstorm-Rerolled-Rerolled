"""Bind final detached analyzer/test package without staging or input analysis."""
import hashlib
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
mapping=[('analyze_player_timing.py','tools/advisor_eval/analyze_player_timing.py'),('test_advisor_player_timing.py','tests/test_advisor_player_timing.py')]
for _,target in mapping:assert not (ROOT/target).exists(),target
files=['analyze_player_timing.py','test_advisor_player_timing.py','run_tests.py','INTEGRATION.md','stage.py','package.py']
record={'schema':1,'status':'detached_ready_for_review','runtime_changed':False,'experiments':0,
 'integration':[{'source':source,'target':target,'base_sha256':None,'sha256':sha(HERE/source)}for source,target in mapping],
 'files':[{'path':f,'sha256':sha(HERE/f)}for f in files],
 'dependencies':[{'path':'tools/advisor_eval/read_player_log.py','sha256':sha(ROOT/'tools/advisor_eval/read_player_log.py')}],
 'validation':{'command':'python tools/advisor_eval/development324/timing_analyzer/run_tests.py','exit_code':0,'python_tests':23,'input_kind':'Manufactured temporary JSONL/BRJ2 only'},
 'limitations':['No live/player inputs read.','No exact percentiles, CPU percentages, cross-session intervals or unobserved tail imputation.','Original experimental authority remains closed.']}
path=HERE/'manifest.json'
with path.open('x',encoding='utf-8',newline='\n')as f:json.dump(record,f,indent=2);f.write('\n')
print(json.dumps({'manifest':path.relative_to(ROOT).as_posix(),'sha256':sha(path)}))
