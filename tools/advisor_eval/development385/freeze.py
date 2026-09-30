"""Freeze the 2.183 cash-fallback candidate against the installed 2.182 checkpoint."""
from datetime import datetime, timezone
from pathlib import Path
import json
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, freeze_policy, policy_hashes

BASE = EVAL / "SESSION_RESET_384.json"
OUT = EVAL / "runs/cash385_candidate"
VERSION = "2.183.0-alpha"
CHANGED = {
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/strategy.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def main():
    base = json.loads(BASE.read_text(encoding="utf-8-sig"))
    assert base["version"] == "2.182.0-alpha"
    installed = Path(base["installed"])
    assert policy_hashes(installed.parent) == base["policy_files"]
    native = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(native) == 7 and native == base["native_files_preserved"]
    assert file_digest(installed / "config.lua") == base["config_sha256"]
    current = policy_hashes(ROOT)
    changed = {p for p in current.keys() | base["policy_files"].keys()
               if current.get(p) != base["policy_files"].get(p)}
    assert changed == CHANGED, sorted(changed)
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
    capture = json.loads((EVAL / "development385/capture/manifest.json").read_text(encoding="utf-8"))
    shops = json.loads((EVAL / "development385/capture/shops.json").read_text(encoding="utf-8"))
    assert capture["events"] == capture["last_sequence"] == 4020
    assert capture["versions"].get("Brainstorm v2.182.0-alpha", 0) > 0
    assert capture["profiles"].get("perkeo_yorick_win_v1", 0) > 0
    high = [s for s in shops if s.get("cash", 0) > 50 and
            (s.get("action") or {}).get("kind") == "leave_shop"]
    assert len(high) == 10 and all(s["shop_truncated"] is True for s in high)
    assert sum((s.get("reroll_review") or {}).get("status") == "admitted" for s in high) == 3
    OUT.mkdir(parents=True, exist_ok=False)
    frozen = freeze_policy(OUT / "policy")
    assert frozen == current
    fixtures = {str(p.relative_to(ROOT)).replace("\\", "/"): file_digest(p)
                for p in sorted((ROOT / "tests").rglob("*"))
                if p.is_file() and (p.suffix == ".lua" or
                                    p.name.startswith("test_advisor_") and p.suffix == ".py")}
    receipt = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "kind": "routine_candidate_validation_no_gameplay_experiment",
        "baseline_release": 384,
        "baseline_policy_digest": base["policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted(changed),
        "test_files": fixtures,
        "public_prefix_manifest_sha256": file_digest(EVAL / "development385/capture/manifest.json"),
        "public_prefix_shops_sha256": file_digest(EVAL / "development385/capture/shops.json"),
        "public_prefix": {"events": 4020, "high_cash_leaves": 10,
                          "admitted_but_abandoned": 3,
                          "loaded_label": "2.182.0-alpha",
                          "profile": "perkeo_yorick_win_v1"},
        "installed_or_running_game_modified": False,
        "new_training_or_gameplay_experiment": False,
    }
    (OUT / "freeze.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": VERSION, "policy_digest": digest(frozen),
                      "runtime_files": len(frozen), "changed": sorted(changed),
                      "test_files": len(fixtures)}))


if __name__ == "__main__":
    main()
