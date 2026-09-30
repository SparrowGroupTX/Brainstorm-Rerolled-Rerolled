"""Verify the exact 2.182 installation and its frozen regression gates.

Read-only except new evidence/checkpoint files. Installation is performed only
by install_slice.py with explicit runtime file arguments.
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
BASE = EVAL / "SESSION_RESET_382.json"
RUNS = EVAL / "runs"
PREFIX = "win384"
CANDIDATE = f"{PREFIX}_candidate"
VERSION = "2.182.0-alpha"


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def preserve(preinstall: dict) -> None:
    assert file_digest(INSTALLED / "config.lua") == preinstall["config_sha256"]
    natives = {p.name: file_digest(p) for p in sorted(INSTALLED.glob("*.dll"))}
    assert len(natives) == 7 and natives == preinstall["native_files_preserved"]


def freeze_installed(destination: Path) -> dict:
    destination.mkdir(parents=True, exist_ok=False)
    for source in policy_sources(INSTALLED.parent):
        target = destination / source.relative_to(INSTALLED.parent)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    hashes = policy_hashes(destination)
    assert hashes == policy_hashes(INSTALLED.parent)
    return hashes


def record(backup: Path) -> None:
    base = read(BASE)
    preinstall = read(EVAL / "development384/preinstall.json")
    frozen = read(RUNS / f"{CANDIDATE}/freeze.json")
    gate = read(RUNS / f"{CANDIDATE}/validation/report.json")
    deployment = read(backup / "deployment.json")
    assert base["version"] == "2.180.0-alpha"
    assert all(gate[key] is True for key in ("passed", "policy_unchanged", "tests_unchanged"))
    assert deployment["version"] == frozen["candidate_version"] == VERSION
    assert Path(deployment["backup"]).resolve() == backup.resolve()
    assert deployment["configSHA256"].lower() == preinstall["config_sha256"]
    assert preinstall["baseline_policy_digest"] == base["policy_digest"]
    preserve(preinstall)
    current = policy_hashes(ROOT)
    installed = policy_hashes(INSTALLED.parent)
    assert installed == current == gate["policy_files"] == frozen["candidate_policy_files"]
    assert digest(installed) == gate["policy_digest"] == frozen["candidate_policy_digest"]
    deployed = {}
    for item in deployment["files"]:
        relative = item["path"].replace("\\", "/")
        expected = item["after"].lower()
        assert file_digest(INSTALLED / relative) == expected
        assert file_digest(ROOT / "Brainstorm" / relative) == expected
        deployed[relative] = expected
    changed = {"Brainstorm/" + relative for relative, sha in deployed.items()
               if sha != base["deployment_files"].get(relative)}
    assert changed == set(frozen["changed_runtime_files"]), sorted(changed)
    assert len(changed) == 9 and len(deployed) == 92 and len(installed) == 108
    out = RUNS / f"{PREFIX}_installed"
    assert freeze_installed(out / "policy") == installed
    receipt = {
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "version": VERSION, "installed_at": deployment["installedAt"],
        "installed": str(INSTALLED), "backup": str(backup),
        "deployment_manifest": str(backup / "deployment.json"),
        "deployment_file_count": len(deployed), "deployment_files": deployed,
        "explicit_changed_files": sorted(relative.removeprefix("Brainstorm/") for relative in changed),
        "all_repository_files_match": True, "config_sha256": preinstall["config_sha256"],
        "native_files_preserved": preinstall["native_files_preserved"],
        "policy": {"policy_digest": digest(installed), "policy_files": installed},
        "activation": "Unconfirmed; next normal user restart required",
        "game_process_control": False, "save_or_profile_access": False,
    }
    write(out / "record.json", receipt)
    print(json.dumps({"version": VERSION, "digest": digest(installed),
                      "deployment_files": len(deployed), "runtime_files": len(installed),
                      "backup": str(backup)}))


def finalize() -> None:
    base = read(BASE)
    preinstall = read(EVAL / "development384/preinstall.json")
    frozen = read(RUNS / f"{CANDIDATE}/freeze.json")
    candidate = read(RUNS / f"{CANDIDATE}/validation/report.json")
    installed_gate = read(RUNS / f"{PREFIX}_installed_validation/report.json")
    receipt = read(RUNS / f"{PREFIX}_installed/record.json")
    assert all(g[key] is True for g in (candidate, installed_gate)
               for key in ("passed", "policy_unchanged", "tests_unchanged"))
    assert candidate["policy_files"] == installed_gate["policy_files"] == receipt["policy"]["policy_files"] == frozen["candidate_policy_files"]
    assert candidate["policy_digest"] == installed_gate["policy_digest"] == receipt["policy"]["policy_digest"] == frozen["candidate_policy_digest"]
    assert candidate["test_files"] == installed_gate["test_files"]
    assert policy_hashes(ROOT) == policy_hashes(INSTALLED.parent) == candidate["policy_files"]
    assert all(file_digest(ROOT / rel) == sha for rel, sha in candidate["test_files"].items())
    preserve(preinstall)
    counts = []
    for name in (f"{CANDIDATE}/validation", f"{PREFIX}_installed_validation"):
        folder = RUNS / name
        lua = (folder / "lua.log").read_text(encoding="utf-8")
        python = (folder / "python.log").read_text(encoding="utf-8")
        match = re.search(r"Ran (\d+) tests", python)
        assert match
        counts.append((len(re.findall(r"^Running ", lua, re.M)), int(match.group(1))))
    assert counts == [(254, 392), (254, 392)]
    capture = EVAL / "development384/capture/summary.json"
    observed = read(capture)
    assert observed["converter_error"] is None
    assert observed["converter"]["counts"]["events"] == 18179
    assert observed["converter"]["counts"]["wins"] == 1
    assert observed["converter"]["counts"]["losses"] == 8
    assert observed["converter"]["counts"]["unsupported"] == 1
    assert file_digest(capture) == frozen["public_capture_summary_sha256"]
    manifest = EVAL / "development384/logs1/manifest.json"
    assert file_digest(manifest) == frozen["public_log_manifest_sha256"]
    checkpoint = {
        "version": VERSION, "installed_at": receipt["installed_at"],
        "installed": receipt["installed"], "backup": receipt["backup"],
        "policy_digest": candidate["policy_digest"], "policy_files": candidate["policy_files"],
        "deployment_files": receipt["deployment_files"],
        "config_sha256": receipt["config_sha256"],
        "native_files_preserved": receipt["native_files_preserved"],
        "runtime_file_count": len(candidate["policy_files"]),
        "deployment_file_count": receipt["deployment_file_count"],
        "candidate_validation": str(RUNS / f"{CANDIDATE}/validation/report.json"),
        "installed_validation": str(RUNS / f"{PREFIX}_installed_validation/report.json"),
        "validation_counts": {"lua_fixtures": 254, "python_tests": 392},
        "latest_public_loaded_label": "2.180.0-alpha",
        "latest_public_profile": "perkeo_yorick_win_v1",
        "latest_public_capture_cutoff": "2026-09-25T15:28:39Z",
        "latest_public_capture_last_sequence": 18179,
        "latest_public_report": str(EVAL / "development384/REPORT.md"),
        "latest_public_outcomes": {"starts": 10, "wins": 1, "losses": 8, "unsupported": 1},
        "latest_public_manifest_sha256": file_digest(manifest),
        "latest_public_capture_sha256": file_digest(capture),
        "incorporated_cadence383_candidate_digest": frozen["incorporated_cadence383_candidate_digest"],
        "activation": "Unconfirmed; normal user restart required",
        "native_or_config_changed": False, "game_process_control": False,
        "saved_game_or_profile_access": False,
    }
    write(EVAL / "SESSION_RESET_384.json", checkpoint)
    final = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "version": VERSION, "candidate_policy_digest": candidate["policy_digest"],
        "installed_policy_digest": installed_gate["policy_digest"],
        "candidate_and_installed_gates_passed": True,
        "candidate_and_installed_test_hashes_match": True,
        "candidate_and_installed_policy_hashes_match": True,
        "deployment_files": receipt["deployment_file_count"],
        "runtime_dependency_files": len(candidate["policy_files"]),
        "lua_fixtures": counts[0][0], "python_tests": counts[0][1],
        "config_sha256": receipt["config_sha256"],
        "native_files_preserved": receipt["native_files_preserved"],
        "backup": receipt["backup"], "activation_confirmed": False,
        "public_log_manifest_sha256": file_digest(manifest),
        "public_capture_summary_sha256": file_digest(capture),
        "no_gameplay_experiment_or_game_control": True,
    }
    write(RUNS / f"{PREFIX}_final/final_verification.json", final)
    print(json.dumps({"version": VERSION, "digest": candidate["policy_digest"],
                      "counts": counts, "deployment_files": receipt["deployment_file_count"],
                      "runtime_files": len(candidate["policy_files"])}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    sub.add_parser("finalize")
    sub.add_parser("record").add_argument("--backup", required=True, type=Path)
    args = parser.parse_args()
    if args.mode == "record":
        record(args.backup)
    else:
        finalize()


if __name__ == "__main__":
    main()
