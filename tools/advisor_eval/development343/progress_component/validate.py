"""Bounded manufactured progress regressions; no original-source or live gameplay."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[4]
component = Path(__file__).resolve().parent
name = sys.argv[1]
if name not in ("before", "after"):
    raise SystemExit("Use before or after")
files = ["Brainstorm/Advisor/auto_run.lua", "Brainstorm/Core/auto_run_product.lua", "tests/advisor_auto_run.lua", "tests/advisor_auto_run_product.lua", "tests/advisor_auto_terminal.lua"]
receipt = {"kind": "manufactured_fixture_only", "source_execution": False, "live_game": False,
           "captured_replay": False, "timeout_seconds": 60,
           "files": {file: hashlib.sha256((root / file).read_bytes()).hexdigest() for file in files}}
command = [sys.executable, "tests/run_lua_tests.py", "tests/advisor_auto_run.lua", "tests/advisor_auto_run_product.lua", "tests/advisor_auto_terminal.lua"]
receipt["command"] = command
start = time.monotonic()
try:
    result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    receipt.update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
except subprocess.TimeoutExpired as error:
    receipt.update(exit_code=None, timeout=True, stdout=str(error.stdout or ""), stderr=str(error.stderr or ""))
receipt["duration_seconds"] = time.monotonic() - start
receipt["files_unchanged"] = all(hashlib.sha256((root / file).read_bytes()).hexdigest() == sha for file, sha in receipt["files"].items())
number = 1
path = component / (name + "_validation.json")
while path.exists():
    number += 1
    path = component / (name + "_validation_" + str(number) + ".json")
with path.open("x", encoding="utf-8") as output:
    json.dump(receipt, output, indent=2)
    output.write("\n")
print(json.dumps(receipt, indent=2))
raise SystemExit(receipt["exit_code"] if receipt["exit_code"] is not None else 1)
