"""Routine synthetic fixtures only, with a fresh output directory and 60s cap."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

folder = Path(__file__).resolve().parent
root = folder.parents[2]
out = folder / sys.argv[1]
out.mkdir(exist_ok=False)
fixtures = sys.argv[2:] or ['tests/advisor_owned_fool_shop.lua']
command = [sys.executable, 'tests/run_lua_tests.py', *fixtures]
names = ['Brainstorm/Advisor/pack_scoring.lua', 'Brainstorm/Advisor/shop_sequences.lua', *fixtures]
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in names}
started = time.perf_counter()
try:
    result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60)
    code, stdout, stderr = result.returncode, result.stdout, result.stderr
    status = 'passed' if code == 0 else 'failed'
except subprocess.TimeoutExpired as exc:
    code, stdout, stderr, status = None, exc.stdout or b'', exc.stderr or b'', 'timeout'
    stdout = stdout.decode(errors='replace') if isinstance(stdout, bytes) else stdout
    stderr = stderr.decode(errors='replace') if isinstance(stderr, bytes) else stderr
elapsed = time.perf_counter() - started
(out / 'stdout.txt').write_text(stdout, encoding='utf-8')
(out / 'stderr.txt').write_text(stderr, encoding='utf-8')
report = dict(status=status, returncode=code, seconds=elapsed, timeout_seconds=60, command=command, sha256=hashes,
              scope='Routine synthetic fixtures only; no source/captured replay/search/attempt/game/save operation.')
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2)); print(stdout); print(stderr)
raise SystemExit(code if code is not None else 124)
