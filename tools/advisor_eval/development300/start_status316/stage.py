"""Describe, or explicitly stage, the four reviewed status-observation files.

No installation, workers, native search, game access, fixture execution or commits.
Each original byte stream is preserved in base_bytes before this helper can run.
"""
from pathlib import Path
import argparse
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PATHS = (
    "Brainstorm/Core/collection_search_product.lua",
    "Brainstorm/Core/auto_run_product.lua",
    "tests/advisor_collection_product.lua",
    "tests/advisor_auto_run_product.lua",
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_plan(root=ROOT, package=HERE):
    root, package = root.resolve(), package.resolve()
    manifest_bytes = (package / "stage_manifest.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    if tuple(row["path"] for row in manifest["files"]) != PATHS:
        raise ValueError("Unexpected staging manifest paths")
    if (package / "stage_receipt.json").exists():
        raise ValueError("This package already has a staging receipt; review it instead of replaying")
    evidence = manifest["validation"]
    if evidence["path"] != "test_record.json":
        raise ValueError("Unexpected validation evidence path")
    if sha((package / evidence["path"]).read_bytes()) != evidence["sha256"]:
        raise ValueError("Detached validation record changed")
    for row in manifest["files"]:
        rel = row["path"]
        destination = (root / rel).resolve()
        if not destination.is_relative_to(root):
            raise ValueError("Destination escaped workspace")
        base = (package / "base_bytes" / rel).read_bytes()
        candidate = (package / rel).read_bytes()
        if sha(base) != row["base_sha256"] or len(base) != row["base_bytes"]:
            raise ValueError("Preserved base bytes changed: " + rel)
        if sha(candidate) != row["candidate_sha256"] or len(candidate) != row["candidate_bytes"]:
            raise ValueError("Detached candidate changed: " + rel)
        if sha(destination.read_bytes()) != row["base_sha256"]:
            raise ValueError("Workspace file differs from reviewed base; do not overwrite: " + rel)
    return manifest, sha(manifest_bytes)


def stage(root=ROOT, package=HERE):
    manifest, digest = checked_plan(root, package)
    receipt_path = package / "stage_receipt.json"
    receipt = {"schema": 1, "status": "staging", "manifest_sha256": digest,
               "scope": "Explicit parent staging only; no installation or evaluation",
               "preserved_originals": "base_bytes/", "written": []}
    # Reserve before any workspace mutation. Partial failure remains visible and
    # is never automatically replayed or rolled back across another user's edit.
    with receipt_path.open("x", encoding="utf-8") as stream:
        json.dump(receipt, stream, indent=2)
        stream.write("\n")
    try:
        for row in manifest["files"]:
            rel = row["path"]
            destination = root / rel
            if sha(destination.read_bytes()) != row["base_sha256"]:
                raise ValueError("Workspace file changed after preflight: " + rel)
            candidate = (package / rel).read_bytes()
            if sha(candidate) != row["candidate_sha256"]:
                raise ValueError("Candidate changed after preflight: " + rel)
            destination.write_bytes(candidate)
            actual = sha(destination.read_bytes())
            if actual != row["candidate_sha256"]:
                raise ValueError("Written hash mismatch: " + rel)
            receipt["written"].append({"path": rel, "sha256": actual})
        receipt["status"] = "staged"
    except Exception as error:
        receipt["status"] = "failed_partial_stage"
        receipt["error"] = str(error)
        raise
    finally:
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--describe", action="store_true")
    modes.add_argument("--stage", action="store_true")
    args = parser.parse_args()
    if args.stage:
        result = stage()
    else:
        result, digest = checked_plan()
        result = {"status": "ready_not_staged", "manifest_sha256": digest, "plan": result}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
