"""Verify the candidate and historical preservation without reading active journals."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import json
import subprocess
import sys

HERE=Path(__file__).resolve().parent
EVAL=HERE.parent
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--candidate',required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    assert a.candidate.startswith('repair408_candidate') and a.candidate.replace('_','').isalnum()
    assert not a.output.exists()
    frozen_dir=EVAL/'runs'/a.candidate
    frozen=json.loads((frozen_dir/'freeze.json').read_text())
    gate=json.loads((frozen_dir/'validation/report.json').read_text())
    pre=json.loads((HERE/'prework.json').read_text())
    baseline=json.loads((EVAL/'SESSION_RESET_404.json').read_text())
    assert gate['passed'] and gate['provenance_unchanged']
    assert policy_hashes(ROOT)==policy_hashes(frozen_dir/'policy')==frozen['candidate_policy_files']==gate['policy_files']
    assert test_manifest()==frozen['test_files']==gate['test_files']
    assert provenance()==frozen['validation_provenance']==gate['validation_provenance']
    for rel,h in frozen['test_files'].items():
        assert file_digest(frozen_dir/'tests_source'/rel)==h,rel
    installed=Path(baseline['installed'])
    assert policy_hashes(installed.parent)==baseline['policy_files']==pre['runtime_files']
    for name in ('native_repository','native_installed'):
        for rel,h in pre[name].items():
            assert file_digest(ROOT/rel)==h,rel
    for rel,h in pre['before_files'].items():
        assert file_digest(HERE/'before'/rel)==h,rel
    nav=('ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md',
         'tools/advisor_eval/NEXT_PRIORITIES_404.md','tools/advisor_eval/ARCHITECTURE_MAP_404.md',
         'tools/advisor_eval/WIN_RATE_RESEARCH.md')
    for rel in nav:
        assert (ROOT/rel).read_bytes().endswith((HERE/'before'/rel).read_bytes()),rel
    allowed=set(frozen['changed_runtime_files'])|set(nav)|{
        'tests/advisor_runtime.lua','tests/advisor_shop_sequences.lua','tests/advisor_acorn_lucky.lua',
        'tools/advisor_eval/flag_suspect_decisions.py'}
    for rel,h in pre['before_files'].items():
        assert (ROOT/rel).is_file(),rel
        if rel not in allowed:assert file_digest(ROOT/rel)==h,rel
    prior=EVAL/'development407/FINAL_VERIFICATION.json'
    assert file_digest(prior)==pre['prior407_verification']
    old=json.loads(prior.read_text())
    artifacts={rel:h for rel,h in old['artifact_hashes'].items() if rel.startswith('tools/advisor_eval/development407/')}
    for rel,h in artifacts.items():assert file_digest(ROOT/rel)==h,rel
    manifest=json.loads((EVAL/'development407/capture/manifest.json').read_text())
    for row in manifest['segments']:
        assert file_digest(EVAL/'development407/logs1'/row['name'])==row['sha256']
    status=subprocess.run(['git','status','--short','--untracked-files=all'],cwd=ROOT,capture_output=True,text=True,check=True).stdout
    (HERE/'git_status_after.txt').write_text(status,encoding='utf-8')
    paths=lambda raw:{line[3:] for line in raw.splitlines() if line}
    assert paths((HERE/'git_status_before.txt').read_text(encoding='utf-8'))<=paths(status)
    process=subprocess.run(['pwsh','-NoProfile','-Command',
        '@(Get-Process Balatro -ErrorAction SilentlyContinue | Select-Object Id,StartTime) | ConvertTo-Json -Compress'],
        capture_output=True,text=True,check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    observed=json.loads(process.stdout) if process.stdout.strip() else []
    report={'verified_utc':datetime.now(timezone.utc).isoformat(),'candidate':a.candidate,
        'candidate_digest':frozen['candidate_policy_digest'],'candidate_version':frozen['candidate_version'],
        'runtime_files':len(gate['policy_files']),'test_files':len(gate['test_files']),
        'candidate_full_gate_passed':True,'runtime_tests_provenance_unchanged':True,
        'gate_sha256':file_digest(frozen_dir/'validation/report.json'),
        'installed_baseline':'exact2.195 checkpoint404','installed_runtime_unchanged':True,
        'repository_and_installed_native_files_preserved':7,'before_files_preserved':len(pre['before_files']),
        'navigation_history_bytes_preserved':True,'prior_git_status_paths_preserved':True,
        'prior407_artifacts_preserved':len(artifacts),'copied407_segments_preserved':len(manifest['segments']),
        'passive_process':observed,'active_session_journals_read':False,'installation_performed':False,
        'normal_exit_confirmed_for_current_session':False,'game_control':False,
        'save_or_profile_access':False,'captured_state_policy_execution':False,'new_experiment':False,
        'configuration_writes':False,
        'installed_config_sha256_at_verification':file_digest(installed/'config.lua'),
        'artifacts':{str(f.relative_to(ROOT)).replace('\\','/'):file_digest(f) for f in sorted(HERE.glob('*'))
                     if f.is_file() and f.resolve()!=a.output.resolve() and
                     not (f.name.startswith('verify_candidate') and f.suffix=='.log')}}
    a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ('candidate','candidate_digest','candidate_full_gate_passed','installed_runtime_unchanged','passive_process')}))


if __name__=='__main__':main()
