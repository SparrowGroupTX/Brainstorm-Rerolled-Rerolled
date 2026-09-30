"""M17 two isolated UI-start lifecycle cases; no native search or advisor action."""
from pathlib import Path
import json
import sys

def main():
    folder = Path(__file__).resolve().parent
    registration = json.loads((folder / "registration.json").read_text(encoding="utf-8"))
    spent = json.loads((folder / "spent.json").read_text(encoding="utf-8"))
    assert registration["job"] == spent["job"] == "M17"
    assert registration["timeout_seconds"] == 30
    assert registration["metadata"]["maximum_advisor_actions"] == 0
    assert registration["metadata"]["maximum_product_launches"] == 2
    import engine_probe
    for case in ("manual", "auto"):
        print(json.dumps({"type": "M17_case_start", "case": case, "fresh_lua_state": True}), flush=True)
        sys.argv = [sys.argv[0], "--deck", "b_red", "--stake", "8", "--seed", "STARTUP1",
                    "--unlock-profile", "all_unlocked_discovered_v1", "--policy-root", str(folder / "policy"),
                    "--episode", "--test-scenario", "collection_button_startup", "--startup-case", case]
        result = engine_probe.main()
        print(json.dumps({"type": "M17_case_finished", "case": case, "exit_code": result}), flush=True)
        if result:
            return result
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
