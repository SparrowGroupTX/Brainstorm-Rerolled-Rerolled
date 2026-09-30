"""Root-only M17 registration helper; no worker dispatch here."""
from pathlib import Path
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / "tools/advisor_eval/development299"))
sys.path.insert(0, str(HERE / "adapter"))
from cycle import register
from startup_receipt import load_observed_receipt

def main():
    record_path = Path(sys.argv[1]).resolve()
    expected_record = ROOT / "tools/advisor_eval/runs/fallback307_installed/record.json"
    assert record_path == expected_record.resolve(), "M17 preparation binds installed307 only"
    record = json.loads(record_path.read_text(encoding="utf-8"))
    policy = record_path.parent / "policy"
    hashes = record["policy"]["policy_files"]
    required = ("Brainstorm/Core/collection_search_product.lua", "Brainstorm/Core/auto_run_product.lua",
                "Brainstorm/Core/auto_terminal.lua", "Brainstorm/UI/collection_run.lua",
                "Brainstorm/Advisor/auto_run.lua", "Brainstorm/Advisor/collection_search.lua")
    assert all(name in hashes for name in required)
    assert record["version"] == "2.107.0-alpha"
    evidence = ROOT / "tools/advisor_eval/runs/gold299_20260914/S05"
    observed = load_observed_receipt(evidence)
    m16 = ROOT / "tools/advisor_eval/runs/gold299_20260914/M16"
    m16record = json.loads((m16 / "record.json").read_text(encoding="utf-8"))
    assert m16record["status"] == "complete" and m16record["exit_code"] == 0
    assert hashlib.sha256((m16 / "inspection/main_menu.lua").read_bytes()).hexdigest() == "ba63b6f2fb232d50856c9b9748cc8037c28d75f9f24b4877e6d20de32a51e8de"
    files = {path.name: path for path in (HERE / "adapter").iterdir() if path.is_file() and path.suffix in (".lua", ".py")}
    for name in ("spec.md", "parent_evidence_hashes.json", "synthetic_fixture_report.json"):
        files[name] = HERE / name
    for name in observed["binding"]["files"]:
        files["evidence/S05/" + name] = evidence / name
    for number in (11, 13, 16):
        folder = ROOT / f"tools/advisor_eval/runs/gold299_20260914/M{number}"
        files[f"evidence/M{number}/record.json"] = folder / "record.json"
        files[f"evidence/M{number}/audit.json"] = folder / "audit.json"
        for path in (folder / "inspection").glob("*"):
            if path.is_file():
                files[f"evidence/M{number}/inspection/{path.name}"] = path
    files["frozen_product_record.json"] = record_path
    files.update({"policy/" + name: policy / name for name in hashes})
    install = Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro")
    job = register("M17", files, [sys.executable, "-B", "-u", "{job}/worker.py"], {
        "hypothesis": "Actual manual and auto Start UI callbacks can leave original source main-menu overlays, respect frame locks, then start observed S05 with an actual Small Charm Tag.",
        "maximum_advisor_actions": 0, "maximum_product_launches": 2, "maximum_cases": 2,
        "native_search_in_component": False, "maximum_score_calls": 0, "outer_cap_seconds": 30,
        "cases": ["manual", "auto"], "case_isolation": "fresh isolated Lua state per case; one shared30s job cap",
        "initial_seed": "STARTUP1", "requested_seed": "S7PXV521", "observed_receipt": observed["binding"],
        "policy_digest": record["policy"]["policy_digest"],
        "mechanical_boundary": "Actual UI button and product facade/controller; original main_menu/options/overlay/exit/update_menu/Controller:update and Game start; existing source UI tree and no-input presentation stubs.",
        "profile": "all_unlocked_discovered_v1, actual source-loaded fresh in-memory Joker progress unchanged",
        "source_access": "Executable ZIP and isolated lua51.dll within this one registered M17 lease only",
        "save_access": "No physical player files; inherited isolated source no-save guards",
        "declared_standins": ["observed S05 search receipt", "M13 font-only boot cache", "UI display tree",
                               "no-input mouse/keyboard", "memory-only auto logger", "advisor invalidation callback"],
        "full_game_update": False, "qualification": False,
        "limits": "Preblind startup only; no true native search, pack acquisition, blind play, terminal outcome, full autoplay or achievement. Unsupported dependencies remain failures.",
    }, external=[install / "Balatro.exe", install / "lua51.dll", Path(sys.executable)])
    print(job / "registration.json")

if __name__ == "__main__":
    main()
