"""Bounded ordinary synthetic UI fixture; never executes original game source."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[3]
label = sys.argv[1]
if not label.isalnum():
    raise ValueError("Use a fresh alphanumeric receipt name")
baseline = len(sys.argv) > 2 and sys.argv[2] == "296"
out = Path(__file__).resolve().parent / label
out.mkdir(exist_ok=False)
env = os.environ.copy()
env.pop("ADVISOR_GOLD_LAYOUT_BASELINE", None)
if baseline:
    env["ADVISOR_GOLD_LAYOUT_BASELINE"] = "296"
files = ["tests/advisor_gold_layout.lua", "Brainstorm/Advisor/gold_search.lua", "Brainstorm/Advisor/gold_stickers.lua",
         "tools/advisor_eval/runs/search296_candidate/policy/Brainstorm/UI/advisor.lua" if baseline else "Brainstorm/UI/advisor.lua"]
sha = lambda name: hashlib.sha256((root / name).read_bytes()).hexdigest()
hashes = {name: sha(name) for name in files}
command = [sys.executable, "-B", "tests/run_lua_tests.py", "tests/advisor_gold_layout.lua"]
started = time.perf_counter()
try:
    result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=60)
    code, stdout, stderr = result.returncode, result.stdout, result.stderr
except subprocess.TimeoutExpired as exc:
    code, stdout, stderr = None, exc.stdout or b"", exc.stderr or b""
elapsed = time.perf_counter() - started
stdout = stdout.decode(errors="replace") if isinstance(stdout, bytes) else stdout
stderr = stderr.decode(errors="replace") if isinstance(stderr, bytes) else stderr
unchanged = all(sha(name) == digest for name, digest in hashes.items())
report = {"status": "passed" if code == 0 and unchanged else "failed", "returncode": code,
          "seconds": elapsed, "timeout_seconds": 60, "baseline296": baseline,
          "sha256": hashes, "files_unchanged": unchanged, "command": command,
          "scope": "Routine synthetic product UI geometry fixture only; no live rendering, original-source execution, search, attempts, game control, saves or profiles."}
(out / "stdout.txt").write_text(stdout, encoding="utf-8")
(out / "stderr.txt").write_text(stderr, encoding="utf-8")
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2))
print(stdout)
print(stderr)
raise SystemExit(0 if report["status"] == "passed" else code or 124)
