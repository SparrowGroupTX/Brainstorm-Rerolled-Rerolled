"""Routine manufactured fixtures only; keep receipts, including failures."""
from pathlib import Path
import json, subprocess, sys, time

root = Path(__file__).resolve().parents[4]
here = Path(__file__).resolve().parent
mode = sys.argv[1]
if mode == 'baseline':
    target = here / 'baseline_fixture.lua'
    text = (root / 'tests/advisor_growth_copy359.lua').read_text()
    text = text.replace("dofile('Brainstorm/Advisor/growth.lua')", "dofile('tools/advisor_eval/development359/growth_review/before/growth.lua')")
    with target.open('x') as f: f.write(text)
    fixtures = [str(target)]
else:
    fixtures = sys.argv[2:]
started = time.time()
result = subprocess.run([sys.executable, 'tests/run_lua_tests.py', *fixtures], cwd=root, capture_output=True, text=True, timeout=60)
report = {'scope': 'manufactured regression only', 'started_unix': started,
          'seconds': time.time() - started, 'fixtures': fixtures,
          'returncode': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
with (here / (mode + '.json')).open('x') as f: json.dump(report, f, indent=2)
print(result.stdout, end=''); print(result.stderr, end='', file=sys.stderr)
sys.exit(result.returncode)
