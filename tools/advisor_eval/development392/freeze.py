"""Freeze the uninstalled 2.190 public-cohort repair without touching play."""

from datetime import datetime, timezone
from pathlib import Path
import json
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, freeze_policy, policy_hashes

PREVIOUS = EVAL / "runs/hand391_verified_candidate/freeze.json"
BASE = EVAL / "SESSION_RESET_386.json"
OUT = EVAL / "runs/mouth_madness392_candidate"
VERSION = "2.190.0-alpha"
CHANGED_FROM_PREVIOUS = {
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/shop_sequences.lua",
    "Brainstorm/Advisor/strategy.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    prior, base = read(PREVIOUS), read(BASE)
    assert prior["candidate_version"] == "2.189.0-alpha"
    assert prior["candidate_policy_digest"] == (
        "03266454ae9cf9aeb1d6260dc295fba2adc824f7670be8167562eae8ba96696a"
    )
    assert read(EVAL / "runs/hand391_verified_candidate/validation/report.json")["passed"]
    assert base["version"] == "2.184.0-alpha"
    installed = Path(base["installed"])
    assert policy_hashes(installed.parent) == base["policy_files"]
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    current = policy_hashes(ROOT)
    delta = {p for p in current.keys() | prior["candidate_policy_files"].keys()
             if current.get(p) != prior["candidate_policy_files"].get(p)}
    assert delta == CHANGED_FROM_PREVIOUS, sorted(delta)
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
        "baseline_release": 386,
        "baseline_policy_digest": base["policy_digest"],
        "incorporated_candidate_version": prior["candidate_version"],
        "incorporated_candidate_digest": prior["candidate_policy_digest"],
        "candidate_version": VERSION,
        "candidate_policy_digest": digest(frozen),
        "candidate_policy_files": frozen,
        "changed_runtime_files": sorted({p for p in frozen.keys() | base["policy_files"].keys()
                                         if frozen.get(p) != base["policy_files"].get(p)}),
        "test_files": tests,
        "public_capture": "development392/logs1: 25 hash-verified segments, 10 starts, 2 wins, 5 losses, 3 unsupported; loaded label 2.184, win-first.",
        "installed_or_running_game_modified": False,
        "new_training_or_gameplay_experiment": False,
    }
    (OUT / "freeze.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": VERSION, "policy_digest": digest(frozen),
                      "runtime_files": len(frozen), "changed_from_previous": sorted(delta),
                      "changed_from_installed": receipt["changed_runtime_files"],
                      "test_files": len(tests)}))


if __name__ == "__main__":
    main()
