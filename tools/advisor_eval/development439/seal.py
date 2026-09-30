"""Bind all twenty jobs, implementation and review before captured execution."""
from pathlib import Path
import json
import run
HERE=Path(__file__).resolve().parent
q=run.read(HERE/'QUALIFIED.json');m=run.read(HERE/'QUALIFICATION_INPUTS.json')
assert q['qualification_inputs_sha256']==run.sha(HERE/'QUALIFICATION_INPUTS.json')
assert not(HERE/'EXECUTION_STARTED.json').exists() and not(HERE/'CLOSED.json').exists()
paths=[p for p in(HERE/'frozen').rglob('*') if p.is_file()]
paths += [HERE/name for name in ('PLAN.md','CASE_SELECTION.json','cases.json','jobs.json','registration.json','run.py','evidence_reader.py',
 'test_runner.py','runner_controls1.log','test_analysis.py','analysis_controls1.log','preflight.py','QUALIFIED.json','QUALIFICATION_INPUTS.json','REVIEW.md',
 'prepare_cases.py','freeze_experiment.py','seal.py','analyze.py')]
for rel,h in m['files'].items():assert run.sha(HERE/rel)==h
capture=HERE/'captures/001';cm=run.read(capture/'manifest.json')
for row in cm['segments']:assert run.sha(capture/'logs'/row['name'])==row['sha256']
for name in ('manifest.json','summary.json'):m['source_files'][str(capture/name)]=run.sha(capture/name)
m['files']={p.relative_to(HERE).as_posix():run.sha(p) for p in sorted(paths)}
run.save(HERE/'manifest.json',m);run.save(HERE/'READY.json',{'manifest_sha256':run.sha(HERE/'manifest.json'),'one_use':True,'jobs':20})
print(json.dumps({'ready':True,'manifest':run.sha(HERE/'manifest.json'),'jobs':20}))
