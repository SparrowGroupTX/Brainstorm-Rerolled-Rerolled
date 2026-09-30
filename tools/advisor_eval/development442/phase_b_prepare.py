"""Prepare the single optional registered second phase; no captured execution."""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,shutil,subprocess,sys
H=Path(__file__).resolve().parent; E=H.parent; A=H/'phase_a'; B=H/'phase_b'; C=E/'runs/repair442_candidate2'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2);f.write('\n')
assert read(C/'validation/report.json')['passed']
B.mkdir(exist_ok=False);shutil.copytree(A/'frozen',B/'frozen')
for name in ('run.py','evidence_reader.py','cases.json','jobs.json','CASE_SELECTION.json','preflight.py','REUSED_CONTROLS.json'):
 if (A/name).exists():shutil.copy2(A/name,B/name)
m=read(A/'QUALIFICATION_INPUTS.json')
for key,path in m['modules'].items():
 dst=B/'frozen'/Path(path).name;src=C/'policy/Brainstorm/Advisor'/dst.name
 assert src.exists();shutil.copy2(src,dst);m['modules'][key]=str(dst)
m['policy_digest']=read(C/'freeze.json')['candidate_policy_digest']
m['source_files']={str(p):sha(p)for p in (C/'freeze.json',C/'validation/report.json',H/'PLAN.md',A/'CLOSED.json',A/'RESULTS.json')}
reg=read(A/'registration.json');reg.update(created_utc=datetime.now(timezone.utc).isoformat(),phase='B')
save(B/'registration.json',reg)
source=(A/'analyze.py').read_text().replace('Candidate2.218','Candidate2.219').replace('phase A','phase B')
source=source.replace('All20 registrations are consumed, with no retries or replacements. Candidate2.217 remains uninstalled. The source session was an active prefix; no completed-session or normal-exit inference. No baseline causal comparison. Round rewards/future shops are not modeled. No Acorn or Heart case was selected.','All20 registrations are consumed, with no retries or replacements. Candidate2.219 is uninstalled. Matched phase A provides a fixed-world development comparison. Legacy snapshots lack exact sort metadata; this cohort does not validate that repair. Round rewards/future shops are not modeled. No Acorn or Heart case was selected.')
(B/'analyze.py').write_text(source)
m['files']={p.relative_to(B).as_posix():sha(p)for p in B.rglob('*')if p.is_file()};save(B/'QUALIFICATION_INPUTS.json',m)
subprocess.run([sys.executable,'-B',str(B/'preflight.py')],check=True)
m['files'].update({n:sha(B/n)for n in ('QUALIFICATION_INPUTS.json','QUALIFIED.json')})
save(B/'manifest.json',m);save(B/'READY.json',{'manifest_sha256':sha(B/'manifest.json'),'one_use':True,'jobs':20})
print('Phase B frozen and qualified; execution remains one-use.')
