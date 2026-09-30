"""Freeze the verified 2.192 installation and copied public-cohort receipt.

This is a read-only installation check; it writes evidence only inside this
repository. It does not control the game, alter settings, or replay policy.
"""

from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes

BASE = EVAL / "runs/concealed396"
FINAL = EVAL / "runs/concealed396_final"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def slash_keys(files):
    return {name.replace("\\", "/"): value for name, value in files.items()}


def main():
    record = read(Path(str(BASE) + "_installed/record.json"))
    candidate = read(Path(str(BASE) + "_candidate/validation/report.json"))
    installed_gate = read(Path(str(BASE) + "_installed_validation/report.json"))
    freeze = read(Path(str(BASE) + "_candidate/freeze.json"))
    manifest_path = Path(record["deployment_manifest"])
    manifest = read(manifest_path)
    cohort = read(EVAL / "development396/capture/verification.json")
    capture_manifest = EVAL / "development396/capture/manifest.json"
    config_before = read(EVAL / "development396/preinstall.json")
    assert candidate["passed"] and installed_gate["passed"]
    assert candidate["policy_unchanged"] and candidate["tests_unchanged"]
    assert installed_gate["policy_unchanged"] and installed_gate["tests_unchanged"]
    expected = freeze["candidate_policy_digest"]
    assert expected == record["policy"]["policy_digest"] == candidate["policy_digest"] == installed_gate["policy_digest"]
    assert candidate["policy_files"] == installed_gate["policy_files"] == freeze["candidate_policy_files"]
    assert slash_keys(candidate["test_files"]) == slash_keys(installed_gate["test_files"]) == slash_keys(freeze["test_files"])
    assert len(candidate["test_files"]) == 302
    current_tests = {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p)
                     for p in sorted((ROOT / "tests").rglob("*"))
                     if p.is_file() and (p.suffix == ".lua" or
                                         p.name.startswith("test_advisor_") and p.suffix == ".py")}
    assert current_tests == slash_keys(candidate["test_files"])
    installed = Path(record["installed"])
    assert policy_hashes(ROOT) == policy_hashes(installed.parent) == record["policy"]["policy_files"]
    assert digest(record["policy"]["policy_files"]) == expected
    assert policy_hashes(Path(str(BASE) + "_installed/policy")) == record["policy"]["policy_files"]
    assert len(record["policy"]["policy_files"]) == 108
    assert record["deployment_file_count"] == 92
    for rel, expected_file_sha in record["deployment_files"].items():
        assert file_digest(installed / rel) == expected_file_sha == file_digest(ROOT / "Brainstorm" / rel)
    assert manifest["installedAt"] == record["installed_at"]
    assert manifest["configSHA256"].lower() == record["config_sha256"] == config_before["config_sha256_before"]
    assert file_digest(installed / "config.lua") == record["config_sha256"]
    native = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(native) == 7 and native == record["native_files_preserved"] == config_before["native_files_preserved"]
    lua = (Path(str(BASE) + "_installed_validation/lua.log")).read_text(encoding="utf-8")
    py = (Path(str(BASE) + "_installed_validation/python.log")).read_text(encoding="utf-8")
    lua_count = re.findall(r"(\d+)/(\d+) fixtures passed", lua)
    py_count = re.findall(r"Ran (\d+) tests", py)
    assert lua_count and lua_count[-1] == ("262", "262") and py_count and py_count[-1] == "392"
    assert len(cohort["starts"]) == len(cohort["endings"]) == 10
    assert cohort["outcome_counts"] == {"loss": 5, "win": 4, "unsupported": 1}
    assert cohort["events"] == 24635 and len(cohort["segments"]) == 27
    assert cohort["versions"] == {"Brainstorm v2.191.0-alpha": 21766}
    assert cohort["profiles"] == {"perkeo_yorick_win_v1": 3643}
    assert all(x["sha256"] == y["sha256"] for x, y in zip(read(capture_manifest)["segments"], cohort["segments"]))
    assert all(x["last_sequence"] + 1 == y["first_sequence"] for x, y in zip(cohort["segments"], cohort["segments"][1:]))
    FINAL.mkdir(exist_ok=False)
    verification = {
        "verified_utc": datetime.now(timezone.utc).isoformat(),
        "version": record["version"], "installed_at": record["installed_at"],
        "policy_digest": expected, "deployment_file_count": 92,
        "runtime_dependency_file_count": 108, "test_file_count": 302,
        "candidate_validation": str(Path(str(BASE) + "_candidate/validation/report.json")),
        "installed_validation": str(Path(str(BASE) + "_installed_validation/report.json")),
        "validation_counts": {"lua_fixtures": 262, "python_tests": 392},
        "candidate_and_installed_passed": True,
        "all_repository_and_installed_files_match": True,
        "config_sha256": record["config_sha256"], "native_files_preserved": native,
        "backup": record["backup"], "deployment_manifest_sha256": sha(manifest_path),
        "public_capture_manifest_sha256": sha(capture_manifest),
        "public_capture_last_sequence": cohort["segments"][-1]["last_sequence"],
        "public_outcomes": cohort["outcome_counts"],
        "public_loaded_label": "2.191.0-alpha",
        "public_profile": "perkeo_yorick_win_v1",
        "activation": "Unconfirmed; normal user restart required",
        "native_or_config_changed": False, "game_process_control": False,
        "saved_game_or_profile_access": False,
    }
    (FINAL / "final_verification.json").write_text(json.dumps(verification, indent=2) + "\n", encoding="utf-8")
    reset = {
        "version": record["version"], "installed_at": record["installed_at"],
        "installed": record["installed"], "backup": record["backup"],
        "policy_digest": expected, "policy_files": record["policy"]["policy_files"],
        "deployment_files": record["deployment_files"],
        "config_sha256": record["config_sha256"], "native_files_preserved": native,
        "runtime_file_count": 108, "deployment_file_count": 92,
        "candidate_validation": verification["candidate_validation"],
        "installed_validation": verification["installed_validation"],
        "validation_counts": verification["validation_counts"],
        "latest_public_loaded_label": verification["public_loaded_label"],
        "latest_public_profile": verification["public_profile"],
        "latest_public_capture_last_sequence": verification["public_capture_last_sequence"],
        "latest_public_capture_complete_batch": True,
        "latest_public_manifest_sha256": verification["public_capture_manifest_sha256"],
        "latest_public_starts": 10, "latest_public_endings": cohort["outcome_counts"],
        "activation": verification["activation"],
        "native_or_config_changed": False, "game_process_control": False,
        "saved_game_or_profile_access": False,
    }
    (EVAL / "SESSION_RESET_397.json").write_text(json.dumps(reset, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": record["version"], "digest": expected,
                      "lua_fixtures": 262, "python_tests": 392,
                      "public_starts": 10, "public_outcomes": cohort["outcome_counts"]}))


if __name__ == "__main__":
    main()
