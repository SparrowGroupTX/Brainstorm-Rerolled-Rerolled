"""Bind the unchanged installed baseline, frozen candidate, settings and DLLs."""

import json
from pathlib import Path
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes  # noqa: E402

BASE = EVAL / "SESSION_RESET_382.json"
FROZEN = EVAL / "runs/win384_candidate/freeze.json"
GATE = EVAL / "runs/win384_candidate/validation/report.json"
OUT = EVAL / "development384/preinstall.json"


def main() -> None:
    base = json.loads(BASE.read_text(encoding="utf-8-sig"))
    frozen = json.loads(FROZEN.read_text(encoding="utf-8"))
    gate = json.loads(GATE.read_text(encoding="utf-8"))
    installed = Path(base["installed"])
    assert base["version"] == "2.180.0-alpha"
    assert policy_hashes(installed.parent) == base["policy_files"]
    assert policy_hashes(ROOT) == gate["policy_files"] == frozen["candidate_policy_files"]
    assert digest(gate["policy_files"]) == gate["policy_digest"] == frozen["candidate_policy_digest"]
    assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert all(file_digest(ROOT / rel) == sha for rel, sha in frozen["test_files"].items())
    config = file_digest(installed / "config.lua")
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]
    record = {"config_sha256": config, "native_files_preserved": natives,
              "baseline_policy_digest": base["policy_digest"],
              "candidate_policy_digest": frozen["candidate_policy_digest"],
              "candidate_test_files": len(frozen["test_files"]),
              "runtime_file_count": len(gate["policy_files"])}
    with OUT.open("x", encoding="utf-8") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"baseline": base["version"], "candidate": frozen["candidate_version"],
                      "candidate_digest": record["candidate_policy_digest"],
                      "config_sha256": config, "native_files": len(natives)}))


if __name__ == "__main__":
    main()
