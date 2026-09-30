"""Copy preserved declared files into new C08 preparation; no experiments."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
BASE=ROOT/'tools/advisor_eval/runs/gold299_20260914'
OUT=HERE/'complete_attempt8'
OUT.mkdir(exist_ok=False)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
registrations={job:json.loads((BASE/job/'registration.json').read_text()) for job in ('C05','C07')}
names=('benchmark.py','development_report.py','engine_contract.lua','engine_probe.lua','engine_probe.py',
       'engine_run.lua','gold_objective_context.lua','gold_objective_spec.py','normal_recipe.py',
       'normal_terminal.lua','opening_support.py','policy_wiring.lua','check_graph.py','test_wiring.lua',
       'test_compile.lua','required_features.json')
origins=[]
for job,files in [('C07',names),('C05',('normal_opening_recipe.json','normal_seed_selection.json'))]:
    for name in files:
        source=BASE/job/name
        value=sha(source);assert registrations[job]['files'][name]==value
        with (OUT/name).open('xb') as f:f.write(source.read_bytes())
        origins.append({'file':name,'source_job':job,'source':job+'/'+name,'source_sha256':value,'prepared_sha256':value,'changed':False})
with (OUT/'preparation_origins.json').open('x') as f:json.dump(origins,f,indent=2)
print(json.dumps({'copied':len(origins),'source_jobs':['C07','C05'],'worker_calls':0,'registered':False}))
