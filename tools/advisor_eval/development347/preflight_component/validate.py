"""Bounded manufactured fixture validation; no captured or source execution."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
STAGED = HERE / 'Brainstorm/Advisor/shop_scoring.lua'
FIXTURE = HERE / 'tests/advisor_shop_family_preflight.lua'
iteration = sys.argv[1] if len(sys.argv) > 1 else '01'
assert iteration.isdigit()
WRAPPER = HERE / ('run_' + iteration + '.lua')
assert not WRAPPER.exists()
WRAPPER.write_text(
    "local original=dofile\n"
    "dofile=function(path)\n"
    "  if path=='Brainstorm/Advisor/shop_scoring.lua' then return original('"
    + STAGED.relative_to(ROOT).as_posix() + "') end\n"
    "  return original(path)\nend\n"
    "dofile('" + FIXTURE.relative_to(ROOT).as_posix() + "')\n",
    encoding='utf-8')
paths = [STAGED, FIXTURE, WRAPPER, ROOT / 'Brainstorm/Advisor/snapshot.lua',
    ROOT / 'tests/run_lua_tests.py']
def hashes():
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
before = hashes()
command = [sys.executable, 'tests/run_lua_tests.py', str(WRAPPER.relative_to(ROOT))]
started = time.monotonic()
try:
    proc = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60,
        creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0)
    result = {'exit_code': proc.returncode, 'stdout': proc.stdout, 'stderr': proc.stderr,
        'status': 'passed' if proc.returncode == 0 else 'failed'}
except subprocess.TimeoutExpired as exc:
    result = {'status': 'timeout', 'exit_code': None,
        'stdout': (exc.stdout or b'').decode('utf-8', 'replace') if isinstance(exc.stdout, bytes) else exc.stdout,
        'stderr': (exc.stderr or b'').decode('utf-8', 'replace') if isinstance(exc.stderr, bytes) else exc.stderr}
result.update({'schema': 1, 'scope': 'Manufactured preflight cost/accounting fixtures only. No captured policy, original-source component, search or full attempt.',
    'command': command, 'cap_seconds': 60, 'seconds': time.monotonic()-started,
    'input_hashes': before, 'input_hashes_after': hashes(), 'inputs_unchanged': before == hashes()})
out = HERE / ('validation_' + iteration + '.json')
with out.open('x', encoding='utf-8') as handle:
    json.dump(result, handle, indent=2)
    handle.write('\n')
print(json.dumps(result))
