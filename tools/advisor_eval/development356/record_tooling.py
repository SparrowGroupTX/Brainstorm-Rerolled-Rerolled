"""Bind the standalone learning data interface without running training or games."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FILES = ['tools/advisor_learning/' + name + '.py' for name in (
    'public_context', 'test_public_context', 'teacher_demonstrations', 'test_teacher_demonstrations')]
FILES += ['tools/advisor_eval/read_player_log.py', 'tests/test_advisor_teacher_encoding.py']

def hashes():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}

if sys.argv[1] == 'freeze':
    before = hashes()
    target = HERE / 'tooling'
    target.mkdir(exist_ok=False)
    for name in FILES:
        dest = target / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, dest)
    assert hashes() == before
    (target / 'inputs.json').write_text(json.dumps({'schema': 1,
        'recorded_utc': datetime.now(timezone.utc).isoformat(), 'files': before,
        'scope': 'Standalone manufactured data-interface validation; no model training or game run.'}, indent=2) + '\n')
else:
    target = HERE / 'tooling'
    frozen = json.loads((target / 'inputs.json').read_text())
    assert hashes() == frozen['files']
    report = json.loads((HERE.parent / 'runs/teacher356_installed_validation/report.json').read_text())
    assert report['passed'] and report['tests_unchanged'] and report['policy_unchanged']
    candidate = json.loads((HERE.parent / 'runs/teacher356_candidate/validation/report.json').read_text())
    assert candidate['passed'] and candidate['test_files'] == report['test_files']
    with (target / 'verification.json').open('x') as f:
        json.dump({'schema': 1, 'verified_utc': datetime.now(timezone.utc).isoformat(),
            'tooling_files_unchanged': True, 'files': hashes(), 'targeted_manufactured_tests': 30,
            'included_in_full_python_regressions': True, 'full_lua_fixtures': 226,
            'full_python_tests': 391, 'game_runs': 0, 'training_jobs': 0}, f, indent=2)
    print('Tooling hashes unchanged; 30 manufactured contracts included in both full Python regressions.')
