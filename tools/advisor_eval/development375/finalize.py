"""Verify release 375, its frozen cohort and both exact gates; write checkpoint."""

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
CANDIDATE = RUNS / "marathon375_candidate"
RELEASE = RUNS / "marathon375_installed"
VALIDATED = RUNS / "marathon375_installed_validation"
FINAL = RUNS / "marathon375_final"
COHORT = EVAL / "win_rate_research/20260923_182719_ten_start"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def address(path):
    return {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
            "sha256": file_digest(path)}


def main():
    old = read(EVAL / "SESSION_RESET_371.json")
    frozen = read(CANDIDATE / "freeze.json")
    candidate = read(CANDIDATE / "validation/report.json")
    record = read(RELEASE / "record.json")
    installed_gate = read(VALIDATED / "report.json")
    deployment = read(Path(record["deployment_manifest"]))
    assert old["version"] == "2.171.0-alpha"
    assert frozen["candidate_version"] == record["version"] == deployment["version"] == "2.174.0-alpha"
    assert candidate["passed"] and installed_gate["passed"]
    assert all(g["policy_unchanged"] and g["tests_unchanged"]
               for g in (candidate, installed_gate))
    assert candidate["policy_digest"] == installed_gate["policy_digest"] == \
        record["policy"]["policy_digest"] == frozen["candidate_policy_digest"]
    assert candidate["policy_files"] == installed_gate["policy_files"] == \
        record["policy"]["policy_files"] == frozen["candidate_policy_files"]
    assert candidate["test_files"] == installed_gate["test_files"]
    assert digest(candidate["policy_files"]) == candidate["policy_digest"]
    assert len(candidate["policy_files"]) == 107 and len(deployment["files"]) == 91
    assert record["all_repository_files_match"]
    assert policy_hashes(ROOT) == policy_hashes(INSTALLED.parent) == candidate["policy_files"]
    assert all(file_digest(ROOT / rel) == sha for rel, sha in candidate["test_files"].items())
    assert file_digest(INSTALLED / "config.lua") == old["config_sha256"] == record["config_sha256"]
    native = {p.name: file_digest(p) for p in sorted(INSTALLED.glob("*.dll"))}
    assert len(native) == 7 and native == old["native_files_preserved"] == record["native_files_preserved"]
    changed = {"Brainstorm/" + rel for rel in record["explicit_changed_files"]}
    assert changed == set(frozen["changed_runtime_files"])
    for folder in (CANDIDATE / "validation", VALIDATED):
        assert len(re.findall(r"^Running ", (folder / "lua.log").read_text(encoding="utf-8"), re.M)) == 246
        assert "Ran 391 tests" in (folder / "python.log").read_text(encoding="utf-8")

    manifest = read(COHORT / "capture/manifest.json")
    summary = read(COHORT / "capture/summary.json")
    runs = read(COHORT / "runs.json")
    assert len(manifest["inputs"]) == 25 and manifest["last_sequence"] == 19427
    assert manifest["last_at"] == "2026-09-23T19:26:13Z"
    assert not manifest["gaps"] and not manifest["errors"]
    assert all(item["stable"] and file_digest(ROOT / item["frozen"]) == item["sha256"]
               for item in manifest["inputs"])
    assert summary["versions"] == {"Brainstorm v2.171.0-alpha": 17608}
    assert summary["converter_error"] is None
    assert len(runs) == 10 and len({r["seed"] for r in runs}) == 10
    assert [sum(r["outcome"] == kind for r in runs) for kind in ("win", "loss", "unsupported")] == [2, 7, 1]

    cohort = {"loaded_public_label": "2.171.0-alpha", "profile": "perkeo_yorick_win_v1",
              "starts": 10, "distinct_seeds": 10, "verified_wins": 2,
              "verified_losses": 7, "unsupported": 1,
              "capture_cutoff_utc": manifest["last_at"],
              "last_sequence": manifest["last_sequence"],
              "report": address(COHORT / "REPORT.md"),
              "capture_manifest": address(COHORT / "capture/manifest.json"),
              "loaded_bytes_attested": False}
    checkpoint = {
        "release": 375, "version": record["version"],
        "installed_at": record["installed_at"], "installed": record["installed"],
        "backup": record["backup"], "config_sha256": record["config_sha256"],
        "native_files_preserved": native,
        "policy_digest": candidate["policy_digest"],
        "policy_files": candidate["policy_files"],
        "deployment_files": record["deployment_files"],
        "explicit_changed_files": sorted(changed),
        "candidate_validation": address(CANDIDATE / "validation/report.json"),
        "exact_installed_validation": address(VALIDATED / "report.json"),
        "installed_record": address(RELEASE / "record.json"),
        "loaded_cohort": cohort,
        "activation": "2.174 not confirmed; normal user restart required",
        "experiment_budget": "No new authorization; historical allowances closed",
    }
    checkpoint_path = EVAL / "SESSION_RESET_375.json"
    checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n", encoding="utf-8")

    docs = [ROOT / "ADVISOR_START_HERE.md", ROOT / "ADVISOR_RESUME_PROMPT.md",
            ROOT / "ADVISOR_HANDOFF.md", EVAL / "SESSION_RESET_375.md",
            checkpoint_path, EVAL / "NEXT_PRIORITIES_375.md",
            EVAL / "ARCHITECTURE_MAP_375.md", EVAL / "WIN_RATE_RESEARCH.md",
            EVAL / "development374/FAST_EVENT_CADENCE.md",
            EVAL / "development375/ACORN_REVIEW.md",
            EVAL / "development375/FOCUSED_VALIDATION.md",
            COHORT / "REPORT.md", COHORT / "UPDATE_SCOPE.md"]
    FINAL.mkdir(parents=True, exist_ok=True)
    final = {
        "verified_at_utc": datetime.now(timezone.utc).isoformat(),
        "version": record["version"],
        "policy_digest": candidate["policy_digest"],
        "deployment_file_count": len(record["deployment_files"]),
        "runtime_dependency_file_count": len(candidate["policy_files"]),
        "explicit_changed_files": sorted(changed),
        "candidate_lua_fixtures": 246, "candidate_python_tests": 391,
        "installed_lua_fixtures": 246, "installed_python_tests": 391,
        "candidate_passed": True, "exact_installed_passed": True,
        "test_hashes_equal": True, "config_unchanged": True,
        "seven_native_files_unchanged": True,
        "cohort_2_171_frozen": True,
        "loaded_2_174_confirmed": False,
        "documents": {str(path.relative_to(ROOT)).replace("\\", "/"): file_digest(path)
                      for path in docs},
        "saves": "Not read or written", "game_control": "None",
        "tool_started_runs": 0, "new_experiments": 0,
    }
    (FINAL / "final_verification.json").write_text(json.dumps(final, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": final["version"],
                      "deployment_files": len(record["deployment_files"]),
                      "runtime_files": len(candidate["policy_files"]),
                      "lua": 246, "python": 391,
                      "cohort": [2, 7, 1], "documents": len(docs)}))


if __name__ == "__main__":
    main()
