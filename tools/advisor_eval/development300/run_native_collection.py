"""Fresh bounded build/synthetic checks only. No seed search or game process."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
LABEL = sys.argv[1] if len(sys.argv) > 1 else "1"
if not LABEL.isalnum():
    raise SystemExit("A fresh alphanumeric build label is required")
OUT = ROOT / ("tools/advisor_eval/development300/native_collection_build" + LABEL)
BUILD = ROOT / ("Immolate/build-collection300-" + LABEL)
OUT.mkdir(parents=True, exist_ok=False)

def run(name, args, cap):
    started = time.perf_counter()
    try:
        done = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=cap)
        status, code, output = "complete", done.returncode, done.stdout + done.stderr
    except subprocess.TimeoutExpired as exc:
        status, code, output = "timeout", None, (exc.stdout or b"") + (exc.stderr or b"")
    path = OUT / (name + ".log")
    path.write_bytes(output)
    record = {"status": status, "exit_code": code, "command": args,
              "timeout_seconds": cap, "elapsed_seconds": time.perf_counter() - started,
              "log": {"path": path.relative_to(ROOT).as_posix(),
                      "sha256": hashlib.sha256(output).hexdigest()}}
    (OUT / (name + ".json")).write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record), flush=True)
    if code != 0:
        print(output.decode(errors="replace")[-6000:])
        raise SystemExit(1)

run("configure", ["cmake", "-S", "Immolate", "-B", str(BUILD), "-G", "MinGW Makefiles",
                  "-DCMAKE_BUILD_TYPE=Release", "-DBUILD_TESTING=ON"], 60)
run("build", ["cmake", "--build", str(BUILD), "--target", "Immolate",
              "brainstorm_collection_targets_regression", "-j", "8"], 300)
run("synthetic", [str(BUILD / "brainstorm_collection_targets_regression.exe")], 30)
