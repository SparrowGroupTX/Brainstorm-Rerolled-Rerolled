"""Bounded manufactured learning-tool tests; no gameplay or model training."""
import datetime as dt
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
command = [sys.executable, '-B', '-m', 'unittest', 'discover', '-s',
           'tools/advisor_learning', '-t', '.', '-p', 'test_*.py', '-v']
started = time.monotonic()
try:
    run = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=60,
                         creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    output, code = run.stdout + run.stderr, run.returncode
except subprocess.TimeoutExpired as error:
    output, code = repr(error), -1
(HERE / 'manufactured_tests.log').write_text(output, encoding='utf-8')
receipt = {'finished_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
           'command': command, 'returncode': code, 'cap_seconds': 60,
           'elapsed_seconds': time.monotonic() - started,
           'scope': 'Manufactured fixtures only; no simulator episodes, training or GPU benchmarks.',
           'output_sha256': hashlib.sha256(output.encode()).hexdigest()}
(HERE / 'test_receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(output[-3500:])
print(json.dumps(receipt, indent=2))
raise SystemExit(code)
