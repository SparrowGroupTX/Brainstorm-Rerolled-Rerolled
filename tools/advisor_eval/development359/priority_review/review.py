"""Manufactured fixtures only; preserve baseline failure and narrow validation."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name, fixtures):
    command = [sys.executable, 'tests/run_lua_tests.py', *fixtures]
    started = time.monotonic()
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                            timeout=60, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    (HERE / (name + '.log')).write_text(result.stdout + '\n' + result.stderr, encoding='utf-8')
    return {'command': command, 'exit_code': result.returncode,
            'seconds': time.monotonic() - started, 'log': name + '.log'}


files = ['tests/advisor_growth_priority359.lua', 'Brainstorm/Advisor/decision.lua',
         'Brainstorm/Advisor/growth.lua', 'Brainstorm/Advisor/consumables.lua',
         'Brainstorm/Advisor/scoring.lua', 'Brainstorm/Advisor/strategy.lua',
         'Brainstorm/Advisor/search.lua']
before = {path: sha(ROOT / path) for path in files}
baseline = run('baseline_final_fixture', ['tools/advisor_eval/development359/priority_review/baseline_wrapper.lua'])
validation = run('validation', ['tests/advisor_growth_priority359.lua', 'tests/advisor_growth.lua',
                              'tests/advisor_decision_budget.lua', 'tests/advisor_surplus_development358.lua'])
after = {path: sha(ROOT / path) for path in files}
record = {'created_utc': datetime.now(timezone.utc).isoformat(),
          'scope': 'Manufactured fixtures only. No captured-state policy evaluation, source component, search, complete attempt, live gameplay, saves or profiles.',
          'baseline_decision_sha256': sha(HERE / 'decision.before.lua'),
          'before': before, 'after': after, 'files_unchanged': before == after,
          'baseline': baseline, 'validation': validation,
          'passed': before == after and baseline['exit_code'] == 1 and validation['exit_code'] == 0,
          'terminal_outcome_evidence': False}
(HERE / 'evidence.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps(record))
