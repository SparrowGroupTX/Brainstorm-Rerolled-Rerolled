"""Bind frozen 2.191 candidate to exact installed 2.184 bytes before release."""

from datetime import datetime, timezone
import json
from pathlib import Path
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes

BASE = EVAL / "SESSION_RESET_386.json"
FROZEN = EVAL / "runs/copy_slot393_candidate/freeze.json"
GATE = EVAL / "runs/copy_slot393_candidate/validation/report.json"
OUT = EVAL / "development394/preinstall.json"
CHANGED = {
    "Brainstorm/Advisor/acorn_belief.lua",
    "Brainstorm/Advisor/blind_finishing.lua",
    "Brainstorm/Advisor/decision.lua",
    "Brainstorm/Advisor/player_journal.lua",
    "Brainstorm/Advisor/search.lua",
    "Brainstorm/Advisor/shop_sequences.lua",
    "Brainstorm/Advisor/strategy.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    base, frozen, gate = read(BASE), read(FROZEN), read(GATE)
    installed = Path(base["installed"])
    assert base["version"] == "2.184.0-alpha"
    assert frozen["candidate_version"] == "2.191.0-alpha"
    assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert policy_hashes(installed.parent) == base["policy_files"]
    assert all(file_digest(installed / rel) == sha
               for rel, sha in base["deployment_files"].items())
    assert policy_hashes(ROOT) == gate["policy_files"] == frozen["candidate_policy_files"]
    assert digest(gate["policy_files"]) == gate["policy_digest"] == frozen["candidate_policy_digest"]
    gate_tests = {rel.replace("\\", "/"): sha for rel, sha in gate["test_files"].items()}
    assert gate_tests == frozen["test_files"]
    assert all(file_digest(ROOT / rel) == sha for rel, sha in frozen["test_files"].items())
    changed = {rel for rel, sha in frozen["candidate_policy_files"].items()
               if sha != base["policy_files"].get(rel)}
    assert changed == CHANGED == set(frozen["changed_runtime_files"])
    config = file_digest(installed / "config.lua")
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    record = {
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "baseline_version": base["version"],
        "candidate_version": frozen["candidate_version"],
        "installed_baseline_policy_digest": base["policy_digest"],
        "candidate_policy_digest": frozen["candidate_policy_digest"],
        "baseline_deployment_files_verified": len(base["deployment_files"]),
        "baseline_runtime_files_verified": len(base["policy_files"]),
        "candidate_test_files_verified": len(frozen["test_files"]),
        "changed_runtime_files": sorted(changed),
        "config_sha256_before": config,
        "config_matches_prior_receipt": config == base["config_sha256"],
        "native_files_preserved": natives,
        "candidate_gate_passed": True,
        "public_completed_session": "development394/capture/verification.json",
    }
    with OUT.open("x", encoding="utf-8") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"baseline": record["baseline_version"],
                      "candidate": record["candidate_version"],
                      "candidate_digest": record["candidate_policy_digest"],
                      "baseline_deployment_files": record["baseline_deployment_files_verified"],
                      "candidate_test_files": record["candidate_test_files_verified"],
                      "config_matches_prior_receipt": record["config_matches_prior_receipt"],
                      "native_files": len(natives)}))


if __name__ == "__main__":
    main()
