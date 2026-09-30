"""Freeze the bounded win-first Yorick discard candidate."""

from datetime import datetime, timezone
import json
from pathlib import Path
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, freeze_policy, policy_hashes  # noqa: E402

BASE = EVAL / "SESSION_RESET_381.json"
INSTALLED = Path("C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm")
OUT = EVAL / "runs/yorick382_candidate2"
VERSION = "2.180.0-alpha"
CHANGED = {
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/growth.lua",
    "Brainstorm/Advisor/player_journal.lua",
    "Brainstorm/Advisor/search.lua",
    "Brainstorm/Advisor/runtime.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def main() -> None:
    base = json.loads(BASE.read_text(encoding="utf-8-sig"))
    assert base["version"] == "2.179.0-alpha"
    assert policy_hashes(INSTALLED.parent) == base["policy_files"]
    assert file_digest(INSTALLED / "config.lua") == base["config_sha256"]
    assert {p.name: file_digest(p) for p in sorted(INSTALLED.glob("*.dll"))} == base["native_files_preserved"]
    current = policy_hashes(ROOT)
    changed = {p for p in current.keys() | base["policy_files"].keys()
               if current.get(p) != base["policy_files"].get(p)}
    assert changed == CHANGED, sorted(changed)
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
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
        "baseline_release": 381,
        "baseline_policy_digest": base["policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted(changed),
        "test_files": fixtures,
        "installed_or_running_game_modified": False,
        "new_training_or_gameplay_experiment": False,
    }
    (OUT / "freeze.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": VERSION, "policy_digest": digest(frozen),
                      "runtime_files": len(frozen), "changed": sorted(changed),
                      "test_files": len(fixtures)}))


if __name__ == "__main__":
    main()
