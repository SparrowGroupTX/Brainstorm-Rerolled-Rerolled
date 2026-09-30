import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
fixtures = [OUT / 'test_journal_work.lua']
for name in ['advisor_player_journal', 'advisor_player_journal_timing', 'advisor_logger_hooks', 'advisor_callback_hooks']:
    wrapper = OUT / f'run_{name}.lua'
    body = """local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/player_journal.lua' then
    return original('tools/advisor_eval/development335/runtime_component/player_journal.lua')
  end
  return original(path)
end
original('tests/%s.lua')
""" % name
    if wrapper.exists():
        assert wrapper.read_text(encoding='utf-8') == body, f'Unexpected existing wrapper {wrapper}'
    else:
        wrapper.write_text(body, encoding='utf-8', newline='\n')
    fixtures.append(wrapper)
command = [sys.executable, 'tests/run_lua_tests.py', *[str(path.relative_to(ROOT)) for path in fixtures]]
started = time.monotonic()
result = subprocess.run(command, cwd=ROOT, timeout=60, capture_output=True, text=True)
receipt = {
    'kind': 'manufactured_journal_short_circuit_regression',
    'timeout_seconds': 60,
    'elapsed_seconds': time.monotonic() - started,
    'returncode': result.returncode,
    'stdout': result.stdout,
    'stderr': result.stderr,
    'sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
               for path in [OUT / 'player_journal.base.lua', OUT / 'player_journal.lua', *fixtures]},
    'scope': 'Detached manufactured Lua data and frozen existing fixtures only; no game control, saves, profiles or logs read.',
}
receipt_path = OUT / 'validation.json'
assert not receipt_path.exists(), 'Preserve existing validation receipt'
receipt_path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(result.stdout, end='')
print(result.stderr, end='', file=sys.stderr)
raise SystemExit(result.returncode)
