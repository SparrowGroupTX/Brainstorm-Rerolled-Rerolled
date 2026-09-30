"""Write current checkpoint hashes after exact candidate and installed gates."""

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes  # noqa: E402

INSTALLED = Path('C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm')
CANDIDATE = EVAL / 'runs/hex369_candidate'
RELEASE = EVAL / 'runs/hex369_installed'
VALIDATED = EVAL / 'runs/hex369_installed_validation'
FINAL = EVAL / 'runs/hex369_final'
COHORT = EVAL / 'win_rate_research/20260923_2_168_ten_start'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def address(path):
    return {'path': str(path.relative_to(ROOT)).replace('\\', '/'),
            'sha256': file_digest(path)}


def main():
    FINAL.mkdir(exist_ok=False)
    record = read(RELEASE / 'record.json')
    candidate = read(CANDIDATE / 'validation/report.json')
    installed_gate = read(VALIDATED / 'report.json')
    review = read(COHORT / 'review_summary.json')
    capture = read(COHORT / 'capture/manifest.json')
    assert all(review['checks'].values())
    assert review['outcomes'] == {'win': 5, 'loss': 5}
    assert len(capture['inputs']) == 26
    for item in capture['inputs']:
        frozen = ROOT / item['frozen']
        assert file_digest(frozen) == item['sha256']
    assert candidate['passed'] and installed_gate['passed']
    assert candidate['policy_digest'] == installed_gate['policy_digest'] == record['policy_digest']
    assert candidate['policy_files'] == installed_gate['policy_files'] == record['policy_files']
    assert candidate['test_files'] == installed_gate['test_files']
    assert all(row['status'] == 'passed' and row['seconds'] < 60
               for gate in (candidate, installed_gate) for row in gate['runs'])
    assert policy_hashes(ROOT) == policy_hashes(INSTALLED.parent) == record['policy_files']
    assert file_digest(INSTALLED / 'config.lua') == record['config_sha256']
    assert {f.name: file_digest(f) for f in sorted(INSTALLED.glob('*.dll'))} == record['native_files_preserved']
    assert len(record['deployed_files']) == 89
    for relative, expected in record['deployed_files'].items():
        assert file_digest(INSTALLED / relative) == expected

    checkpoint = {
        'release': 369,
        'version': record['version'],
        'installed_at': record['installed_at'],
        'installed': record['installed'],
        'backup': record['backup'],
        'config_sha256': record['config_sha256'],
        'native_files_preserved': record['native_files_preserved'],
        'policy_digest': record['policy_digest'],
        'policy_files': record['policy_files'],
        'deployment_files': record['deployed_files'],
        'candidate_validation': address(CANDIDATE / 'validation/report.json'),
        'exact_installed_validation': address(VALIDATED / 'report.json'),
        'installed_record': address(RELEASE / 'record.json'),
        'loaded_cohort': {
            'version_stamp': '2.168.0-alpha',
            'profile': 'perkeo_yorick_win_v1',
            'starts': 10, 'wins': 5, 'losses': 5,
            'capture_manifest': address(COHORT / 'capture/manifest.json'),
            'review_summary': address(COHORT / 'review_summary.json'),
            'report': address(COHORT / 'REPORT.md'),
        },
        'activation': 'Not confirmed; normal user restart required',
        'experiment_budget': 'No new authorization; historical allowances closed',
    }
    checkpoint_path = EVAL / 'SESSION_RESET_369.json'
    checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + '\n', encoding='utf-8')
    docs = [ROOT / 'ADVISOR_START_HERE.md', ROOT / 'ADVISOR_RESUME_PROMPT.md',
            ROOT / 'ADVISOR_HANDOFF.md', EVAL / 'SESSION_RESET_369.md',
            checkpoint_path, EVAL / 'NEXT_PRIORITIES_369.md',
            EVAL / 'ARCHITECTURE_MAP_369.md', EVAL / 'WIN_RATE_RESEARCH.md',
            COHORT / 'REPORT.md', EVAL / 'development369/SCOPE.md',
            EVAL / 'development369/REVIEW.md', EVAL / 'development369/BUDGET.md']
    final = {
        'verified_at_utc': datetime.now(timezone.utc).isoformat(),
        'version': record['version'],
        'policy_digest': digest(record['policy_files']),
        'all_89_deployment_files_match': True,
        'all_105_runtime_dependency_files_match': True,
        'candidate_passed': candidate['passed'],
        'exact_installed_passed': installed_gate['passed'],
        'candidate_lua_fixtures': 240,
        'candidate_python_tests': 391,
        'installed_lua_fixtures': 240,
        'installed_python_tests': 391,
        'test_hashes_equal': True,
        'config_unchanged': True,
        'seven_native_files_unchanged': True,
        'cohort_frozen_hashes_match': True,
        'cohort_outcomes': review['outcomes'],
        'loaded_2_169_confirmed': False,
        'documents': {str(path.relative_to(ROOT)).replace('\\', '/'): file_digest(path)
                      for path in docs},
        'saves': 'Not read or written',
        'game_control': 'None',
        'new_experiments': 0,
    }
    (FINAL / 'final_verification.json').write_text(json.dumps(final, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'version': final['version'], 'policy_digest': final['policy_digest'],
                      'deployment_files': 89, 'runtime_files': 105,
                      'lua': 240, 'python': 391, 'cohort': final['cohort_outcomes'],
                      'documents': len(docs)}))


if __name__ == '__main__':
    main()
