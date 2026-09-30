"""Bounded manufactured objective fixtures; no captured replay or game execution."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[4]
component = Path(__file__).resolve().parent
runtime = ["Brainstorm/Advisor/gold_goal.lua", "Brainstorm/Advisor/perkeo_inventory.lua"]
fixtures = ["tests/advisor_gold_goal.lua", "tests/advisor_bell_opening.lua",
            "tests/advisor_perkeo_inventory.lua", "tests/advisor_gold_planet_policy.lua"]
round_number = 1
while (component / f"validation_{round_number:02d}_current.json").exists():
    round_number += 1

for fixture in fixtures:
    wrapper = component / ("before_" + Path(fixture).name)
    if not wrapper.exists():
        wrapper.write_text("local original=dofile\nlocal before='" + str(component.relative_to(root)).replace('\\', '/') + "/before/'\n"
                           "dofile=function(path)\n if path=='Brainstorm/Advisor/gold_goal.lua' or path=='Brainstorm/Advisor/perkeo_inventory.lua' then return original(before..path) end\n return original(path)\nend\n"
                           "original('" + fixture + "')\n", encoding="utf-8")

for mode in (["before", "current"] if round_number == 1 else ["current"]):
    paths = fixtures if mode == "current" else [str((component / ("before_" + Path(f).name)).relative_to(root)) for f in fixtures]
    command = [sys.executable, "tests/run_lua_tests.py", *paths]
    record = {"kind": "manufactured_fixtures", "source_execution": False, "captured_replay": False,
              "live_game": False, "max_seconds": 60, "command": command,
              "expected_failure": mode == "before",
              "inputs": {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in runtime + fixtures}}
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=60,
                                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        record.update(exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr)
    except subprocess.TimeoutExpired as error:
        record.update(exit_code=None, timeout=True, stdout=str(error.stdout or ''), stderr=str(error.stderr or ''))
    record["seconds"] = time.monotonic() - start
    record["inputs_unchanged"] = all(hashlib.sha256((root / path).read_bytes()).hexdigest() == expected for path, expected in record["inputs"].items())
    receipt = component / f"validation_{round_number:02d}_{mode}.json"
    with receipt.open("x", encoding="utf-8") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print(mode, record.get("exit_code"), record["stdout"], record["stderr"])
    if mode == "current" and (record.get("exit_code") != 0 or not record["inputs_unchanged"]):
        raise SystemExit(1)
