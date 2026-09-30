"""Record detached snapshot candidate and manufactured fixture provenance."""
from __future__ import annotations
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    command = [sys.executable, 'tests/run_lua_tests.py',
               str((HERE / 'run_candidate.lua').relative_to(ROOT)), str((HERE / 'run_existing.lua').relative_to(ROOT))]
    begin = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    (HERE / 'focused_output.txt').write_text(result.stdout + result.stderr, encoding='utf-8')
    dump(HERE / 'focused_report.json', {'schema': 1, 'kind': 'manufactured_and_existing_fixture_validation_only',
        'status': 'passed' if result.returncode == 0 else 'failed', 'exit_code': result.returncode,
        'new_checks': 52, 'existing_checks': 536, 'total_checks': 588,
        'command': command, 'elapsed_seconds': time.monotonic() - begin,
        'timestamp_utc': datetime.now(timezone.utc).isoformat(), 'output_sha256': sha(HERE / 'focused_output.txt'),
        'source_execution': False, 'captured_replay': False, 'complete_attempt': False})
    if result.returncode:
        print(result.stdout + result.stderr)
        raise SystemExit(result.returncode)
    preserved = ROOT / 'tools/advisor_eval/runs/planet_pool_source1/source/functions/common_events.lua'
    deps = ['Brainstorm/Advisor/gold_stickers.lua', 'Brainstorm/Advisor/perkeo_inventory.lua',
            'tests/advisor_snapshot.lua', 'tests/advisor_gold_stickers.lua', 'tests/advisor_perkeo_inventory.lua', 'tests/run_lua_tests.py']
    manifest = {'schema': 1, 'kind': 'detached_snapshot_idle323_integration', 'status': 'ready_for_independent_review',
        'runtime_changed': False, 'source_experiments': False,
        'integration': [
            {'source': 'snapshot.lua', 'target': 'Brainstorm/Advisor/snapshot.lua',
             'base_sha256': sha(HERE / 'snapshot.base.lua'), 'sha256': sha(HERE / 'snapshot.lua')},
            {'source': 'test_advisor_snapshot_idle.lua', 'target': 'tests/advisor_snapshot_idle.lua',
             'base_sha256': None, 'sha256': sha(HERE / 'test_advisor_snapshot_idle.lua')}],
        'dependencies': [{'path': path, 'sha256': sha(ROOT / path)} for path in deps],
        'preserved_source': {'path': preserved.relative_to(ROOT).as_posix(), 'sha256': sha(preserved),
                             'function': 'update_hand_text', 'start_line': 495, 'execution': False},
        'validation': {'path': 'focused_report.json', 'sha256': sha(HERE / 'focused_report.json')},
        'package_files': [{'path': path.name, 'sha256': sha(path)} for path in sorted(HERE.iterdir())
                          if path.is_file() and path.name != 'manifest.json']}
    dump(HERE / 'manifest.json', manifest)
    print(result.stdout + result.stderr)
    print(json.dumps({'manifest_sha256': sha(HERE / 'manifest.json'), 'runtime_sha256': sha(HERE / 'snapshot.lua'),
                      'fixture_sha256': sha(HERE / 'test_advisor_snapshot_idle.lua')}))


if __name__ == '__main__':
    main()
