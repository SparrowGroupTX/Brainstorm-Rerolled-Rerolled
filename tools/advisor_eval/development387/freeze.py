"""Freeze the 2.185 discard-comparison candidate against installed 2.184."""

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, freeze_policy, policy_hashes

BASE = EVAL / "SESSION_RESET_386.json"
OUT = EVAL / "runs/yorick387_candidate"
VERSION = "2.185.0-alpha"
CHANGED = {
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/player_journal.lua",
    "Brainstorm/Advisor/search.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def main():
    base = json.loads(BASE.read_text(encoding="utf-8-sig"))
    assert base["version"] == "2.184.0-alpha"
    installed = Path(base["installed"])
    assert policy_hashes(installed.parent) == base["policy_files"]
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    current = policy_hashes(ROOT)
    changed = {p for p in current.keys() | base["policy_files"].keys()
               if current.get(p) != base["policy_files"].get(p)}
    assert changed == CHANGED, sorted(changed)
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
    capture = EVAL / "development387/capture/manifest.json"
    summary = json.loads(capture.read_text(encoding="utf-8"))
    assert summary["events"] == 7143 and len(summary["segments"]) == 7
    assert summary["versions"].get("Brainstorm v2.184.0-alpha", 0) > 0
    assert summary["profiles"].get("perkeo_yorick_win_v1", 0) > 0
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
        "baseline_release": 386,
        "baseline_policy_digest": base["policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted(changed),
        "test_files": fixtures,
        "public_prefix_manifest_sha256": file_digest(capture),
        "public_prefix": {"events": 7143, "completed_segments": 7,
                          "loaded_label": "2.184.0-alpha",
                          "profile": "perkeo_yorick_win_v1",
                          "complete_batch": False},
        "installed_or_running_game_modified": False,
        "new_training_or_gameplay_experiment": False,
    }
    with (OUT / "freeze.json").open("x", encoding="utf-8") as stream:
        json.dump(receipt, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"version": VERSION, "policy_digest": digest(frozen),
                      "runtime_files": len(frozen), "changed": sorted(changed),
                      "test_files": len(fixtures)}))


if __name__ == "__main__":
    main()
