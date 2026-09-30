"""Freeze uninstalled 2.186, incorporating 2.185, against installed 2.184."""

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, freeze_policy, policy_hashes

BASE = EVAL / "SESSION_RESET_386.json"
PREVIOUS = EVAL / "runs/yorick387_candidate/freeze.json"
CAPTURE = EVAL / "development388/capture/manifest.json"
OUT = EVAL / "runs/cash388_candidate"
VERSION = "2.186.0-alpha"
CHANGED = {
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/player_journal.lua",
    "Brainstorm/Advisor/search.lua",
    "Brainstorm/Advisor/strategy.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    base, previous, capture = read(BASE), read(PREVIOUS), read(CAPTURE)
    assert base["version"] == "2.184.0-alpha"
    assert previous["candidate_version"] == "2.185.0-alpha"
    assert previous["candidate_policy_digest"] == (
        "bf09ad12fcd2327850d02c0e6dd8c308f952c93c26e8f3341aeaa9ccd99fb1b2"
    )
    installed = Path(base["installed"])
    assert policy_hashes(installed.parent) == base["policy_files"]
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    current = policy_hashes(ROOT)
    changed = {p for p in current.keys() | base["policy_files"].keys()
               if current.get(p) != base["policy_files"].get(p)}
    assert changed == CHANGED, sorted(changed)
    for path in ("Brainstorm/Advisor/search.lua", "Brainstorm/Advisor/decision.lua"):
        assert current[path] == previous["candidate_policy_files"][path]
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (
        ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
    assert capture["first_sequence"] == 7144 and capture["last_sequence"] == 18531
    assert len(capture["segments"]) == 13
    assert capture["versions"].get("Brainstorm v2.184.0-alpha", 0) > 0
    assert capture["profiles"].get("perkeo_yorick_win_v1", 0) > 0
    assert (EVAL / "runs/yorick387_candidate/validation/report.json").is_file()
    prior_gate = read(EVAL / "runs/yorick387_candidate/validation/report.json")
    assert prior_gate["passed"] and prior_gate["policy_unchanged"] and prior_gate["tests_unchanged"]

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
        "incorporated_candidate_version": previous["candidate_version"],
        "incorporated_candidate_digest": previous["candidate_policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted(changed),
        "test_files": fixtures,
        "public_increment_manifest_sha256": file_digest(CAPTURE),
        "public_increment": {"first_sequence": 7144, "last_sequence": 18531,
                             "completed_segments": 13, "loaded_label": "2.184.0-alpha",
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
