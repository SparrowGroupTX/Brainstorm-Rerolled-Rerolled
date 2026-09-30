"""Verify and record release 370 and the frozen loaded-2.169 public cohort."""

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
CANDIDATE = RUNS / "auto_arch370_candidate"
RELEASE = RUNS / "auto_arch370_installed"
VALIDATED = RUNS / "auto_arch370_installed_validation"
FINAL = RUNS / "auto_arch370_final"
COHORT = EVAL / "win_rate_research/20260923_2_169_ten_start"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def address(path):
    return {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
            "sha256": file_digest(path)}


def main():
    old = read(EVAL / "SESSION_RESET_369.json")
    candidate = read(CANDIDATE / "validation/report.json")
    record = read(RELEASE / "record.json")
    installed_gate = read(VALIDATED / "report.json")
    capture = read(COHORT / "capture/manifest.json")
    audit = read(COHORT / "checkpoint.json")
    summary = read(COHORT / "capture/summary.json")
    deployment = read(Path(record["deployment_manifest"]))

    assert old["version"] == "2.169.0-alpha"
    assert record["version"] == deployment["version"] == "2.170.0-alpha"
    assert candidate["passed"] and installed_gate["passed"]
    assert candidate["policy_unchanged"] and candidate["tests_unchanged"]
    assert installed_gate["policy_unchanged"] and installed_gate["tests_unchanged"]
    assert candidate["policy_digest"] == installed_gate["policy_digest"] == record["policy"]["policy_digest"]
    assert candidate["policy_files"] == installed_gate["policy_files"] == record["policy"]["policy_files"]
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
    old_deployed = old["deployment_files"]
    changed = {relative for relative in deployed if deployed[relative] != old_deployed.get(relative)}
    expected_changed = {"Advisor/auto_run.lua", "Core/auto_run_product.lua",
                        "Core/auto_run_settlement.lua", "Core/Brainstorm.lua",
                        "steamodded_compat.lua"}
    assert changed == expected_changed
    assert not (set(old_deployed) - set(deployed))

    assert len(capture["inputs"]) == 25 and capture["last_sequence"] == 17189
    assert not capture["gaps"] and not capture["errors"]
    assert audit["frozen_mismatches"] == [] and audit["stable_capture"]
    for item in capture["inputs"]:
        assert file_digest(ROOT / item["frozen"]) == item["sha256"]
    counts = summary["converter"]["counts"]
    assert (counts["wins"], counts["losses"], counts["error"], counts["unsupported"]) == (2, 8, 0, 0)
    assert summary["snapshot_profiles"] == {"perkeo_yorick_win_v1": 2696}
    assert summary["versions"] == {"Brainstorm v2.169.0-alpha": 15563}

    lua_counts = []
    for path in (CANDIDATE / "validation/lua.log", VALIDATED / "lua.log"):
        lua_counts.append(len(re.findall(r"^Running ", path.read_text(encoding="utf-8"), re.MULTILINE)))
    assert lua_counts == [241, 241]
    for path in (CANDIDATE / "validation/python.log", VALIDATED / "python.log"):
        assert "Ran 391 tests" in path.read_text(encoding="utf-8")

    checkpoint = {
        "release": 370, "version": record["version"],
        "installed_at": record["installed_at"], "installed": record["installed"],
        "backup": record["backup"], "config_sha256": record["config_sha256"],
        "native_files_preserved": native, "policy_digest": candidate["policy_digest"],
        "policy_files": candidate["policy_files"], "deployment_files": deployed,
        "candidate_validation": address(CANDIDATE / "validation/report.json"),
        "exact_installed_validation": address(VALIDATED / "report.json"),
        "installed_record": address(RELEASE / "record.json"),
        "loaded_cohort": {
            "version_stamp": "2.169.0-alpha", "profile": "perkeo_yorick_win_v1",
            "starts": 10, "wins": 2, "losses": 8, "nonterminal": 0,
            "capture_cutoff_utc": capture["last_at"], "last_sequence": capture["last_sequence"],
            "capture_manifest": address(COHORT / "capture/manifest.json"),
            "audit_checkpoint": address(COHORT / "checkpoint.json"),
            "report": address(COHORT / "REPORT.md"),
        },
        "activation": "Not confirmed; normal user restart required",
        "experiment_budget": "No new authorization; historical allowances closed",
    }
    checkpoint_path = EVAL / "SESSION_RESET_370.json"
    checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n", encoding="utf-8")

    docs = [ROOT / "ADVISOR_START_HERE.md", ROOT / "ADVISOR_RESUME_PROMPT.md",
            ROOT / "ADVISOR_HANDOFF.md", EVAL / "SESSION_RESET_370.md",
            checkpoint_path, EVAL / "NEXT_PRIORITIES_370.md",
            EVAL / "ARCHITECTURE_MAP_370.md", EVAL / "WIN_RATE_RESEARCH.md",
            EVAL / "development370/AUTO_RUN_ARCHITECTURE.md", COHORT / "REPORT.md"]
    FINAL.mkdir(exist_ok=False)
    final = {
        "verified_at_utc": datetime.now(timezone.utc).isoformat(),
        "version": record["version"], "policy_digest": candidate["policy_digest"],
        "deployment_file_count": 90, "runtime_dependency_file_count": 106,
        "explicit_changed_files": sorted(changed),
        "candidate_lua_fixtures": 241, "candidate_python_tests": 391,
        "installed_lua_fixtures": 241, "installed_python_tests": 391,
        "candidate_passed": True, "exact_installed_passed": True,
        "test_hashes_equal": True, "config_unchanged": True,
        "seven_native_files_unchanged": True, "cohort_frozen_hashes_match": True,
        "cohort_outcomes": {"win": 2, "loss": 8},
        "loaded_2_169_public_label": True, "loaded_2_170_confirmed": False,
        "documents": {str(path.relative_to(ROOT)).replace("\\", "/"): file_digest(path)
                      for path in docs},
        "saves": "Not read or written", "game_control": "None", "new_experiments": 0,
    }
    (FINAL / "final_verification.json").write_text(json.dumps(final, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": final["version"], "deployment_files": 90,
                      "runtime_files": 106, "lua": 241, "python": 391,
                      "cohort": final["cohort_outcomes"], "documents": len(docs)}))


if __name__ == "__main__":
    main()
