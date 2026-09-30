"""Freeze and verify exact 2.174 installed runtime bytes; no game access."""

from datetime import datetime, timezone
from pathlib import Path
import json
import shutil
import sys


EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes, policy_sources  # noqa: E402


INSTALLED = Path("C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm")
BACKUP = INSTALLED / "deployment-backups/advisor-20260923-153123"
CANDIDATE = EVAL / "runs/marathon375_candidate"
OUT = EVAL / "runs/marathon375_installed"


def main():
    old = json.loads((EVAL / "SESSION_RESET_371.json").read_text(encoding="utf-8"))
    frozen = json.loads((CANDIDATE / "freeze.json").read_text(encoding="utf-8"))
    gate = json.loads((CANDIDATE / "validation/report.json").read_text(encoding="utf-8"))
    deployment = json.loads((BACKUP / "deployment.json").read_text(encoding="utf-8"))
    assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert deployment["version"] == frozen["candidate_version"] == "2.174.0-alpha"
    assert Path(deployment["backup"]).resolve() == BACKUP.resolve()
    assert file_digest(INSTALLED / "config.lua") == old["config_sha256"] == deployment["configSHA256"].lower()
    natives = {p.name: file_digest(p) for p in sorted(INSTALLED.glob("*.dll"))}
    assert len(natives) == 7 and natives == old["native_files_preserved"]
    installed = policy_hashes(INSTALLED.parent)
    assert installed == gate["policy_files"] == frozen["candidate_policy_files"] == policy_hashes(ROOT)
    assert digest(installed) == gate["policy_digest"] == frozen["candidate_policy_digest"]

    deployed = {}
    for item in deployment["files"]:
        relative = item["path"].replace("\\", "/")
        expected = item["after"].lower()
        assert file_digest(INSTALLED / relative) == expected
        assert file_digest(ROOT / "Brainstorm" / relative) == expected
        deployed[relative] = expected
    assert len(deployed) == len(deployment["files"]) == 91
    changed = {relative for relative, sha in deployed.items()
               if sha != old["deployment_files"].get(relative)}
    assert {"Brainstorm/" + relative for relative in changed} == set(frozen["changed_runtime_files"])

    OUT.mkdir(parents=True, exist_ok=False)
    for source in policy_sources(INSTALLED.parent):
        destination = OUT / "policy" / source.relative_to(INSTALLED.parent)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    assert policy_hashes(OUT / "policy") == installed
    record = {
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "version": deployment["version"],
        "installed_at": deployment["installedAt"],
        "installed": str(INSTALLED),
        "backup": str(BACKUP),
        "deployment_manifest": str(BACKUP / "deployment.json"),
        "deployment_file_count": len(deployed),
        "deployment_files": deployed,
        "explicit_changed_files": sorted(changed),
        "all_repository_files_match": True,
        "config_sha256": old["config_sha256"],
        "native_files_preserved": natives,
        "policy": {"policy_digest": digest(installed), "policy_files": installed},
        "activation": "Unconfirmed; next normal user restart required",
        "game_process_control": False,
        "save_or_profile_access": False,
    }
    (OUT / "record.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"version": record["version"], "policy_digest": digest(installed),
                      "deployment_files": len(deployed), "runtime_files": len(installed),
                      "changed": sorted(changed), "config_preserved": True,
                      "native_files_preserved": len(natives)}))


if __name__ == "__main__":
    main()
