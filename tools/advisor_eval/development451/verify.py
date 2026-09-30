"""Close the finalizer's redirected log receipt and verify delivery hashes."""
from pathlib import Path
from datetime import datetime,timezone
import json,sys,shutil,hashlib
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
path=H/'FINAL_VERIFICATION.json';V=read(path);P=read(H/'prework.json');C=E/'runs/repair451_candidate1';F=read(C/'freeze.json')
bad=[rel for rel,h in V['artifact_hashes'].items()if file_digest(R/rel)!=h]
if bad:
    # finalize.py seals its own then-empty redirected stdout before printing.
    # Preserve that initial receipt and record only the subsequently closed log.
    rel='tools/advisor_eval/development451/finalize.log'
    assert bad==[rel]and V['artifact_hashes'][rel]==hashlib.sha256(b'').hexdigest(),bad
    previous=H/'VERIFICATION_BEFORE_LOG_CLOSE.json';assert not previous.exists();shutil.copy2(path,previous)
    V['artifact_hashes'][rel]=file_digest(R/rel)
    V['artifact_hashes'][previous.relative_to(R).as_posix()]=file_digest(previous)
    V['artifact_hashes'][Path(__file__).relative_to(R).as_posix()]=file_digest(Path(__file__))
    V['finalization_log_closed_utc']=datetime.now(timezone.utc).isoformat()
    V['log_closure_note']='Initial receipt preserved; finalize stdout hash taken after process completion.'
    path.write_text(json.dumps(V,indent=2)+'\n',encoding='utf-8')
for rel,h in V['artifact_hashes'].items():assert file_digest(R/rel)==h,rel
for rel,h in V['navigation_hashes'].items():assert file_digest(R/rel)==h,rel
for rel,h in P['prior_files'].items():assert file_digest(R/rel)==h,rel
for rel,h in P['before_files'].items():assert file_digest(H/'before'/rel)==h,rel
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']
assert test_manifest()==F['test_files']and provenance()==F['validation_provenance']
assert policy_hashes(Path(P['installed']['installed']).parent)==P['installed']['policy_files']
assert file_digest(Path(P['installed']['installed'])/'config.lua')==P['config_sha256']
assert file_digest(E/'INSTALLATION_POLICY.md')==P['before_files']['tools/advisor_eval/INSTALLATION_POLICY.md']
print(json.dumps({'verified':True,'prior_files':len(P['prior_files']),'artifacts':len(V['artifact_hashes']),
    'candidate_version':V['version'],'installed_version':V['installed_version'],'installed_unchanged':True}))
