"""Bind tooling405 completion to unchanged runtime404 and preserved inputs."""
from datetime import datetime,timezone
from pathlib import Path
import json,subprocess,sys

EVAL=Path(__file__).resolve().parents[1];ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance

def main():
    dev=Path(__file__).resolve().parent
    before=json.loads((dev/'prework.json').read_text())
    base=json.loads((EVAL/'SESSION_RESET_404.json').read_text())
    installed=Path(base['installed']);gate=json.loads((dev/'validation/report.json').read_text())
    frozen=json.loads((dev/'validation/manifest.json').read_text())
    assert gate['passed'] and gate['total_python_tests']==413
    assert gate['manifest_sha256']==file_digest(dev/'validation/manifest.json')
    assert policy_hashes(ROOT)==policy_hashes(installed.parent)==base['policy_files']==before['runtime_files']
    assert test_manifest()==frozen['test_files'] and provenance()==frozen['provenance']
    assert len(frozen['test_files'])==313
    for rel,sha in before['baseline_tests'].items():assert file_digest(ROOT/rel)==sha,rel
    for rel,sha in before['original_files'].items():assert file_digest(dev/'before'/rel)==sha,rel
    for rel,sha in frozen['changed_source_files'].items():
        assert file_digest(ROOT/rel)==sha==file_digest(dev/'validation/sources'/rel)
    natives={p.name:file_digest(p) for p in installed.glob('*.dll')}
    assert natives==base['native_files_preserved']
    process=subprocess.run(['pwsh','-NoProfile','-Command',
       "@(Get-Process -Name Balatro -ErrorAction SilentlyContinue | Select-Object Id,ProcessName) | ConvertTo-Json -Compress"],
       capture_output=True,text=True,check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    active=json.loads(process.stdout) if process.stdout.strip() else []
    status=subprocess.run(['git','status','--porcelain=v1','--untracked-files=all'],cwd=ROOT,
                          capture_output=True,text=True,check=True)
    (dev/'git_status_after.txt').write_text(status.stdout,encoding='utf-8')
    documents=[EVAL/'PUBLIC_LOG_INTEGRITY_405.md',EVAL/'TOOLING_CHECKPOINT_405.md',EVAL/'README.md',
       EVAL/'WIN_RATE_RESEARCH.md',ROOT/'ADVISOR_START_HERE.md',ROOT/'ADVISOR_RESUME_PROMPT.md',ROOT/'ADVISOR_HANDOFF.md']
    artifacts=list(dev.glob('*.py'))+list(dev.glob('*.md'))+list(dev.glob('*.log'))+[
        dev/'prework.json',dev/'validation/manifest.json',dev/'validation/report.json',
        EVAL/'SESSION_RESET_404.json',EVAL/'runs/repair404_candidate2/freeze.json',
        EVAL/'runs/repair404_installed/record.json']+documents
    report={'verified_utc':datetime.now(timezone.utc).isoformat(),'status':'tooling405_complete_runtime404_unchanged',
       'runtime_version':base['version'],'runtime_digest':base['policy_digest'],'runtime_files':109,
       'native_files_preserved':natives,'python_tests_passed':413,'frozen_test_files':313,
       'baseline312_tests_unchanged':True,'tooling_tests_provenance_unchanged_after_gate':True,
       'original_sources_and_failures_preserved':True,'runtime_installation_or_config_writes':False,
       'passive_game_processes':active,'active_journals_read':False,'current_loaded_label':'not inspected',
       'current_session_outcomes':'not inspected','game_control':False,'save_or_profile_access':False,
       'captured_policy_or_scorer_replay':False,'new_experiment_or_automation':False,
       'artifact_hashes':{p.relative_to(ROOT).as_posix():file_digest(p) for p in artifacts}}
    out=dev/'final_verification.json';assert not out.exists()
    out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ('status','runtime_digest','python_tests_passed','frozen_test_files','passive_game_processes')}))

if __name__=='__main__':main()
