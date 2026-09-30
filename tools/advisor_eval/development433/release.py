"""Install exact validated433 only after passive absence and journal checks."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
CANDIDATE=EVAL/'runs/repair433_candidate3';FINAL=EVAL/'runs/repair433_installed'
def now():return datetime.now(timezone.utc).isoformat()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8'))
def save(p,x):
 with Path(p).open('x',encoding='utf-8')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def processes():
 r=subprocess.run(['pwsh','-NoProfile','-Command',"@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
 return json.loads(r.stdout)if r.stdout.strip()else []
def absent():assert not processes(),'Balatro is running; defer installation'
def journals(source=False):
 latest=read(EVAL/'development433/LATEST.json');folder=ROOT/latest['capture'];m=read(folder/'manifest.json');v=read(folder/'summary.json')
 assert file_digest(folder/'summary.json')==latest['summary_sha256']
 for row in m['segments']:assert file_digest(folder/'logs'/row['name'])==row['sha256']
 assert file_digest(folder/'events.sqlite3')==v['database_sha256']
 assert not v['errors']and v['session']==m['session']and v['events']==25337
 assert v['outcomes']=={'win':5,'loss':5}and not v['unended_run_ids']
 if source:
  paths=list(Path(m['source']).glob('*.brj'))
  assert max(paths,key=lambda p:p.stat().st_mtime).name.startswith(m['session']+'-'),'New session needs preservation'
  assert {p.name:file_digest(p)for p in paths if p.name.startswith(m['session']+'-')}=={r['name']:r['sha256']for r in m['segments']},'New journal bytes need preservation'
 return folder,m,v
def exact(deployed=False):
 base=read(EVAL/'SESSION_RESET_431.json');installed=Path(base['installed']);f=read(CANDIDATE/'freeze.json')
 gate=read(CANDIDATE/'validation/report.json');pre=read(HERE/'prework.json')
 assert all(gate[k]for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
 assert policy_hashes(ROOT)==policy_hashes(CANDIDATE/'policy')==f['candidate_policy_files']==gate['policy_files']
 assert test_manifest()==f['test_files']==gate['test_files']
 assert provenance()==f['validation_provenance']==gate['validation_provenance']==pre['provenance']
 assert file_digest(HERE/'SCOPE.md')==f['scope_sha256']
 for rel,h in f['test_files'].items():assert file_digest(CANDIDATE/'tests_source'/rel)==h
 assert policy_hashes(installed.parent)==(f['candidate_policy_files']if deployed else base['policy_files'])
 assert file_digest(installed/'config.lua')==pre['config_sha256']
 for root in (ROOT/'Brainstorm',installed):assert {p.name:file_digest(p)for p in root.glob('*.dll')}==pre['native_files']
 for rel,h in pre['prior_files'].items():assert file_digest(ROOT/rel)==h,rel
 for rel,h in pre['before_files'].items():assert file_digest(HERE/'before'/rel)==h
 assert file_digest(EVAL/'INSTALLATION_POLICY.md')==pre['before_files']['tools/advisor_eval/INSTALLATION_POLICY.md']
 return base,installed,f,pre
def main():
 absent();base,installed,f,pre=exact();folder,manifest,summary=journals(True)
 expected=f['candidate_policy_files'];delta={r for r in expected.keys()|base['policy_files'].keys()if expected.get(r)!=base['policy_files'].get(r)}
 assert delta==set(f['changed_runtime_files'])and len(delta)==9
 command=[sys.executable,str(EVAL/'install_slice.py'),'--version','2.213.0-alpha',*[r.removeprefix('Brainstorm/')for r in sorted(delta)]]
 save(HERE/'preinstall_verification.json',{'verified_utc':now(),'command':command,'candidate_digest':f['candidate_policy_digest'],
  'exact_candidate_gate_passed':True,'authorization':'Standing user instruction: check process and install when absent; no confirmation.',
  'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,'passive_processes':processes(),
  'public_capture':str(folder),'public_segments_preserved':len(manifest['segments']),
  'config_sha256':pre['config_sha256'],'native_files':pre['native_files']})
 assert not FINAL.exists()and not(HERE/'installation.log').exists()
 absent()
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,creationflags=subprocess.CREATE_NO_WINDOW)
 (HERE/'installation.log').write_text(r.stdout+'\n'+r.stderr,encoding='utf-8');assert r.returncode==0,r.stdout+r.stderr
 receipt=json.loads(r.stdout.splitlines()[0]);exact(True);journals(True)
 FINAL.mkdir()
 for rel,h in expected.items():
  target=FINAL/'policy'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(installed.parent/rel,target);assert file_digest(target)==h
 assert policy_hashes(FINAL/'policy')==expected
 save(FINAL/'record.json',{'created_utc':now(),'installation':receipt,'installed':str(installed),'command':command,
  'policy_digest':f['candidate_policy_digest'],'policy_files':expected,'test_files':test_manifest(),
  'validation_provenance':provenance(),'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
  'candidate_freeze_sha256':file_digest(CANDIDATE/'freeze.json'),'normal_exit_inferred':False,
  'post_install_processes':processes(),'activation':'Unconfirmed; awaits user-started loading'})
 print(json.dumps({'version':'2.213.0-alpha','backup':receipt['backup'],'digest':f['candidate_policy_digest'],'installed_gate':'pending'}))
if __name__=='__main__':main()
