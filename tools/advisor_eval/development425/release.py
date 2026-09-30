"""Deploy exact validated425 under the user's process-check installation policy."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
CANDIDATE=EVAL/'runs/repair425_candidate1';FINAL=EVAL/'runs/repair425_installed'
def now():return datetime.now(timezone.utc).isoformat()
def save(path,value):
 with path.open('x',encoding='utf-8') as f:json.dump(value,f,indent=2,allow_nan=False);f.write('\n')
def processes():
 r=subprocess.run(['pwsh','-NoProfile','-Command',"@(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -ieq 'Balatro' } | Select-Object Id,StartTime) | ConvertTo-Json -Compress"],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
 return json.loads(r.stdout) if r.stdout.strip() else []
def absent():assert not processes(),'Balatro is running; installation deferred'
def journals(source=False):
 folder=EVAL/'development426/captures/002';m=json.loads((folder/'manifest.json').read_text())
 for row in m['segments']:assert file_digest(folder/'logs'/row['name'])==row['sha256']
 if source:assert {p.name:file_digest(p) for p in Path(m['source']).glob('*.brj')}=={r['name']:r['sha256'] for r in m['segments']},'Current journals changed; preserve the newer public data before release'
 v=json.loads((folder/'summary.json').read_text())
 assert not v['errors'] and v['session']==m['session'] and v['events']==11341
 assert len(v['starts'])==5 and len(v['endings'])==4 and v['unended_run_ids']==['game:6']
 assert v['outcomes']=={'win':3,'loss':1} and len(m['segments'])==13
 assert file_digest(folder/'events.sqlite3')==v['database_sha256']
 return m
def exact(deployed=False):
 base=json.loads((EVAL/'SESSION_RESET_424.json').read_text());installed=Path(base['installed'])
 freeze=json.loads((CANDIDATE/'freeze.json').read_text());gate=json.loads((CANDIDATE/'validation/report.json').read_text())
 pre=json.loads((HERE/'prework.json').read_text())
 assert all(gate[k] for k in ('passed','policy_unchanged','tests_unchanged','provenance_unchanged'))
 assert policy_hashes(ROOT)==policy_hashes(CANDIDATE/'policy')==freeze['candidate_policy_files']==gate['policy_files']
 assert test_manifest()==freeze['test_files']==gate['test_files']
 assert provenance()==freeze['validation_provenance']==gate['validation_provenance']==pre['provenance']
 assert file_digest(HERE/'SCOPE.md')==freeze['scope_sha256']
 for rel,sha in freeze['test_files'].items():assert file_digest(CANDIDATE/'tests_source'/rel)==sha
 assert policy_hashes(installed.parent)==(freeze['candidate_policy_files'] if deployed else base['policy_files'])
 assert file_digest(installed/'config.lua')==pre['config_sha256']
 for root in (ROOT/'Brainstorm',installed):assert {p.name:file_digest(p) for p in root.glob('*.dll')}==pre['native_files']
 for rel,sha in pre['prior_files'].items():assert file_digest(ROOT/rel)==sha,rel
 assert file_digest(EVAL/'INSTALLATION_POLICY.md')==pre['before_files']['tools/advisor_eval/INSTALLATION_POLICY.md']
 final=json.loads((HERE/'FINAL_VERIFICATION.json').read_text())
 for rel,sha in final['artifact_hashes'].items():assert file_digest(ROOT/rel)==sha,rel
 assert file_digest(HERE/'final_changes.diff')==final['final_diff_sha256']
 return base,installed,freeze,pre
def main():
 absent();base,installed,freeze,pre=exact();manifest=journals(True)
 expected=freeze['candidate_policy_files']
 delta={p for p in expected.keys()|base['policy_files'].keys() if expected.get(p)!=base['policy_files'].get(p)}
 assert delta==set(freeze['changed_runtime_files']) and len(delta)==4
 command=[sys.executable,str(EVAL/'install_slice.py'),'--version','2.208.0-alpha',*[p.removeprefix('Brainstorm/') for p in sorted(delta)]]
 save(HERE/'preinstall_verification.json',{'verified_utc':now(),'command':command,'candidate_digest':freeze['candidate_policy_digest'],
  'exact_candidate_gate_passed':True,'authorization':'Existing user instruction: check process and install when absent; no further confirmation.',
  'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,'passive_processes':processes(),
  'public_log_segments_preserved':len(manifest['segments']),'config_sha256':pre['config_sha256'],'native_files':pre['native_files']})
 absent();assert not FINAL.exists() and not (HERE/'installation.log').exists()
 r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,creationflags=subprocess.CREATE_NO_WINDOW)
 (HERE/'installation.log').write_text(r.stdout+'\n'+r.stderr,encoding='utf-8');assert r.returncode==0,r.stderr
 receipt=json.loads(r.stdout.splitlines()[0]);absent();exact(True);journals(True)
 FINAL.mkdir()
 for rel,sha in expected.items():
  target=FINAL/'policy'/rel;target.parent.mkdir(parents=True,exist_ok=True)
  shutil.copy2(installed.parent/rel,target);assert file_digest(target)==sha
 assert policy_hashes(FINAL/'policy')==expected
 save(FINAL/'record.json',{'created_utc':now(),'installation':receipt,'installed':str(installed),'command':command,
  'policy_digest':freeze['candidate_policy_digest'],'policy_files':expected,'test_files':test_manifest(),
  'validation_provenance':provenance(),'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
  'installation_policy_sha256':file_digest(EVAL/'INSTALLATION_POLICY.md'),'normal_exit_inferred':False,
  'candidate_freeze_sha256':file_digest(CANDIDATE/'freeze.json'),'activation':'Unconfirmed; awaits user start'})
 print(json.dumps({'version':'2.208.0-alpha','backup':receipt['backup'],'digest':freeze['candidate_policy_digest'],'installed_gate':'pending'}))
if __name__=='__main__':main()
