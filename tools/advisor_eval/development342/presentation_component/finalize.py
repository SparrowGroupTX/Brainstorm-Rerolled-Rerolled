"""Seal the reviewed staged payload and preserved manufactured-test receipts."""
from pathlib import Path
import hashlib
import json

stage = Path(__file__).resolve().parent
root = stage.parents[3]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
before = json.loads((stage / "before_hashes.json").read_text(encoding="utf-8-sig"))
files = []
for item in before["files"]:
    path = item["path"]
    assert sha(stage / "before" / path) == item["sha256"], path
    assert sha(root / path) == item["sha256"], f"Production changed before integration: {path}"
    files.append({"destination": path, "staged_path": str((stage / path).relative_to(root)).replace("\\", "/"),
                  "kind": "test" if path.startswith("tests/") else "runtime",
                  "before_sha256": item["sha256"], "after_sha256": sha(stage / path)})
evidence = json.loads((stage / "validation_01_evidence.json").read_text(encoding="utf-8"))
receipts = []
for name in ("before", "staged"):
    path = stage / f"validation_01_{name}.json"
    receipt = json.loads(path.read_text(encoding="utf-8"))
    receipts.append({"path": str(path.relative_to(root)).replace("\\", "/"), "sha256": sha(path),
                     "exit_code": receipt["exit_code"], "expected_failure": name == "before"})
assert receipts[0]["exit_code"] == 1 and receipts[1]["exit_code"] == 0
result = {
    "schema": 1, "status": "staged_review_ready", "production_paths_written": False,
    "scope": "Persistent Card.flipping presentation lifecycle; Acorn observer, Snapshot redaction, Gold held inventory",
    "files": files,
    "validation": {"receipts": receipts, "manufactured_checks": {"acorn_public": 190, "gold_stickers": 334},
                   "before_failure": "Settled source-shaped backs fail to narrow six identity worlds to two",
                   "source_execution": False, "live_game": False, "captured_replay": False,
                   "source_archive_read": False, "search_experiment": False},
    "source_provenance": evidence["sources"],
    "source_binding_receipt": {"path": str((stage / "validation_01_evidence.json").relative_to(root)).replace("\\", "/"),
                               "sha256": sha(stage / "validation_01_evidence.json")},
    "behavior": [
        "A directed flip is settled only when logical and rendered facing match its target and pinch.x is explicitly false.",
        "Nil-flipping legacy cards remain accepted unless pinch is active or malformed.",
        "Settled backs admit public status/juice observation, certified reorder and observed drag without reading hidden identity.",
        "Settled fronts retire concealed belief, can be remembered again, and are available to Snapshot/opt-in Gold capture.",
        "Unknown/missing/mismatched transition fields and explicit redaction remain conservative.",
        "Gold retains raw get/plain safety and public-memory fallback; no runtime loader dependencies added."
    ],
    "integration": "Copy only listed runtime/tests after verifying destination hashes equal before_sha256; verify copied hashes equal after_sha256. Root owns release/version/docs and installation."
}
with (stage / "result.json").open("x", encoding="utf-8") as output:
    json.dump(result, output, indent=2)
    output.write("\n")
print(json.dumps({"result": str(stage / "result.json"), "sha256": sha(stage / "result.json"), "files": len(files)}))
