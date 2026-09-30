"""Freeze the 2.174 routine candidate; no game, policy replay or source execution."""

from datetime import datetime, timezone
from pathlib import Path
import json
import shutil
import sys


EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes, policy_sources  # noqa: E402


INSTALLED = Path("C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm")
OUT = EVAL / "runs" / "marathon375_candidate"
BASELINE = EVAL / "SESSION_RESET_371.json"
EXPECTED = {
    "Brainstorm/Advisor/strategy.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/Core/event_cadence.lua",
    "Brainstorm/UI/game_speed.lua",
    "Brainstorm/steamodded_compat.lua",
}


def main():
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    assert baseline["version"] == "2.171.0-alpha"
    installed = policy_hashes(INSTALLED.parent)
    assert installed == baseline["policy_files"]
    assert file_digest(INSTALLED / "config.lua") == baseline["config_sha256"]
    natives = {p.name: file_digest(p) for p in sorted(INSTALLED.glob("*.dll"))}
    assert len(natives) == 7 and natives == baseline["native_files_preserved"]
    candidate = policy_hashes(ROOT)
    changed = {name for name in set(installed) | set(candidate)
               if installed.get(name) != candidate.get(name)}
    assert changed == EXPECTED, changed
    assert "Brainstorm v2.174.0-alpha" in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text()
    assert "--- VERSION: 2.174.0-alpha" in (ROOT / "Brainstorm/steamodded_compat.lua").read_text()

    OUT.mkdir(parents=True, exist_ok=False)
    for source in policy_sources(ROOT):
        destination = OUT / "policy" / source.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    assert policy_hashes(OUT / "policy") == candidate
    fixture = ROOT / "tests/advisor_copy_target_rating375.lua"
    freeze = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "kind": "routine_candidate_validation_no_gameplay_experiment",
        "baseline_release": 371,
        "baseline_policy_digest": baseline["policy_digest"],
        "candidate_version": "2.174.0-alpha",
        "candidate_policy_digest": digest(candidate),
        "candidate_policy_files": candidate,
        "changed_runtime_files": sorted(changed),
        "fixture": {str(fixture.relative_to(ROOT)).replace("\\", "/"): file_digest(fixture)},
        "installed_371_matches_checkpoint": True,
        "installed_config_and_seven_native_files_preserved": True,
        "installed_not_modified": True,
        "includes_validated_unreleased_speed_candidate": "runs/speed374_candidate2",
    }
    (OUT / "freeze.json").write_text(json.dumps(freeze, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": freeze["candidate_version"],
                      "policy_digest": freeze["candidate_policy_digest"],
                      "policy_files": len(candidate), "changed": sorted(changed)}))


if __name__ == "__main__":
    main()
