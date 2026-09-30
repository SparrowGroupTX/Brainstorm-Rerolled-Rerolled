"""Prospective, one-use seal after qualification and the focused review."""
from pathlib import Path
import sys
from run import HERE,read,save,sha,now
assert not(HERE/'EXECUTION_STARTED.json').exists()
qualification=read(HERE/'QUALIFIED.json');assert qualification['status']=='passed'
for name,h in qualification['files'].items():assert sha(HERE/name)==h,name
assert (HERE/'REVIEW.md').is_file()
files={}
for p in (HERE/'frozen').rglob('*'):
 if p.is_file():files[str(p)]=sha(p)
for name in ('PLAN.md','adapter.lua','test_adapter.lua','test_runner.py','run.py','prepare.py','freeze.py','cases.json','jobs.json',
 'registration.json','QUALIFIED.json','REVIEW.md','preflight3.log','runner_tests2.log'):
 p=HERE/name;files[str(p)]=sha(p)
proposal=HERE.parent/'TARGETED_EXPERIMENT_PROPOSAL_435.md';files[str(proposal)]=sha(proposal)
reg=read(HERE/'registration.json');source=Path(reg['source']);assert sha(source)==reg['source_sha256']
for folder in ('ledger','results','bindings'):(HERE/folder).mkdir(exist_ok=False)
save(HERE/'manifest.json',{'at':now(),'files':files,'source_files':{str(source):sha(source)},'python_version':sys.version,
 'python_sha256':sha(sys.executable),'authorization':'Go for it. You can use way more than a single worker though.',
 'policy':'installed434 / 2.214.0-alpha','policy_digest':'0d0dbdc6086e3bd1b96394e0932af75347fabb1494ed120301f131812daf642e',
 'registration':reg,'manufactured_qualification':qualification,'no_auto_resume':True})
save(HERE/'READY.json',{'at':now(),'manifest_sha256':sha(HERE/'manifest.json'),'prospective':True})
print('READY: 53 jobs maximum; four workers; frozen before any captured evaluation')
