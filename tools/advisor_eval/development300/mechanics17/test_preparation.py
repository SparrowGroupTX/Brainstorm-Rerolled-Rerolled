"""Read-only evidence and harness scope checks; never executes source/native code."""
from pathlib import Path
import ast
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE / "adapter"))
from startup_receipt import load_observed_receipt

def main():
    checks = 0
    def check(value):
        nonlocal checks
        checks += 1
        assert value
    for folder in (HERE, HERE / "adapter"):
        for path in folder.glob("*.py"):
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            checks += 1
    original = json.loads((HERE / "parent_evidence_hashes.json").read_text(encoding="utf-8"))
    for name, expected in original.items():
        check(hashlib.sha256((ROOT / "tools/advisor_eval/runs/gold299_20260914/M12" / name).read_bytes()).hexdigest() == expected)
    observed = load_observed_receipt(ROOT / "tools/advisor_eval/runs/gold299_20260914/S05")
    check(observed["result"]["seed"] == "S7PXV521")
    probe = (HERE / "adapter/engine_probe.py").read_text(encoding="utf-8")
    fixture = (HERE / "adapter/startup_fixture.lua").read_text(encoding="utf-8")
    support = (HERE / "adapter/startup_menu_support.lua").read_text(encoding="utf-8")
    worker = (HERE / "adapter/worker.py").read_text(encoding="utf-8")
    check('for case in ("manual", "auto")' in worker and 'if result:' in worker)
    for term in ("probe_auto_run_product", "probe_auto_terminal", "probe_collection_run_ui", "probe_startup_menu_support", "PROBE_STARTUP_CASE"):
        check(term in probe)
    for term in ("g.FUNCS[callback]()", "g.FUNCS.options()", "g.CONTROLLER.locks.frame_set", "g.STATE_COMPLETE==false",
                 "calls.advisor_actions==0", "env.score_calls()==0", "after.skip_tags.Small=='tag_charm'",
                 "q.burnt_fallback==false", "q.quota_mode=='strict'"):
        check(term in fixture)
    for term in ("g:main_menu('game')", "g:update_menu(1/60)", "g.CONTROLLER:update(1/60)", "full_game_update=false", "original_boot_timer=false"):
        check(term in support)
    for term in ("g.CONTROLLER.locks={}", "g.STATE_COMPLETE=true", "g:prep_stage(", "g.GAME.won=true", "G.FUNCS.skip_blind("):
        check(term not in fixture and term not in support)
    with (HERE / "synthetic_fixture_report.json").open("x", encoding="utf-8") as stream:
        json.dump({"schema": 1, "checks": checks, "passed": True, "source_execution": False,
                   "native_search": False, "registration": False,
                   "scope": "Python AST, immutable M12/S05 inputs, explicit UI/phase wiring and scope guards only"}, stream, indent=2)
        stream.write("\n")
    print(f"M17 preparation: {checks} checks passed; source/native execution and registration remain pending.")

if __name__ == "__main__":
    main()
