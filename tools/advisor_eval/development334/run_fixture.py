from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[3]
folder = Path(__file__).resolve().parent
fixture = folder / (sys.argv[1] if len(sys.argv) > 1 else 'test_duplicates.lua')
if fixture.parent != folder or fixture.name not in {'test_duplicates.lua', 'compare_death.lua'}:
    raise ValueError('Only the two manufactured development fixtures are allowed')
started = time.monotonic()
command = [sys.executable, 'tests/run_lua_tests.py', str(fixture)]
try:
    result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60)
    record = {'kind': 'manufactured_lua_fixture', 'timeout_seconds': 60,
              'exit_code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
except subprocess.TimeoutExpired as error:
    record = {'kind': 'manufactured_lua_fixture', 'timeout_seconds': 60, 'timed_out': True,
              'stdout': str(error.stdout), 'stderr': str(error.stderr)}
record['wall_seconds'] = time.monotonic() - started
record['fixture_sha256'] = hashlib.sha256(fixture.read_bytes()).hexdigest()
record['runtime_sha256'] = hashlib.sha256((root / 'Brainstorm/Advisor/consumables.lua').read_bytes()).hexdigest()
if fixture.name == 'compare_death.lua':
    record['baseline_sha256'] = hashlib.sha256((folder / 'before/consumables.lua').read_bytes()).hexdigest()
prefix = 'comparison_receipt' if fixture.name == 'compare_death.lua' else 'fixture_receipt'
number = 1
while (folder / f'{prefix}{number}.json').exists():
    number += 1
destination = folder / f'{prefix}{number}.json'
destination.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(json.dumps(record, indent=2))
raise SystemExit(record.get('exit_code', 1))
