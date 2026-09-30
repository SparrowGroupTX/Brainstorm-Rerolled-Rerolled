"""Final406 preservation/provenance receipt; read-only except new receipt file."""
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(EVAL))
from benchmark import file_digest, policy_hashes
from validate_checkpoint import test_manifest, provenance


def main():
    output = OUT/'final_verification.json'
    assert not output.exists()
    pre = json.loads((OUT/'prework.json').read_text())
    checkpoint = json.loads((EVAL/'SESSION_RESET_404.json').read_text())
    installed = Path(checkpoint['installed'])
    assert policy_hashes(ROOT) == policy_hashes(installed.parent) == pre['runtime_files'] == checkpoint['policy_files']
    frozen = json.loads((OUT/'validation/manifest.json').read_text())
    gate = json.loads((OUT/'validation/report.json').read_text())
    assert gate['passed'] and gate['total_python_tests'] == 452
    assert test_manifest() == frozen['test_files'] and provenance() == frozen['provenance']
    for name, digest in frozen['changed_source_files'].items():
        assert file_digest(ROOT/name) == digest == file_digest(OUT/'validation/sources'/name)
    for name, digest in pre['native_repository'].items():
        assert file_digest(ROOT/name) == digest
    for name, digest in pre['native_installed'].items():
        assert file_digest(Path(name)) == digest
    for name, digest in pre['before_files'].items():
        assert file_digest(OUT/'before'/name) == digest
        if name != 'tools/advisor_eval/README.md':
            assert (ROOT/name).read_bytes().endswith((OUT/'before'/name).read_bytes())
    earlier_count = 0
    for number in (403, 405):
        earlier_path = EVAL/f'development{number}/final_verification.json'
        assert file_digest(earlier_path) == pre[f'prior{number}_verification_sha256']
        earlier = json.loads(earlier_path.read_text())
        for name, digest in earlier['artifact_hashes'].items():
            if name not in pre['before_files']:
                assert file_digest(ROOT/name) == digest, name
                earlier_count += 1
    old_tests = json.loads((EVAL/'development405/validation/manifest.json').read_text())['test_files']
    assert all(frozen['test_files'][k] == v for k, v in old_tests.items())
    capture = json.loads((EVAL/'development403/capture/manifest.json').read_text())
    for entry in capture['segments']:
        p = EVAL/'development403/logs1'/entry['name']
        assert p.stat().st_size == entry['bytes'] and file_digest(p) == entry['sha256']
    demo = json.loads((OUT/'historical403_final/report.json').read_text())
    assert demo['screener_sha256'] == frozen['changed_source_files']['tools/advisor_eval/flag_suspect_decisions.py']
    assert demo['events'] == 24223 and demo['flags_total'] == 304
    assert any(f['rule'] == 'sale_plan_reversal' and f['anchors']['request']['sequence'] == 19922 for f in demo['flags'])
    docs = [ROOT/k for k in pre['before_files']]
    docs += [EVAL/'SUSPECT_DECISION_SCREEN_406.md', EVAL/'TOOLING_CHECKPOINT_406.md']
    artifacts = [p for p in OUT.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    artifacts += docs + [ROOT/p for p in frozen['changed_source_files']]
    processes = subprocess.run(['powershell', '-NoProfile', '-Command',
        '@(Get-Process -Name Balatro -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id) | ConvertTo-Json -Compress'],
        capture_output=True, text=True, timeout=10, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    result = {'verified_utc': datetime.now(timezone.utc).isoformat(), 'status': 'complete_tooling_only',
        'runtime_version': checkpoint['version'], 'runtime_digest': checkpoint['policy_digest'],
        'runtime_files_per_tree': len(pre['runtime_files']), 'native_files_per_tree': len(pre['native_repository']),
        'python_tests_passed': gate['total_python_tests'], 'new_manufactured_tests': 39,
        'frozen_test_files': len(frozen['test_files']), 'prior313_test_files_unchanged': True,
        'tooling_and_provenance_match_gate': True, 'historical403_segments_unchanged': len(capture['segments']),
        'earlier_recorded_artifacts_verified': earlier_count,
        'historical_flags': demo['flags_by_rule'], 'historical_groups': len(demo['review_groups']),
        'historical_screen_is_not_new_gameplay': True,
        'passive_game_process_ids': json.loads(processes.stdout) if processes.stdout.strip() else None,
        'active_journals_read': False, 'game_control': False, 'save_or_profile_access': False,
        'captured_policy_or_scorer_replay': False, 'new_experiment_or_automation': False,
        'runtime_installation_or_config_writes': False, 'current_loaded_label': None, 'current_session_outcomes': None,
        'artifact_hashes': {p.relative_to(ROOT).as_posix(): file_digest(p) for p in sorted(set(artifacts))}}
    output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'artifact_hashes'}))


if __name__ == '__main__':
    main()
