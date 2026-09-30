"""Install only the validated404 slice after explicit current-session confirmation."""
from datetime import datetime,timezone
from pathlib import Path
import argparse,json,shutil,subprocess,sys

EVAL=Path(__file__).resolve().parents[1]
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--finish-existing',action='store_true',help='Verify/freeze the already successful logged installation; never deploy again')
    args=parser.parse_args()
    development=EVAL/'development404'
    confirmation=development/'normal_exit_confirmation.json'
    preflight=development/'preinstall_verification.json'
    if not args.finish_existing:
        assert not preflight.exists()
        subprocess.run([sys.executable,str(development/'verify_release.py'),'--output',str(preflight),
           '--normal-exit-confirmation',str(confirmation)],cwd=ROOT,check=True)
    else:
        subprocess.run([sys.executable,str(development/'verify_release.py'),'--installed',
           '--output',str(development/'postinstall_pre_gate_verification.json'),
           '--normal-exit-confirmation',str(confirmation)],cwd=ROOT,check=True)
    before=json.loads(preflight.read_text());assert before['normal_exit_confirmed']
    base=json.loads((EVAL/'SESSION_RESET_400.json').read_text())
    installed=Path(base['installed'])
    candidate=EVAL/'runs/repair404_candidate2'
    freeze=json.loads((candidate/'freeze.json').read_text())
    files=[str(Path(p).relative_to('Brainstorm')).replace('\\','/') for p in freeze['changed_runtime_files']]
    assert len(files)==15 and all(p.endswith('.lua') for p in files)
    command=[sys.executable,str(EVAL/'install_slice.py'),'--version','2.195.0-alpha',*files]
    log=development/'installation.log'
    if not args.finish_existing:
        assert not log.exists()
        result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,
           creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        log.write_text(result.stdout+'\n'+result.stderr)
        assert result.returncode==0,result.stderr
    receipt=json.loads(log.read_text().splitlines()[0])
    expected=freeze['candidate_policy_files']
    assert policy_hashes(ROOT)==policy_hashes(installed.parent)==expected
    assert file_digest(installed/'config.lua')==before['installed_config_sha256']==receipt['configSHA256'].lower()
    assert {p.name:file_digest(p) for p in installed.glob('*.dll')}==before['native_files_preserved']
    assert test_manifest()==freeze['test_files'] and provenance()==freeze['validation_provenance']
    out=EVAL/'runs/repair404_installed';out.mkdir(exist_ok=False)
    for relative in expected:
        source=installed.parent/relative;target=out/'policy'/relative
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    assert policy_hashes(out/'policy')==expected==policy_hashes(installed.parent)
    report={'created_utc':datetime.now(timezone.utc).isoformat(),'installation':receipt,
      'installed':str(installed),'command':command,'policy_digest':digest(expected),'policy_files':expected,
      'test_files':test_manifest(),'validation_provenance':provenance(),
      'candidate_freeze_sha256':file_digest(candidate/'freeze.json'),
      'normal_exit_confirmation_sha256':file_digest(confirmation),'preflight_sha256':file_digest(preflight),
      'config_sha256':before['installed_config_sha256'],'native_files_preserved':before['native_files_preserved'],
      'activation':'Unconfirmed; awaits normal user start','game_process_control':False}
    (out/'record.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'version':'2.195.0-alpha','backup':receipt['backup'],'digest':digest(expected),
      'installed_freeze':str(out),'full_installed_gate':'pending'}))

if __name__=='__main__':main()
