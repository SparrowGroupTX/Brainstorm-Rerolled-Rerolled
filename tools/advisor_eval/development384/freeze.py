"""Freeze only the versioned 384 runtime slice and manufactured fixtures."""

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
OUT = EVAL / "runs/win384_candidate"
VERSION = "2.182.0-alpha"
CHANGED = {
    "Brainstorm/Advisor/acorn_belief.lua",
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/deck_development.lua",
    "Brainstorm/Advisor/player_journal.lua",
    "Brainstorm/Advisor/search.lua",
    "Brainstorm/Advisor/strategy.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/Core/event_cadence.lua",
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
    cadence = json.loads((EVAL / "runs/cadence383_candidate/freeze.json").read_text(encoding="utf-8"))
    assert current["Brainstorm/Core/event_cadence.lua"] == cadence["candidate_policy_files"]["Brainstorm/Core/event_cadence.lua"]
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
    capture = json.loads((EVAL / "development384/capture/summary.json").read_text(encoding="utf-8"))
    assert capture["converter_error"] is None and capture["converter"]["counts"]["events"] == 18179
    assert capture["converter"]["counts"]["wins"] == 1 and capture["converter"]["counts"]["losses"] == 8
    assert capture["converter"]["counts"]["unsupported"] == 1
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
        "incorporated_cadence383_candidate_digest": cadence["candidate_policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted(changed),
        "test_files": fixtures,
        "public_log_manifest_sha256": file_digest(EVAL / "development384/logs1/manifest.json"),
        "public_capture_summary_sha256": file_digest(EVAL / "development384/capture/summary.json"),
        "public_cohort": {"starts": 10, "wins": 1, "losses": 8, "unsupported": 1,
                          "loaded_label": "2.180.0-alpha", "profile": "perkeo_yorick_win_v1"},
        "installed_or_running_game_modified": False,
        "new_training_or_gameplay_experiment": False,
    }
    (OUT / "freeze.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": VERSION, "policy_digest": digest(frozen),
                      "runtime_files": len(frozen), "changed": sorted(changed),
                      "test_files": len(fixtures)}))


if __name__ == "__main__":
    main()
