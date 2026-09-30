"""Bounded synthetic Gold metadata fixture; no game/profile/source execution."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[3]
label = sys.argv[1]
if not label.isalnum():
    raise ValueError("Use a fresh alphanumeric receipt label")
out = Path(__file__).resolve().parent / label
out.mkdir(exist_ok=False)
files = [
    root / "Brainstorm/Advisor/gold_stickers.lua",
    root / "Brainstorm/Advisor/snapshot.lua",
    root / "tests/advisor_gold_stickers.lua",
    root / "tests/run_lua_tests.py",
    Path(__file__).resolve(),
]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
before = {str(p.relative_to(root)): sha(p) for p in files}
cmd = [sys.executable, "-B", "tests/run_lua_tests.py", "tests/advisor_gold_stickers.lua"]
started = time.perf_counter()
try:
    result = subprocess.run(cmd, cwd=root, capture_output=True, text=True, timeout=60)
    code, stdout, stderr = result.returncode, result.stdout, result.stderr
except subprocess.TimeoutExpired as exc:
    code, stdout, stderr = None, exc.stdout or b"", exc.stderr or b""
elapsed = time.perf_counter() - started
stdout = stdout.decode(errors="replace") if isinstance(stdout, bytes) else stdout
stderr = stderr.decode(errors="replace") if isinstance(stderr, bytes) else stderr
after = {str(p.relative_to(root)): sha(p) for p in files}
status = "passed" if code == 0 and before == after else "timeout" if code is None else "failed"
report = {
    "status": status, "returncode": code, "seconds": elapsed, "timeout_seconds": 60,
    "command": cmd, "sha256": before, "after_sha256": after,
    "files_unchanged": before == after,
    "scope": "One ordinary synthetic fixture; no original-source component, replay, search, terminal attempt, game process or player profile/save read.",
}
(out / "stdout.txt").write_text(stdout, encoding="utf-8")
(out / "stderr.txt").write_text(stderr, encoding="utf-8")
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
print(stdout)
print(stderr)
raise SystemExit(0 if status == "passed" else code or 124)
