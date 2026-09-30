"""Manufactured Lua fixture receipts; no live game or original-source execution."""
from pathlib import Path
import json
import hashlib
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[4]
stage = Path(__file__).resolve().parent
run = 1
while (stage / f"validation_{run:02d}_evidence.json").exists():
    run += 1
sources = {
    "tools/advisor_eval/runs/chicot_order_source1/source/card.lua": {
        "ranges": [[4113, 4142]], "purpose": "Flip sets direction; update changes rendered sprite and clears pinch without clearing direction"},
    "tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua": {
        "ranges": [[779, 785], [875, 917]], "purpose": "Final public attention_text fields after focus redirection"},
}
for path, evidence in sources.items():
    evidence["sha256"] = hashlib.sha256((root / path).read_bytes()).hexdigest()
evidence = {"kind": "read_only_preserved_source_binding", "sources": sources,
            "source_execution": False, "archive_read": False,
            "staged_files": {str(path.relative_to(stage)): hashlib.sha256(path.read_bytes()).hexdigest()
                             for folder in ("Brainstorm", "tests") for path in (stage / folder).rglob("*.lua")}}
with (stage / f"validation_{run:02d}_evidence.json").open("x", encoding="utf-8") as output:
    json.dump(evidence, output, indent=2)
    output.write("\n")
for name in ("before", "staged"):
    command = [sys.executable, "tests/run_lua_tests.py", str((stage / f"run_{name}.lua").relative_to(root))]
    start = time.monotonic()
    receipt = {"kind": "manufactured_fixture_only", "command": command,
               "source_execution": False, "live_game": False, "captured_replay": False}
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        receipt.update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
    except subprocess.TimeoutExpired as error:
        receipt.update(exit_code=None, timeout=True, stdout=str(error.stdout or ""), stderr=str(error.stderr or ""))
    receipt["duration_seconds"] = time.monotonic() - start
    with (stage / f"validation_{run:02d}_{name}.json").open("x", encoding="utf-8") as output:
        json.dump(receipt, output, indent=2)
        output.write("\n")
    print(name, receipt["exit_code"], receipt["stdout"], receipt["stderr"])
    if receipt.get("timeout") or name == "staged" and receipt["exit_code"]:
        raise SystemExit(receipt["exit_code"] or 1)
