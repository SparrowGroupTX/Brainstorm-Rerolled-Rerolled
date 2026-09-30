"""Read-only exact candidate/baseline/public preservation verification."""
from datetime import datetime,timezone
from pathlib import Path
import argparse,json,subprocess,sys

EVAL=Path(__file__).resolve().parents[1]
ROOT=EVAL.parents[1]
sys.path.insert(0,str(EVAL))
from benchmark import digest,file_digest,policy_hashes
from validate_checkpoint import test_manifest,provenance

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--installed',action='store_true')
    p.add_argument('--normal-exit-confirmation',type=Path)
    a=p.parse_args()
    assert not a.output.exists()
    base=json.loads((EVAL/'SESSION_RESET_400.json').read_text())
    candidate=EVAL/'runs/repair404_candidate2'
    frozen=json.loads((candidate/'freeze.json').read_text())
    gate=json.loads((candidate/'validation/report.json').read_text())
    assert gate['passed'] and gate['provenance_unchanged']
    expected=frozen['candidate_policy_files']
    assert policy_hashes(ROOT)==policy_hashes(candidate/'policy')==expected==gate['policy_files']
    assert test_manifest()==frozen['test_files']==gate['test_files']
    assert provenance()==frozen['validation_provenance']==gate['validation_provenance']
    installed=Path(base['installed'])
    assert policy_hashes(installed.parent)==(expected if a.installed else base['policy_files'])
    natives={p.name:file_digest(p) for p in installed.glob('*.dll')}
    assert natives==base['native_files_preserved']
    capture=EVAL/'development403/capture/manifest.json'
    manifest=json.loads(capture.read_text())
    source=Path(manifest['source'])
    known={r['name']:r['sha256'] for r in manifest['segments']}
    current={p.name:file_digest(p) for p in source.glob('*.brj')}
    assert current==known,'Public journal inventory changed; preserve/analyze newer files before release'
    process=subprocess.run(['pwsh','-NoProfile','-Command',
       "@(Get-Process -Name Balatro -ErrorAction SilentlyContinue | Select-Object Id,ProcessName) | ConvertTo-Json -Compress"],
       capture_output=True,text=True,check=True,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    running=json.loads(process.stdout) if process.stdout.strip() else []
    assert not running,'Balatro is running; installation prohibited'
    confirmation=None
    if a.normal_exit_confirmation:
        confirmation=json.loads(a.normal_exit_confirmation.read_text())
        assert confirmation['confirmed'] is True and confirmation['public_session']==manifest['session']
    assert not a.installed or confirmation,'Installed verification requires current user confirmation receipt'
    report={'verified_utc':datetime.now(timezone.utc).isoformat(),
      'candidate_version':frozen['candidate_version'],'candidate_digest':digest(expected),
      'runtime_files':len(expected),'test_files':len(gate['test_files']),
      'candidate_gate_passed':True,'candidate_gate_sha256':file_digest(candidate/'validation/report.json'),
      'policy_tests_provenance_unchanged':True,'installed_matches':'candidate404' if a.installed else 'baseline400',
      'installed_config_sha256':file_digest(installed/'config.lua'),'native_files_preserved':natives,
      'public_files':current,'public_manifest_sha256':file_digest(capture),
      'game_processes':running,'normal_exit_confirmed':bool(confirmation),
      'normal_exit_confirmation_sha256':file_digest(a.normal_exit_confirmation) if confirmation else None,
      'normal_exit_note':'Explicit user confirmation bound separately; process absence alone is not normal-exit evidence.',
      'game_control':False,'save_or_profile_access':False,'new_experiment':False}
    a.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('candidate_digest','runtime_files','test_files','installed_matches','game_processes','normal_exit_confirmed')}))

if __name__=='__main__':main()
