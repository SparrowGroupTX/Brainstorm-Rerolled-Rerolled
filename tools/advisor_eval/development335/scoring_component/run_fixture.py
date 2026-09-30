from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
fixture = HERE / 'test_scoring_reuse.lua'
started = time.monotonic()
command = [sys.executable, 'tests/run_lua_tests.py', str(fixture)]
try:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
    record = {'kind': 'manufactured_lua_fixture', 'timeout_seconds': 60,
              'exit_code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
except subprocess.TimeoutExpired as error:
    record = {'kind': 'manufactured_lua_fixture', 'timeout_seconds': 60, 'timed_out': True,
              'stdout': str(error.stdout), 'stderr': str(error.stderr)}
record['wall_seconds'] = time.monotonic() - started
record['sha256'] = {name: hashlib.sha256((HERE / name).read_bytes()).hexdigest()
                    for name in ('scoring_before.lua', 'scoring.lua', 'test_scoring_reuse.lua', 'run_fixture.py')}
number = 1
while (HERE / f'fixture_receipt{number}.json').exists():
    number += 1
with (HERE / f'fixture_receipt{number}.json').open('x', encoding='utf-8') as stream:
    json.dump(record, stream, indent=2)
    stream.write('\n')
print(json.dumps(record, indent=2))
raise SystemExit(record.get('exit_code', 1))
