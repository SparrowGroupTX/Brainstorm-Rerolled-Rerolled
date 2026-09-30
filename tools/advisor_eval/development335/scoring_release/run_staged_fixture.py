"""Validate the production-shaped fixture in a fresh manufactured-only tree."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
COMPONENT = HERE.parent / 'scoring_component'
number = 1
while (HERE / f'standalone_validation{number}').exists():
    number += 1
stage = HERE / f'standalone_validation{number}'
stage.mkdir(exist_ok=False)
inputs = {
    'tests/advisor_scoring_work336.lua': HERE / 'advisor_scoring_reuse.lua',
    'tests/fixtures/advisor_scoring_reuse336/scoring_before.lua': COMPONENT / 'scoring_before.lua',
    'Brainstorm/Advisor/scoring.lua': COMPONENT / 'scoring.lua',
    'Brainstorm/Advisor/score_cache.lua': ROOT / 'Brainstorm/Advisor/score_cache.lua',
    'Brainstorm/Advisor/snapshot.lua': ROOT / 'Brainstorm/Advisor/snapshot.lua',
    'tests/run_lua_tests.py': ROOT / 'tests/run_lua_tests.py',
}
hashes = {}
for relative, source in inputs.items():
    target = stage / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    data = source.read_bytes()
    with target.open('xb') as stream:
        stream.write(data)
    hashes[relative] = hashlib.sha256(data).hexdigest()
started = time.monotonic()
command = [sys.executable, str(stage / 'tests/run_lua_tests.py'), 'tests/advisor_scoring_work336.lua']
try:
    result = subprocess.run(command, cwd=stage, capture_output=True, text=True, timeout=60)
    record = {'exit_code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
except subprocess.TimeoutExpired as error:
    record = {'timed_out': True, 'stdout': str(error.stdout), 'stderr': str(error.stderr)}
record.update(kind='manufactured_production_shaped_fixture', timeout_seconds=60,
              wall_seconds=time.monotonic()-started, files=hashes)
with (stage / 'receipt.json').open('x', encoding='utf-8') as stream:
    json.dump(record, stream, indent=2)
    stream.write('\n')
print(json.dumps(record, indent=2))
raise SystemExit(record.get('exit_code', 1))
