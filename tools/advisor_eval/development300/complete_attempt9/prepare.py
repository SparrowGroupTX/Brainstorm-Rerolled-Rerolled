"""Prepare C09 tooling only. No installation binding, registration or execution."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE=ROOT/'tools/advisor_eval/runs/gold299_20260914'
assert not (BASE/'C09').exists() and not (BASE/'C09_reservation.json').exists()
prior=json.loads((BASE/'C07/registration.json').read_text())
names=['benchmark.py','development_report.py','engine_contract.lua','engine_probe.lua','engine_probe.py','engine_run.lua',
       'gold_objective_context.lua','gold_objective_spec.py','normal_opening_recipe.json','normal_recipe.py',
       'normal_seed_selection.json','normal_terminal.lua','opening_support.py','policy_wiring.lua','test_wiring.lua','check_graph.py']
origins=[]
for name in names:
    data=(BASE/'C07'/name).read_bytes(); actual=hashlib.sha256(data).hexdigest()
    assert actual==prior['files'][name]
    with (HERE/name).open('xb') as stream:stream.write(data)
    origins.append({'file':name,'source_job':'C07','source':'C07/'+name,'source_sha256':actual,'prepared_sha256':actual,'changed':False})
worker=(BASE/'C07/run_attempt7.py').read_text().replace('C07','C09').replace('2.120.0-alpha','2.121.0-alpha').replace('!= 320','!= 321').replace("'previous_same_seed_attempt': 'C06'","'previous_same_seed_attempt': 'C07'")
with (HERE/'run_attempt9.py').open('x',encoding='utf-8',newline='\n') as stream:stream.write(worker)
with (HERE/'preparation_origins.json').open('x',encoding='utf-8') as stream:json.dump(origins,stream,indent=2);stream.write('\n')
print(json.dumps({'copied_unchanged_files':len(origins),'prepared_only':True}))
