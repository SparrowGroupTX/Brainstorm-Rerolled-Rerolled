"""Attest the exact 2.183 installation and frozen regression gates."""
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
from benchmark import digest, file_digest, policy_hashes, policy_sources

BASE = EVAL / "SESSION_RESET_384.json"
PREINSTALL = EVAL / "development385/preinstall.json"
RUNS = EVAL / "runs"
PREFIX = "cash385"
VERSION = "2.183.0-alpha"
CHANGED = {"Brainstorm/Advisor/decision.lua", "Brainstorm/Advisor/strategy.lua",
           "Brainstorm/Core/Brainstorm.lua", "Brainstorm/steamodded_compat.lua"}


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_new(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def preserve(installed, preinstall):
    assert file_digest(installed / "config.lua") == preinstall["config_sha256_before"]
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == preinstall["native_files_preserved"]


def freeze_installed(installed, destination):
    destination.mkdir(parents=True, exist_ok=False)
    for source in policy_sources(installed.parent):
        target = destination / source.relative_to(installed.parent)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    hashes = policy_hashes(destination)
    assert hashes == policy_hashes(installed.parent)
    return hashes


def record(backup):
    base, preinstall = read(BASE), read(PREINSTALL)
    frozen = read(RUNS / f"{PREFIX}_candidate/freeze.json")
    gate = read(RUNS / f"{PREFIX}_candidate/validation/report.json")
    deployment = read(backup / "deployment.json")
    installed = Path(base["installed"])
    assert base["version"] == "2.182.0-alpha"
    assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert deployment["version"] == frozen["candidate_version"] == VERSION
    assert Path(deployment["backup"]).resolve() == backup.resolve()
    assert deployment["configSHA256"].lower() == preinstall["config_sha256_before"]
    assert preinstall["installed_baseline_policy_digest"] == base["policy_digest"]
    preserve(installed, preinstall)
    current, deployed_policy = policy_hashes(ROOT), policy_hashes(installed.parent)
    assert current == deployed_policy == gate["policy_files"] == frozen["candidate_policy_files"]
    assert digest(current) == gate["policy_digest"] == frozen["candidate_policy_digest"]
    deployed_files = {}
    for item in deployment["files"]:
        relative = item["path"].replace("\\", "/")
        expected = item["after"].lower()
        assert file_digest(installed / relative) == expected
        assert file_digest(ROOT / "Brainstorm" / relative) == expected
        deployed_files[relative] = expected
    changed = {"Brainstorm/" + rel for rel, sha in deployed_files.items()
               if sha != base["deployment_files"].get(rel)}
    assert changed == CHANGED == set(frozen["changed_runtime_files"])
    assert len(deployed_files) == 92 and len(deployed_policy) == 108
    out = RUNS / f"{PREFIX}_installed"
    assert freeze_installed(installed, out / "policy") == deployed_policy
    receipt = {
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "version": VERSION,
        "installed_at": deployment["installedAt"],
        "installed": str(installed),
        "backup": str(backup),
        "deployment_manifest": str(backup / "deployment.json"),
        "deployment_file_count": len(deployed_files),
        "deployment_files": deployed_files,
        "explicit_changed_files": sorted(rel.removeprefix("Brainstorm/") for rel in changed),
        "config_sha256": preinstall["config_sha256_before"],
        "native_files_preserved": preinstall["native_files_preserved"],
        "policy": {"policy_digest": digest(deployed_policy), "policy_files": deployed_policy},
        "activation": "Unconfirmed; next normal user restart required",
        "game_process_control": False,
        "save_or_profile_access": False,
    }
    write_new(out / "record.json", receipt)
    print(json.dumps({"version": VERSION, "digest": digest(deployed_policy),
                      "deployment_files": len(deployed_files), "runtime_files": len(deployed_policy),
                      "backup": str(backup)}))


def finalize():
    base, preinstall = read(BASE), read(PREINSTALL)
    frozen = read(RUNS / f"{PREFIX}_candidate/freeze.json")
    candidate = read(RUNS / f"{PREFIX}_candidate/validation/report.json")
    installed_gate = read(RUNS / f"{PREFIX}_installed_validation/report.json")
    receipt = read(RUNS / f"{PREFIX}_installed/record.json")
    for gate in (candidate, installed_gate):
        assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert candidate["policy_files"] == installed_gate["policy_files"] == receipt["policy"]["policy_files"] == frozen["candidate_policy_files"]
    assert candidate["policy_digest"] == installed_gate["policy_digest"] == receipt["policy"]["policy_digest"] == frozen["candidate_policy_digest"]
    assert candidate["test_files"] == installed_gate["test_files"]
    installed = Path(receipt["installed"])
    assert policy_hashes(ROOT) == policy_hashes(installed.parent) == candidate["policy_files"]
    assert all(file_digest(ROOT / rel) == sha for rel, sha in frozen["test_files"].items())
    preserve(installed, preinstall)
    counts = []
    for name in (f"{PREFIX}_candidate/validation", f"{PREFIX}_installed_validation"):
        folder = RUNS / name
        lua, python = (folder / "lua.log").read_text(encoding="utf-8"), (folder / "python.log").read_text(encoding="utf-8")
        match = re.search(r"Ran (\d+) tests", python)
        assert match
        counts.append((len(re.findall(r"^Running ", lua, re.M)), int(match.group(1))))
    assert counts == [(254, 392), (254, 392)]
    capture = EVAL / "development385/capture/manifest.json"
    shops = EVAL / "development385/capture/shops.json"
    assert file_digest(capture) == frozen["public_prefix_manifest_sha256"]
    assert file_digest(shops) == frozen["public_prefix_shops_sha256"]
    observation = read(capture)
    assert observation["events"] == 4020 and observation["last_sequence"] == 4020
    checkpoint = {
        "version": VERSION,
        "installed_at": receipt["installed_at"],
        "installed": receipt["installed"],
        "backup": receipt["backup"],
        "policy_digest": candidate["policy_digest"],
        "policy_files": candidate["policy_files"],
        "deployment_files": receipt["deployment_files"],
        "config_sha256": receipt["config_sha256"],
        "native_files_preserved": receipt["native_files_preserved"],
        "runtime_file_count": len(candidate["policy_files"]),
        "deployment_file_count": receipt["deployment_file_count"],
        "candidate_validation": str(RUNS / f"{PREFIX}_candidate/validation/report.json"),
        "installed_validation": str(RUNS / f"{PREFIX}_installed_validation/report.json"),
        "validation_counts": {"lua_fixtures": 254, "python_tests": 392},
        "latest_public_loaded_label": "2.182.0-alpha",
        "latest_public_profile": "perkeo_yorick_win_v1",
        "latest_public_capture_cutoff": observation["last_at"],
        "latest_public_capture_last_sequence": 4020,
        "latest_public_capture_complete_batch": False,
        "latest_public_report": str(EVAL / "development385/REPORT.md"),
        "latest_public_manifest_sha256": file_digest(capture),
        "latest_public_shops_sha256": file_digest(shops),
        "activation": "Unconfirmed; normal user restart required",
        "native_or_config_changed": False,
        "game_process_control": False,
        "saved_game_or_profile_access": False,
    }
    write_new(EVAL / "SESSION_RESET_385.json", checkpoint)
    final = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "version": VERSION,
        "candidate_policy_digest": candidate["policy_digest"],
        "installed_policy_digest": installed_gate["policy_digest"],
        "candidate_and_installed_gates_passed": True,
        "candidate_and_installed_test_hashes_match": True,
        "candidate_and_installed_policy_hashes_match": True,
        "deployment_files": receipt["deployment_file_count"],
        "runtime_dependency_files": len(candidate["policy_files"]),
        "lua_fixtures": counts[0][0],
        "python_tests": counts[0][1],
        "config_sha256": receipt["config_sha256"],
        "native_files_preserved": receipt["native_files_preserved"],
        "backup": receipt["backup"],
        "activation_confirmed": False,
        "public_prefix_manifest_sha256": file_digest(capture),
        "no_gameplay_experiment_or_game_control": True,
    }
    write_new(RUNS / f"{PREFIX}_final/final_verification.json", final)
    print(json.dumps({"version": VERSION, "digest": candidate["policy_digest"],
                      "counts": counts, "deployment_files": receipt["deployment_file_count"],
                      "runtime_files": len(candidate["policy_files"])}))


def main():
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
