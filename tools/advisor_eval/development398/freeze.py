"""Freeze the tested 2.193 Amber Acorn final-hand candidate without installation."""

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, freeze_policy, policy_hashes

BASE = EVAL / "SESSION_RESET_397.json"
OUT = EVAL / "runs/acorn398_candidate"
VERSION = "2.193.0-alpha"
CHANGED = {
    "Brainstorm/Advisor/acorn_discard.lua",
    "Brainstorm/Advisor/acorn_ordering.lua",
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/runtime.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def main():
    base = json.loads(BASE.read_text(encoding="utf-8-sig"))
    assert base["version"] == "2.192.0-alpha"
    installed = Path(base["installed"])
    assert policy_hashes(installed.parent) == base["policy_files"]
    assert all(file_digest(installed / rel) == sha
               for rel, sha in base["deployment_files"].items())
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    current = policy_hashes(ROOT)
    delta = {rel for rel in current.keys() | base["policy_files"].keys()
             if current.get(rel) != base["policy_files"].get(rel)}
    assert delta == CHANGED, sorted(delta)
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (
        ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
    OUT.mkdir(parents=True, exist_ok=False)
    frozen = freeze_policy(OUT / "policy")
    assert frozen == current
    tests = {str(p.relative_to(ROOT)).replace("\\", "/"): file_digest(p)
             for p in sorted((ROOT / "tests").rglob("*"))
             if p.is_file() and (p.suffix == ".lua" or
                 p.name.startswith("test_advisor_") and p.suffix == ".py")}
    receipt = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "kind": "routine_candidate_validation_no_gameplay_experiment",
        "baseline_release": 397,
        "baseline_version": base["version"],
        "baseline_policy_digest": base["policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted(CHANGED),
        "test_files": tests,
        "public_captures": ["development396/capture/verification.json"],
        "installed_or_running_game_modified": False,
        "new_training_or_gameplay_experiment": False,
    }
    (OUT / "freeze.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": VERSION, "policy_digest": digest(frozen),
                      "runtime_files": len(frozen), "changed": sorted(CHANGED),
                      "test_files": len(tests)}))


if __name__ == "__main__":
    main()
