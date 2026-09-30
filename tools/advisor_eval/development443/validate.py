"""Exact tooling freeze and all Python regression groups; no Lua/policy run."""
from pathlib import Path
from datetime import datetime,timezone
import difflib,json,subprocess,sys,time
H=Path(__file__).resolve().parent;E=H.parent;R=E.parents[1];sys.path.insert(0,str(E))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance,PYTHON_GROUPS
def read(p):return json.loads(p.read_text())
def save(p,x):
 with p.open('x',encoding='utf-8')as f:json.dump(x,f,indent=2);f.write('\n')
out=H/('validation'+(sys.argv[1]if len(sys.argv)>1 else'1'));out.mkdir(exist_ok=False)
P=read(H/'prework.json');assert policy_hashes(R)==P['runtime_files']
files={rel:file_digest(R/rel)for rel in ('tools/advisor_eval/flag_suspect_decisions.py','tools/advisor_eval/review_decisions.py','tools/advisor_eval/read_player_log.py','tests/test_advisor_decision_review443.py')}
tests=test_manifest();prov=provenance()
freeze={'created_utc':datetime.now(timezone.utc).isoformat(),'tool_files':files,'tests':tests,'provenance':prov,'runtime_unchanged':P['runtime_files'],'scope_sha256':file_digest(H/'SCOPE.md')}
save(out/'freeze.json',freeze)
for rel in set(files)|set(tests):
 dst=out/'sources'/rel;dst.parent.mkdir(parents=True,exist_ok=True)
 with dst.open('xb')as f:f.write((R/rel).read_bytes())
diff=[]
for rel in files:
 old=H/'before'/rel
 if old.exists()or rel.endswith(('review_decisions.py','test_advisor_decision_review443.py')):
  diff.extend(difflib.unified_diff(old.read_text().splitlines(True)if old.exists()else[],(R/rel).read_text().splitlines(True),fromfile='before/'+rel,tofile=rel))
(out/'changes.diff').write_text(''.join(diff),encoding='utf-8')
results=[]
for i,pattern in enumerate(PYTHON_GROUPS):
 command=[sys.executable,'-B','-m','unittest','discover','-s','tests','-p',pattern];tick=time.monotonic()
 try:
  p=subprocess.run(command,cwd=R,capture_output=True,text=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
  row={'pattern':pattern,'status':'passed'if p.returncode==0 else'failed','exit_code':p.returncode};log=p.stdout+'\n'+p.stderr
 except subprocess.TimeoutExpired as ex:
  row={'pattern':pattern,'status':'timeout','timeout_seconds':60};log=str(ex.stdout)+'\n'+str(ex.stderr)
 row['seconds']=time.monotonic()-tick;results.append(row);(out/f'python{i}.log').write_text(log,encoding='utf-8')
unchanged=files=={rel:file_digest(R/rel)for rel in files}and tests==test_manifest()and prov==provenance()and policy_hashes(R)==P['runtime_files']
report={'runs':results,'exact_inputs_unchanged':unchanged,'passed':unchanged and all(r['status']=='passed'for r in results),'lua_or_captured_policy_executed':False}
save(out/'report.json',report);print(json.dumps(report));raise SystemExit(0 if report['passed'] else 1)
