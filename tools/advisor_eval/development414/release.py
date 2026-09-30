"""Install exact validated2.199 revision414 after this session's own exit."""
from pathlib import Path
from datetime import datetime,timezone
import json,shutil,subprocess,sys
HERE=Path(__file__).resolve().parent;EVAL=HERE.parent;ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance
CANDIDATE=EVAL/'runs/repair414_candidate2';FINAL=EVAL/'runs/repair414_installed'
def now():return datetime.now(timezone.utc).isoformat()
def save(path,value):
    with path.open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
def processes():
    r=subprocess.run(['pwsh','-NoProfile','-Command','@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],capture_output=True,text=True,check=True,creationflags=subprocess.CREATE_NO_WINDOW)
    return json.loads(r.stdout) if r.stdout.strip() else []
def absent():assert not processes(),'Balatro is running; installation prohibited'
def journals(source=False):
    m=json.loads((HERE/'capture/manifest.json').read_text())
    for row in m['segments']:assert file_digest(HERE/'logs1'/row['name'])==row['sha256']
    if source:assert {p.name:file_digest(p) for p in Path(m['source']).glob('*.brj')}=={r['name']:r['sha256'] for r in m['segments']}
    v=json.loads((HERE/'capture/verification.json').read_text())
    assert not v['failures'] and v['session']==m['session']
    return m
def exact(deployed=False):
    base=json.loads((EVAL/'SESSION_RESET_412.json').read_text());installed=Path(base['installed'])
    freeze=json.loads((CANDIDATE/'freeze.json').read_text());gate=json.loads((CANDIDATE/'validation/report.json').read_text())
    pre=json.loads((HERE/'prework.json').read_text())
    assert gate['passed'] and gate['policy_unchanged'] and gate['tests_unchanged'] and gate['provenance_unchanged']
    assert policy_hashes(ROOT)==policy_hashes(CANDIDATE/'policy')==freeze['candidate_policy_files']==gate['policy_files']
    assert test_manifest()==freeze['test_files']==gate['test_files']
    assert provenance()==freeze['validation_provenance']==gate['validation_provenance']==pre['provenance']
    for rel,sha in freeze['test_files'].items():assert file_digest(CANDIDATE/'tests_source'/rel)==sha
    assert policy_hashes(installed.parent)==(freeze['candidate_policy_files'] if deployed else base['policy_files'])
    assert file_digest(installed/'config.lua')==pre['config_sha256']
    for root in (ROOT/'Brainstorm',installed):assert {p.name:file_digest(p) for p in root.glob('*.dll')}==pre['native_files']
    for rel,sha in pre['prior_files'].items():assert file_digest(ROOT/rel)==sha,rel
    return base,installed,freeze,pre
def main():
    absent();base,installed,freeze,pre=exact();manifest=journals(True)
    confirmation=json.loads((HERE/'normal_exit_confirmation.json').read_text())
    assert confirmation['confirmed'] and manifest['session'] in confirmation['public_sessions']
    expected=freeze['candidate_policy_files']
    delta={p for p in expected.keys()|base['policy_files'].keys() if expected.get(p)!=base['policy_files'].get(p)}
    assert delta==set(freeze['changed_runtime_files']) and len(delta)==5
    command=[sys.executable,str(EVAL/'install_slice.py'),'--version','2.199.0-alpha',*[p.removeprefix('Brainstorm/') for p in sorted(delta)]]
    save(HERE/'preinstall_verification.json',{'verified_utc':now(),'command':command,'candidate_digest':freeze['candidate_policy_digest'],
      'exact_candidate_gate_passed':True,'normal_exit_confirmed':True,'passive_processes':processes(),
      'public_log_segments_preserved':len(manifest['segments']),'config_sha256':pre['config_sha256'],'native_files':pre['native_files']})
    absent();assert not FINAL.exists() and not (HERE/'installation.log').exists()
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,creationflags=subprocess.CREATE_NO_WINDOW)
    (HERE/'installation.log').write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
    assert r.returncode==0,r.stderr
    receipt=json.loads(r.stdout.splitlines()[0]);absent();exact(True);journals(True)
    FINAL.mkdir()
    for rel,sha in expected.items():
        target=FINAL/'policy'/rel;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(installed.parent/rel,target);assert file_digest(target)==sha
    assert policy_hashes(FINAL/'policy')==expected
    save(FINAL/'record.json',{'created_utc':now(),'installation':receipt,'installed':str(installed),'command':command,
      'policy_digest':freeze['candidate_policy_digest'],'policy_files':expected,'test_files':test_manifest(),
      'validation_provenance':provenance(),'config_sha256':pre['config_sha256'],'native_files_preserved':pre['native_files'],
      'normal_exit_confirmation_sha256':file_digest(HERE/'normal_exit_confirmation.json'),
      'candidate_freeze_sha256':file_digest(CANDIDATE/'freeze.json'),'activation':'Unconfirmed; awaits user start'})
    print(json.dumps({'version':'2.199.0-alpha','backup':receipt['backup'],'digest':freeze['candidate_policy_digest'],'installed_gate':'pending'}))
if __name__=='__main__':main()
