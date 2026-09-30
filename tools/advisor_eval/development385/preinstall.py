"""Bind the frozen 2.183 candidate to exact installed 2.182 bytes and current settings."""
import json
from pathlib import Path
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes

BASE = EVAL / "SESSION_RESET_384.json"
FROZEN = EVAL / "runs/cash385_candidate/freeze.json"
GATE = EVAL / "runs/cash385_candidate/validation/report.json"
OUT = EVAL / "development385/preinstall.json"


def main():
    base = json.loads(BASE.read_text(encoding="utf-8-sig"))
    frozen = json.loads(FROZEN.read_text(encoding="utf-8"))
    gate = json.loads(GATE.read_text(encoding="utf-8"))
    installed = Path(base["installed"])
    assert base["version"] == "2.182.0-alpha"
    assert policy_hashes(installed.parent) == base["policy_files"]
    assert policy_hashes(ROOT) == gate["policy_files"] == frozen["candidate_policy_files"]
    assert digest(gate["policy_files"]) == gate["policy_digest"] == frozen["candidate_policy_digest"]
    assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert all(file_digest(ROOT / rel) == sha for rel, sha in frozen["test_files"].items())
    config = file_digest(installed / "config.lua")
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    record = {
        "baseline_version": base["version"],
        "candidate_version": frozen["candidate_version"],
        "installed_baseline_policy_digest": base["policy_digest"],
        "candidate_policy_digest": frozen["candidate_policy_digest"],
        "config_sha256_before": config,
        "config_matches_prior_receipt": config == base["config_sha256"],
        "native_files_preserved": natives,
        "candidate_test_files": len(frozen["test_files"]),
        "candidate_gate_passed": True,
        "changed_runtime_files": frozen["changed_runtime_files"],
    }
    with OUT.open("x", encoding="utf-8") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"baseline": record["baseline_version"],
                      "candidate": record["candidate_version"],
                      "candidate_digest": record["candidate_policy_digest"],
                      "config_sha256_before": config,
                      "config_matches_prior_receipt": record["config_matches_prior_receipt"],
                      "native_files": len(natives)}))


if __name__ == "__main__":
    main()
