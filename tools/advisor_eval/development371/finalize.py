"""Verify exact 371 candidate/installation and write compact checkpoint receipts.

Read-only verification except for new checkpoint/final JSON files. No game,
save, policy replay, search or source-game execution is involved.
"""

from datetime import datetime, timezone
from pathlib import Path
import json
import re
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes  # noqa: E402

INSTALLED = Path("C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm")
RUNS = EVAL / "runs"
CANDIDATE = RUNS / "engine371_candidate"
RELEASE = RUNS / "engine371_installed"
VALIDATED = RUNS / "engine371_installed_validation"
FINAL = RUNS / "engine371_final"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def address(path):
    return {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
            "sha256": file_digest(path)}


def main():
    old = read(EVAL / "SESSION_RESET_370.json")
    frozen = read(CANDIDATE / "freeze.json")
    candidate = read(CANDIDATE / "validation/report.json")
    record = read(RELEASE / "record.json")
    installed_gate = read(VALIDATED / "report.json")
    deployment = read(Path(record["deployment_manifest"]))

    assert old["version"] == "2.170.0-alpha"
    assert frozen["version"] == record["version"] == deployment["version"] == "2.171.0-alpha"
    assert candidate["passed"] and installed_gate["passed"]
    assert all(gate["policy_unchanged"] and gate["tests_unchanged"]
               for gate in (candidate, installed_gate))
    assert candidate["policy_digest"] == installed_gate["policy_digest"] == \
        record["policy"]["policy_digest"] == frozen["policy"]["policy_digest"]
    assert candidate["policy_files"] == installed_gate["policy_files"] == \
        record["policy"]["policy_files"] == frozen["policy"]["policy_files"]
    assert candidate["test_files"] == installed_gate["test_files"]
    assert digest(candidate["policy_files"]) == candidate["policy_digest"]
    assert len(candidate["policy_files"]) == 106 and len(deployment["files"]) == 90
    assert record["all_repository_files_match"]
    assert policy_hashes(ROOT) == policy_hashes(INSTALLED.parent) == candidate["policy_files"]
    assert all(file_digest(ROOT / relative) == expected
               for relative, expected in candidate["test_files"].items())
    assert all(row["status"] == "passed" and row["seconds"] < 60
               for gate in (candidate, installed_gate) for row in gate["runs"])
    assert file_digest(INSTALLED / "config.lua") == old["config_sha256"] == record["config_sha256"]
    native = {path.name: file_digest(path) for path in sorted(INSTALLED.glob("*.dll"))}
    assert native == old["native_files_preserved"] and len(native) == 7

    deployed = {}
    for item in deployment["files"]:
        relative = item["path"].replace("\\", "/")
        expected = item["after"].lower()
        assert file_digest(INSTALLED / relative) == expected
        deployed[relative] = expected
    assert len(deployed) == 90
    changed = {relative for relative, sha in deployed.items()
               if sha != old["deployment_files"].get(relative)}
    expected_changed = {"Advisor/strategy.lua", "Advisor/paid_reroll.lua",
                        "Advisor/decision.lua", "Core/Brainstorm.lua",
                        "steamodded_compat.lua"}
    assert changed == expected_changed
    assert not (set(old["deployment_files"]) - set(deployed))

    cohort = old["loaded_cohort"]
    report = ROOT / cohort["report"]["path"]
    assert file_digest(report) == cohort["report"]["sha256"]
    assert cohort["version_stamp"] == "2.169.0-alpha"
    assert (cohort["starts"], cohort["wins"], cohort["losses"], cohort["nonterminal"]) == (10, 2, 8, 0)

    for path in (CANDIDATE / "validation/lua.log", VALIDATED / "lua.log"):
        assert len(re.findall(r"^Running ", path.read_text(encoding="utf-8"), re.MULTILINE)) == 244
    for path in (CANDIDATE / "validation/python.log", VALIDATED / "python.log"):
        assert "Ran 391 tests" in path.read_text(encoding="utf-8")

    checkpoint = {
        "release": 371, "version": record["version"],
        "installed_at": record["installed_at"], "installed": record["installed"],
        "backup": record["backup"], "config_sha256": record["config_sha256"],
        "native_files_preserved": native, "policy_digest": candidate["policy_digest"],
        "policy_files": candidate["policy_files"], "deployment_files": deployed,
        "explicit_changed_files": sorted(changed),
        "candidate_validation": address(CANDIDATE / "validation/report.json"),
        "exact_installed_validation": address(VALIDATED / "report.json"),
        "installed_record": address(RELEASE / "record.json"),
        "loaded_cohort": cohort,
        "activation": "Not confirmed; normal user restart required",
        "experiment_budget": "No new authorization; historical allowances closed",
    }
    checkpoint_path = EVAL / "SESSION_RESET_371.json"
    checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n", encoding="utf-8")

    docs = [ROOT / "ADVISOR_START_HERE.md", ROOT / "ADVISOR_RESUME_PROMPT.md",
            ROOT / "ADVISOR_HANDOFF.md", EVAL / "SESSION_RESET_371.md",
            checkpoint_path, EVAL / "NEXT_PRIORITIES_371.md",
            EVAL / "ARCHITECTURE_MAP_371.md", EVAL / "WIN_RATE_RESEARCH.md",
            EVAL / "development371/SCOPE.md", report]
    FINAL.mkdir(parents=True, exist_ok=True)
    final = {
        "verified_at_utc": datetime.now(timezone.utc).isoformat(),
        "version": record["version"], "policy_digest": candidate["policy_digest"],
        "deployment_file_count": len(deployed),
        "runtime_dependency_file_count": len(candidate["policy_files"]),
        "explicit_changed_files": sorted(changed),
        "candidate_lua_fixtures": 244, "candidate_python_tests": 391,
        "installed_lua_fixtures": 244, "installed_python_tests": 391,
        "candidate_passed": True, "exact_installed_passed": True,
        "test_hashes_equal": True, "config_unchanged": True,
        "seven_native_files_unchanged": True,
        "loaded_2_169_cohort_unchanged": True,
        "loaded_2_171_confirmed": False,
        "documents": {str(path.relative_to(ROOT)).replace("\\", "/"): file_digest(path)
                      for path in docs},
        "saves": "Not read or written", "game_control": "None", "new_experiments": 0,
    }
    (FINAL / "final_verification.json").write_text(json.dumps(final, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": final["version"], "deployment_files": len(deployed),
                      "runtime_files": len(candidate["policy_files"]),
                      "lua": 244, "python": 391, "documents": len(docs)}))


if __name__ == "__main__":
    main()
