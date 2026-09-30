"""Run only the explicitly named draft synthetic Gold-goal fixture."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

folder = Path(__file__).resolve().parent
root = folder.parents[2]
output = folder / sys.argv[1]
output.mkdir(exist_ok=False)
production = len(sys.argv) > 2 and sys.argv[2] == "production"
fixture = "tests/advisor_gold_goal.lua" if production else "tools/advisor_eval/development294/advisor_gold_goal.lua"
planner = "Brainstorm/Advisor/gold_goal.lua" if production else "tools/advisor_eval/development294/gold_goal.lua"
command = [sys.executable, "-B", "tests/run_lua_tests.py", fixture]
files = [fixture, planner, "Brainstorm/Advisor/strategy.lua",
         "Brainstorm/Advisor/shop_sequences.lua", "Brainstorm/Advisor/shop_scoring.lua", "Brainstorm/Advisor/liquidity.lua",
         "Brainstorm/Advisor/scoring.lua", "Brainstorm/Advisor/snapshot.lua"]
hashes = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
started = time.perf_counter()
try:
    result = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=60)
    code, stdout, stderr = result.returncode, result.stdout, result.stderr
except subprocess.TimeoutExpired as exc:
    code, stdout, stderr = 124, exc.stdout or b"", exc.stderr or b""
    stdout = stdout.decode(errors="replace") if isinstance(stdout, bytes) else stdout
    stderr = stderr.decode(errors="replace") if isinstance(stderr, bytes) else stderr
report = {"status": "passed" if code == 0 else "timeout" if code == 124 else "failed", "returncode": code,
          "seconds": time.perf_counter() - started, "timeout_seconds": 60, "command": command, "sha256": hashes,
          "scope": "Routine draft synthetic fixture only. No profile/game/save/source/captured/search/attempt operation."}
(output / "stdout.txt").write_text(stdout, encoding="utf-8")
(output / "stderr.txt").write_text(stderr, encoding="utf-8")
(output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2)); print(stdout); print(stderr)
raise SystemExit(code)
