"""Record routine fixture validation and detached integration provenance."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import sys
import time

PACKAGE = Path(__file__).resolve().parent
ROOT = PACKAGE.parents[3]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    fixtures = [str((PACKAGE / 'run_candidate.lua').relative_to(ROOT)),
                str((PACKAGE / 'run_existing.lua').relative_to(ROOT)), 'tests/advisor_bell_opening.lua']
    command = [sys.executable, 'tests/run_lua_tests.py', *fixtures]
    start = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    (PACKAGE / 'focused_output.txt').write_text(output, encoding='utf-8')
    report = {'schema': 1, 'status': 'passed' if result.returncode == 0 else 'failed',
              'kind': 'manufactured_fixture_validation_only', 'source_experiment': False,
              'captured_state_replay': False, 'complete_attempt': False,
              'timestamp_utc': datetime.now(timezone.utc).isoformat(), 'elapsed_seconds': time.monotonic() - start,
              'command': command, 'exit_code': result.returncode, 'fixtures': fixtures,
              'output_sha256': digest(PACKAGE / 'focused_output.txt')}
    (PACKAGE / 'focused_report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    if result.returncode:
        print(output)
        raise SystemExit(result.returncode)
    dependencies = ['Brainstorm/Advisor/bell_opening.lua', 'Brainstorm/Advisor/scoring.lua',
                    'Brainstorm/Advisor/strategy.lua', 'Brainstorm/Advisor/shop_scoring.lua',
                    'Brainstorm/Advisor/finish_rewards.lua', 'Brainstorm/Advisor/snapshot.lua',
                    'Brainstorm/Advisor/decision.lua', 'Brainstorm/Advisor/runtime.lua',
                    'tests/advisor_blind_routing.lua', 'tests/advisor_bell_opening.lua', 'tests/run_lua_tests.py']
    manifest = {'schema': 1, 'kind': 'detached_bell_routing322_integration', 'status': 'ready_for_independent_review',
                'runtime_changed': False, 'source_experiments': False,
                'integration': [
                    {'source': 'blind_routing.lua', 'target': 'Brainstorm/Advisor/blind_routing.lua',
                     'base_sha256': digest(PACKAGE / 'blind_routing.base.lua'), 'sha256': digest(PACKAGE / 'blind_routing.lua')},
                    {'source': 'test_advisor_bell_routing.lua', 'target': 'tests/advisor_bell_routing.lua',
                     'base_sha256': None, 'sha256': digest(PACKAGE / 'test_advisor_bell_routing.lua')}],
                'dependencies': [{'path': str(path), 'sha256': digest(ROOT / path)} for path in dependencies],
                'validation': {'report': 'focused_report.json', 'sha256': digest(PACKAGE / 'focused_report.json')},
                'package_files': [{'path': path.name, 'sha256': digest(path)} for path in sorted(PACKAGE.iterdir())
                                  if path.is_file() and path.name != 'manifest.json']}
    (PACKAGE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(output)
    print(json.dumps({'status': 'ready_for_independent_review', 'manifest_sha256': digest(PACKAGE / 'manifest.json'),
                      'runtime_sha256': digest(PACKAGE / 'blind_routing.lua'),
                      'fixture_sha256': digest(PACKAGE / 'test_advisor_bell_routing.lua')}))


if __name__ == '__main__':
    main()
