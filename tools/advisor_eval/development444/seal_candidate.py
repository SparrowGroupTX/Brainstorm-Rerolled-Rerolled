"""Verify the exact full gate and preservation before authorized deployment."""
from pathlib import Path
from datetime import datetime,timezone
import json,re,sys
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import policy_hashes,file_digest
from validate_checkpoint import test_manifest,provenance
def read(p):return json.loads(p.read_text())
def save(p,x):
 with p.open('x')as f:json.dump(x,f,indent=2);f.write('\n')
P=read(H/'prework.json');C=E/'runs/repair444_candidate1';F=read(C/'freeze.json');G=read(C/'validation/report.json')
assert all(G[k]for k in('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
assert G['lua_workers']==2 and G['lua_worker_deadline_seconds']==55
assert policy_hashes(R)==policy_hashes(C/'policy')==F['candidate_policy_files']==P['runtime_files']
assert test_manifest()==F['test_files']==G['test_files']and provenance()==F['validation_provenance']==G['validation_provenance']
for rel,hash_ in P['prior_files'].items():assert file_digest(R/rel)==hash_,rel
for rel,hash_ in P['before_files'].items():assert file_digest(H/'before'/rel)==hash_,rel
lua=(C/'validation/lua.log').read_text();m=re.search(r'(\d+)/(\d+) fixtures passed',lua);assert m and m[1]==m[2]=='322'
python=sum(int(re.search(r'Ran (\d+) tests',(C/'validation'/n).read_text())[1])for n in('python.log','python_1.log','python_2.log'));assert python==494
assert 'Focused recheck complete' in(H/'REVIEW.md').read_text()
receipt={'created_utc':datetime.now(timezone.utc).isoformat(),'revision':444,'candidate_version':'2.219.0-alpha','candidate_policy_digest':F['candidate_policy_digest'],'candidate_policy_files':F['candidate_policy_files'],'runtime_unchanged_from_reviewed442':True,'validation_scheduling_only_repair':True,'full_gate_passed':True,'lua_fixtures':322,'python_tests':494,'runtime_files':110,'test_files':375,'lua_workers':2,'lua_worker_deadline_seconds':55,'outer_gate_seconds':60,'review_exhausted':True,'prior_files_preserved':len(P['prior_files']),'installed_yet':False,'captured_policy_experiments':0,'all_historical_experiments':'CLOSED','installation_policy_sha256':file_digest(E/'INSTALLATION_POLICY.md')}
save(H/'FINAL_VERIFICATION.json',receipt);save(E/'CANDIDATE_CHECKPOINT_444.json',receipt)
text=f'''#444 candidate2.219 ready for installation

The reviewed442 runtime bytes are unchanged. Exact candidate gate now passes
322Lua/494Python tests. Digest `{F['candidate_policy_digest']}`.
The blocker was serial suite wall time: diagnostic322/322passed in74.687s;
new forecast fixture took0.4075s. Two isolated DLL workers now execute every
same fixture once under shared55s deadline; the outer60s gate is unchanged.
Seven manufactured scheduler controls pass. No runtime proof, scoring budget
or test assertion weakened. Scope/review/provenance and all{len(P['prior_files'])}
prior artifact hashes are preserved. No game control or captured experiment.

This is the candidate record before deployment. A later INSTALLED_CHECKPOINT_444
establishes installation and exact-installed qualification. Latest complete2.218
marathon remains preserved under development443/log_copy/captures/001. No loaded
2.219 improvement is yet established, and discard/Acorn limitations remain.
'''
with(E/'CANDIDATE_CHECKPOINT_444.md').open('x')as f:f.write(text)
with(H/'REPORT.md').open('x')as f:f.write(text)
print(json.dumps({'candidate_ready':True,'lua':322,'python':494,'digest':F['candidate_policy_digest']}))
