"""Attest the exact installed 2.194 slice and freeze its validation policy."""

from datetime import datetime, timezone
from pathlib import Path
import json
import shutil
import sys

EVAL = Path(__file__).resolve().parents[1]
ROOT = EVAL.parents[1]
sys.path.insert(0, str(EVAL))
from benchmark import digest, file_digest, policy_hashes, policy_sources

BASE = EVAL / "SESSION_RESET_397.json"
PRE = EVAL / "development400/preinstall.json"
FROZEN = EVAL / "runs/copydeath400_candidate2/freeze.json"
GATE = EVAL / "runs/copydeath400_candidate2/validation/report.json"
OUT = EVAL / "runs/copydeath400_installed"
BACKUP = Path(r"C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260926-111624")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    base, pre, frozen, gate = map(read, (BASE, PRE, FROZEN, GATE))
    deployment = read(BACKUP / "deployment.json")
    installed = Path(base["installed"])
    assert deployment["version"] == frozen["candidate_version"] == "2.194.0-alpha"
    assert Path(deployment["backup"]).resolve() == BACKUP.resolve()
    assert gate["passed"] and gate["policy_unchanged"] and gate["tests_unchanged"]
    assert deployment["configSHA256"].lower() == pre["config_sha256_before"]
    assert file_digest(installed / "config.lua") == pre["config_sha256_before"]
    natives = {p.name: file_digest(p) for p in sorted(installed.glob("*.dll"))}
    assert len(natives) == 7 and natives == pre["native_files_preserved"]
    assert pre["installed_baseline_policy_digest"] == base["policy_digest"]
    current, deployed = policy_hashes(ROOT), policy_hashes(installed.parent)
    assert current == deployed == gate["policy_files"] == frozen["candidate_policy_files"]
    assert digest(current) == gate["policy_digest"] == frozen["candidate_policy_digest"]
    deployment_files = {}
    for item in deployment["files"]:
        rel = item["path"].replace("\\", "/")
        expected = item["after"].lower()
        assert file_digest(installed / rel) == expected
        assert file_digest(ROOT / "Brainstorm" / rel) == expected
        deployment_files[rel] = expected
    changed = {"Brainstorm/" + rel for rel, sha in deployment_files.items()
               if sha != base["deployment_files"].get(rel)}
    assert changed == set(pre["changed_runtime_files"]) == set(frozen["changed_runtime_files"])
    assert len(deployment_files) == 93 and len(deployed) == 109
    policy_dir = OUT / "policy"
    policy_dir.mkdir(parents=True, exist_ok=False)
    for source in policy_sources(installed.parent):
        target = policy_dir / source.relative_to(installed.parent)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    assert policy_hashes(policy_dir) == deployed
    record = {
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "version": frozen["candidate_version"],
        "installed_at": deployment["installedAt"],
        "installed": str(installed), "backup": str(BACKUP),
        "deployment_manifest": str(BACKUP / "deployment.json"),
        "deployment_file_count": len(deployment_files),
        "deployment_files": deployment_files,
        "explicit_changed_files": sorted(rel.removeprefix("Brainstorm/") for rel in changed),
        "config_sha256": pre["config_sha256_before"],
        "native_files_preserved": natives,
        "policy": {"policy_digest": digest(deployed), "policy_files": deployed},
        "activation": "Unconfirmed; next normal user restart required",
        "game_process_control": False, "save_or_profile_access": False,
    }
    with (OUT / "record.json").open("x", encoding="utf-8") as stream:
        json.dump(record, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"version": record["version"], "digest": digest(deployed),
                      "deployment_files": len(deployment_files),
                      "runtime_files": len(deployed), "backup": str(BACKUP)}))


if __name__ == "__main__":
    main()
