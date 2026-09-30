"""Freeze, record, and verify the exact 2.177 copy-acquisition slice.

Read-only except new evidence/checkpoint files. Installation is separately
performed by install_slice.py with explicit file arguments.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes, policy_sources  # noqa: E402

INSTALLED = Path("C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm")
BASE = EVAL / "SESSION_RESET_377.json"
RUNS = EVAL / "runs"
PREFIX = "copy378"
VERSION = "2.177.0-alpha"
CHANGED = {
    "Brainstorm/Advisor/strategy.lua",
    "Brainstorm/Advisor/paid_reroll.lua",
    "Brainstorm/Advisor/player_journal.lua",
    "Brainstorm/Core/Brainstorm.lua",
    "Brainstorm/steamodded_compat.lua",
}
COHORT = EVAL / "win_rate_research/20260924_032258_ten_start"


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def address(path: Path) -> dict:
    return {"path": str(path.relative_to(ROOT)).replace("\\", "/"),
            "sha256": file_digest(path)}


def copy_policy(source_root: Path, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=False)
    for source in policy_sources(source_root):
        target = output / source.relative_to(source_root)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    frozen = policy_hashes(output)
    assert frozen == policy_hashes(source_root)
    return frozen


def preserve(base: dict) -> None:
    assert file_digest(INSTALLED / "config.lua") == base["config_sha256"]
    natives = {p.name: file_digest(p) for p in sorted(INSTALLED.glob("*.dll"))}
    assert len(natives) == 7 and natives == base["native_files_preserved"]


def freeze() -> None:
    base = read(BASE)
    assert base["version"] == "2.176.0-alpha"
    assert policy_hashes(INSTALLED.parent) == base["policy_files"]
    preserve(base)
    candidate = policy_hashes(ROOT)
    changed = {p for p in set(candidate) | set(base["policy_files"])
               if candidate.get(p) != base["policy_files"].get(p)}
    assert changed == CHANGED, sorted(changed)
    assert VERSION in (ROOT / "Brainstorm/Core/Brainstorm.lua").read_text(encoding="utf-8")
    assert f"--- VERSION: {VERSION}" in (ROOT / "Brainstorm/steamodded_compat.lua").read_text(encoding="utf-8")
    out = RUNS / f"{PREFIX}_candidate"
    assert copy_policy(ROOT, out / "policy") == candidate
    fixtures = {name: file_digest(ROOT / name) for name in (
        "tests/advisor_copy_acquisition378.lua",
        "tests/advisor_proactive_reroll371.lua",
        "tests/advisor_perishable_replacement377.lua",
        "tests/advisor_funded_copy371.lua", "tests/advisor_copy_target_rating375.lua")}
    record = {"created_utc": datetime.now(timezone.utc).isoformat(),
              "kind": "routine_candidate_validation_no_gameplay_experiment",
              "baseline_release": 377, "baseline_policy_digest": base["policy_digest"],
              "candidate_version": VERSION, "candidate_policy_digest": digest(candidate),
              "candidate_policy_files": candidate, "changed_runtime_files": sorted(changed),
              "focused_fixture_hashes": fixtures,
              "installed_377_matches_checkpoint": True,
              "installed_config_and_seven_native_files_preserved": True,
              "installed_not_modified": True}
    write(out / "freeze.json", record)
    print(json.dumps({"version": VERSION, "digest": digest(candidate),
                      "runtime_files": len(candidate), "changed": sorted(changed)}))


def record(backup: Path) -> None:
    base = read(BASE)
    frozen = read(RUNS / f"{PREFIX}_candidate/freeze.json")
    gate = read(RUNS / f"{PREFIX}_candidate/validation/report.json")
    deployment = read(backup / "deployment.json")
    assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert deployment["version"] == frozen["candidate_version"] == VERSION
    assert Path(deployment["backup"]).resolve() == backup.resolve()
    assert deployment["configSHA256"].lower() == base["config_sha256"]
    preserve(base)
    installed = policy_hashes(INSTALLED.parent)
    assert installed == gate["policy_files"] == frozen["candidate_policy_files"] == policy_hashes(ROOT)
    assert digest(installed) == gate["policy_digest"] == frozen["candidate_policy_digest"]
    deployed = {}
    for item in deployment["files"]:
        rel = item["path"].replace("\\", "/")
        expected = item["after"].lower()
        assert file_digest(INSTALLED / rel) == expected
        assert file_digest(ROOT / "Brainstorm" / rel) == expected
        deployed[rel] = expected
    changed = {"Brainstorm/" + rel for rel, sha in deployed.items()
               if sha != base["deployment_files"].get(rel)}
    assert changed == CHANGED, sorted(changed)
    out = RUNS / f"{PREFIX}_installed"
    assert copy_policy(INSTALLED.parent, out / "policy") == installed
    receipt = {"recorded_utc": datetime.now(timezone.utc).isoformat(),
               "version": VERSION, "installed_at": deployment["installedAt"],
               "installed": str(INSTALLED), "backup": str(backup),
               "deployment_manifest": str(backup / "deployment.json"),
               "deployment_file_count": len(deployed), "deployment_files": deployed,
               "explicit_changed_files": sorted(rel.removeprefix("Brainstorm/") for rel in changed),
               "all_repository_files_match": True, "config_sha256": base["config_sha256"],
               "native_files_preserved": base["native_files_preserved"],
               "policy": {"policy_digest": digest(installed), "policy_files": installed},
               "activation": "Unconfirmed; next normal user restart required",
               "game_process_control": False, "save_or_profile_access": False}
    write(out / "record.json", receipt)
    print(json.dumps({"version": VERSION, "digest": digest(installed),
                      "deployment_files": len(deployed), "runtime_files": len(installed),
                      "backup": str(backup)}))


def finalize() -> None:
    base = read(BASE)
    frozen = read(RUNS / f"{PREFIX}_candidate/freeze.json")
    candidate = read(RUNS / f"{PREFIX}_candidate/validation/report.json")
    installed_gate = read(RUNS / f"{PREFIX}_installed_validation/report.json")
    receipt = read(RUNS / f"{PREFIX}_installed/record.json")
    deployment = read(Path(receipt["deployment_manifest"]))
    assert candidate["passed"] and installed_gate["passed"]
    assert candidate["policy_files"] == installed_gate["policy_files"] == receipt["policy"]["policy_files"] == frozen["candidate_policy_files"]
    assert candidate["policy_digest"] == installed_gate["policy_digest"] == receipt["policy"]["policy_digest"] == frozen["candidate_policy_digest"]
    assert candidate["test_files"] == installed_gate["test_files"]
    assert policy_hashes(ROOT) == policy_hashes(INSTALLED.parent) == candidate["policy_files"]
    assert all(file_digest(ROOT / rel) == sha for rel, sha in candidate["test_files"].items())
    preserve(base)
    assert receipt["all_repository_files_match"] and len(deployment["files"]) == receipt["deployment_file_count"]
    counts = []
    for gate_dir in (RUNS / f"{PREFIX}_candidate/validation", RUNS / f"{PREFIX}_installed_validation"):
        lua = (gate_dir / "lua.log").read_text(encoding="utf-8")
        python = (gate_dir / "python.log").read_text(encoding="utf-8")
        fixture_count = len(re.findall(r"^Running ", lua, re.M))
        match = re.search(r"Ran (\d+) tests", python)
        assert match and fixture_count > 246
        counts.append((fixture_count, int(match.group(1))))
    assert counts[0] == counts[1]
    assert (COHORT / "REPORT.md").is_file() and (COHORT / "capture/manifest.json").is_file()
    cohort = {
        "loaded_public_label": "2.175.0-alpha", "profile": "perkeo_yorick_win_v1",
        "starts": 10, "distinct_seeds": 10, "verified_wins": 2,
        "verified_losses": 8, "unsupported": 0,
        "capture_cutoff_utc": "2026-09-24T04:08:01Z", "last_sequence": 17693,
        "report": address(COHORT / "REPORT.md"),
        "capture_manifest": address(COHORT / "capture/manifest.json"),
        "loaded_bytes_attested": False,
    }
    checkpoint = {
        "release": 378, "version": VERSION, "installed_at": receipt["installed_at"],
        "installed": receipt["installed"], "backup": receipt["backup"],
        "config_sha256": receipt["config_sha256"], "native_files_preserved": receipt["native_files_preserved"],
        "policy_digest": candidate["policy_digest"], "policy_files": candidate["policy_files"],
        "deployment_files": receipt["deployment_files"],
        "explicit_changed_files": sorted(CHANGED),
        "candidate_validation": address(RUNS / f"{PREFIX}_candidate/validation/report.json"),
        "exact_installed_validation": address(RUNS / f"{PREFIX}_installed_validation/report.json"),
        "installed_record": address(RUNS / f"{PREFIX}_installed/record.json"),
        "loaded_cohort": cohort,
        "activation": "2.177 not confirmed; normal user restart required",
        "experiment_budget": "No new authorization; historical allowances closed",
    }
    checkpoint_path = EVAL / "SESSION_RESET_378.json"
    write(checkpoint_path, checkpoint)
    docs = [ROOT / "ADVISOR_START_HERE.md", ROOT / "ADVISOR_RESUME_PROMPT.md",
            ROOT / "ADVISOR_HANDOFF.md", EVAL / "SESSION_RESET_378.md", checkpoint_path,
            EVAL / "NEXT_PRIORITIES_378.md", EVAL / "ARCHITECTURE_MAP_378.md",
            EVAL / "WIN_RATE_RESEARCH.md", EVAL / "development378/SCOPE.md",
            COHORT / "REPORT.md", COHORT / "capture/manifest.json"]
    final_dir = RUNS / f"{PREFIX}_final"
    final_dir.mkdir(parents=True, exist_ok=False)
    final = {"verified_at_utc": datetime.now(timezone.utc).isoformat(),
             "version": VERSION, "policy_digest": candidate["policy_digest"],
             "deployment_file_count": len(receipt["deployment_files"]),
             "runtime_dependency_file_count": len(candidate["policy_files"]),
             "explicit_changed_files": sorted(CHANGED),
             "candidate_lua_fixtures": counts[0][0], "candidate_python_tests": counts[0][1],
             "installed_lua_fixtures": counts[1][0], "installed_python_tests": counts[1][1],
             "candidate_passed": True, "exact_installed_passed": True,
             "test_hashes_equal": True, "config_unchanged": True,
             "seven_native_files_unchanged": True,
             "new_cohort_frozen": True, "loaded_2_175_label_confirmed": True,
             "loaded_2_176_confirmed": False,
             "loaded_2_177_confirmed": False,
             "documents": {str(path.relative_to(ROOT)).replace("\\", "/"): file_digest(path)
                           for path in docs},
             "saves": "Not read or written", "game_control": "None",
             "tool_started_runs": 0, "new_experiments": 0}
    write(final_dir / "final_verification.json", final)
    print(json.dumps({"version": VERSION, "digest": candidate["policy_digest"],
                      "deployment_files": len(receipt["deployment_files"]),
                      "runtime_files": len(candidate["policy_files"]),
                      "lua": counts[0][0], "python": counts[0][1]}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("step", choices=("freeze", "record", "finalize"))
    parser.add_argument("--backup", type=Path)
    args = parser.parse_args()
    if args.step == "freeze": freeze()
    elif args.step == "record":
        if not args.backup: parser.error("record requires --backup")
        record(args.backup)
    else: finalize()


if __name__ == "__main__":
    main()
