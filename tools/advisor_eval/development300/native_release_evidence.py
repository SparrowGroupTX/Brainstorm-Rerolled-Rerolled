"""Freeze existing successful native/build/runtime receipts; executes no worker."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
prefix=sys.argv[1];assert prefix.isalnum()
out=ROOT/'tools/advisor_eval/runs'/f'{prefix}_native_evidence.json'
assert not out.exists()
base=ROOT/'tools/advisor_eval/runs/gold299_20260914'
bound=read(base/'M04/registration.json')['files']
for rel,h in bound.items():
    if rel.startswith('Immolate/'):assert sha(ROOT/rel)==h
sources={rel:sha(ROOT/rel) for rel in bound if rel.startswith('Immolate/') and '/tests/' not in rel}
tests={rel:sha(ROOT/rel) for rel in bound if rel.startswith('Immolate/tests/')}
for p in (ROOT/'tests').glob('advisor_collection_*.lua'):tests[p.relative_to(ROOT).as_posix()]=sha(p)
for name in ('advisor_native_dispatch.lua','advisor_decision_budget.lua','advisor_runtime.lua','advisor_gold_layout.lua','test_advisor_install_ui.py','test_advisor_install_slice.py'):
    p=ROOT/'tests'/name;tests[p.relative_to(ROOT).as_posix()]=sha(p)
runtime={p.relative_to(ROOT).as_posix():sha(p) for p in (ROOT/'Brainstorm').rglob('*.lua') if p.name!='config.lua'}
for name in ('tools/install_advisor.ps1','tools/advisor_eval/install_slice.py'):
    runtime[name]=sha(ROOT/name)
validation=[read(ROOT/'tools/advisor_eval/development300/native_collection_build4/synthetic.json')]
for name in ('M04','M07'):
    folder=base/name;record=read(folder/'record.json');registration=read(folder/'registration.json')
    assert record['status']=='complete' and record['exit_code']==0 and record['frozen_files_unchanged']
    validation.append({k:record[k] for k in ('status','exit_code','elapsed_seconds','timeout_seconds')})
    validation[-1].update(command=registration['command'],log={'path':(folder/'trace.log').relative_to(ROOT).as_posix(),'sha256':sha(folder/'trace.log')})
candidate=ROOT/'tools/advisor_eval/runs'/f'{prefix}_candidate/validation/report.json'
report=read(candidate);assert report['passed']
for item in report['runs']:
    # Validator receipts preserve exact command, cap and file-backed logs.
    assert item['status']=='passed' and item['exit_code']==0
    log=candidate.parent/(item['name']+'.log')
    validation.append({'status':'complete','exit_code':0,'command':item['command'],
      'timeout_seconds':60,'elapsed_seconds':item['seconds'],
      'log':{'path':log.relative_to(ROOT).as_posix(),'sha256':sha(log)}})
dll='Brainstorm/Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll'
evidence={'schema':1,'kind':'advisor_native_slice','dll':{'path':dll,'sha256':sha(ROOT/dll)},
 'sources':sources,'tests':tests,'runtime_files':runtime,
 'build':read(ROOT/'tools/advisor_eval/development300/native_collection_build4/build.json'),
 'validation':validation}
out.write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
print(out)
