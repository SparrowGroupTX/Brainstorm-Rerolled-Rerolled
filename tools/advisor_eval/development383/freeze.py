"""Freeze the bounded 64x event-cadence candidate without running a game."""

from datetime import datetime, timezone
import json
from pathlib import Path
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, freeze_policy, policy_hashes  # noqa: E402

BASE = EVAL / "SESSION_RESET_382.json"
INSTALLED = Path("C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm")
OUT = EVAL / "runs/cadence383_candidate"
VERSION = "2.181.0-alpha"
CHANGED = {
    "Brainstorm/Core/event_cadence.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def main() -> None:
    base = json.loads(BASE.read_text(encoding="utf-8-sig"))
    assert base["version"] == "2.180.0-alpha"
    assert policy_hashes(INSTALLED.parent) == base["policy_files"]
    natives = {p.name: file_digest(p) for p in sorted(INSTALLED.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    current = policy_hashes(ROOT)
    changed = {p for p in current.keys() | base["policy_files"].keys()
               if current.get(p) != base["policy_files"].get(p)}
    assert changed == CHANGED, sorted(changed)
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
    timing = EVAL / "development383/timing_prefix.json"
    timing_report = json.loads(timing.read_text(encoding="utf-8"))
    assert timing_report["status"] == "parsed_supplied_records"
    assert len(timing_report["inputs"]) == 3 and timing_report["performance_windows"] == 46
    OUT.mkdir(parents=True, exist_ok=False)
    frozen = freeze_policy(OUT / "policy")
    assert frozen == current
    fixtures = {str(path.relative_to(ROOT)).replace("\\", "/"): file_digest(path)
                for path in sorted((ROOT / "tests").rglob("*"))
                if path.is_file() and (path.suffix == ".lua" or
                    path.name.startswith("test_advisor_") and path.suffix == ".py")}
    receipt = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "kind": "routine_candidate_validation_no_gameplay_experiment",
        "baseline_release": 382,
        "baseline_policy_digest": base["policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted(changed),
        "test_files": fixtures,
        "timing_prefix_sha256": file_digest(timing),
        "public_prefix_status": "partial_stable_segments_not_terminal",
        "installed_or_running_game_modified": False,
        "new_training_or_gameplay_experiment": False,
    }
    (OUT / "freeze.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": VERSION, "policy_digest": digest(frozen),
                      "runtime_files": len(frozen), "changed": sorted(changed),
                      "test_files": len(fixtures)}))


if __name__ == "__main__":
    main()
