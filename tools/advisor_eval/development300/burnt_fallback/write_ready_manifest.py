"""Record detached bytes and exact current306 integration baseline; no runtime writes."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
DRAFT = Path(__file__).resolve().parent
PREFIX = "tools/advisor_eval/development300/burnt_fallback/"
RUNTIME = ["Brainstorm/Advisor/collection_search.lua", "Brainstorm/Core/collection_search_product.lua",
           "Brainstorm/Core/auto_run_product.lua", "Brainstorm/UI/collection_run.lua"]
TESTS = ["tests/advisor_collection_query.lua", "tests/advisor_adaptive_quota.lua",
         "tests/advisor_auto_run_product.lua", "tests/advisor_collection_product.lua",
         "tests/advisor_burnt_fallback.lua", "tests/advisor_collection_status.lua"]

def sha(data):
    return hashlib.sha256(data).hexdigest()

record = ROOT / "tools/advisor_eval/runs/quota306_installed/record.json"
assert record.is_file()
validation_record = ROOT / "tools/advisor_eval/runs/quota306_installed_validation/report.json"
installed = json.loads(record.read_text(encoding="utf-8"))
validation = json.loads(validation_record.read_text(encoding="utf-8"))
baseline_hashes = dict(installed["policy"]["policy_files"])
baseline_hashes.update({key.replace("\\", "/"): value for key, value in validation["test_files"].items()})
rows = []
for relative in RUNTIME + TESTS:
    draft = (DRAFT / relative).read_bytes()
    normalized = draft.replace(PREFIX.encode(), b"") if relative in TESTS else draft
    baseline = ROOT / relative
    rows.append({"path": relative, "kind": "runtime" if relative in RUNTIME else "fixture",
                 "draft_sha256": sha(draft), "staged_sha256": sha(normalized),
                 "baseline306_sha256": baseline_hashes.get(relative),
                 "worktree_observed_sha256": sha(baseline.read_bytes()) if baseline.exists() else None,
                 "draft_bytes": len(draft), "staged_bytes": len(normalized)})
manifest = {"schema": 1, "baseline_record": record.relative_to(ROOT).as_posix(),
            "baseline_record_sha256": sha(record.read_bytes()), "files": rows,
            "baseline_validation_record": validation_record.relative_to(ROOT).as_posix(),
            "baseline_validation_sha256": sha(validation_record.read_bytes()),
            "supersedes": "ready307_manifest.json: draft and normalized staging hashes remain correct; its baseline306 fields accidentally sampled worktree after concurrent root staging. Use frozen306 provenance here.",
            "fixture_path_rewrite": {"from": PREFIX, "to": ""},
            "validation": {"fixtures_passed": 6, "checks": 482,
                           "native_execution": False, "source_execution": False},
            "runtime_or_test_files_written": False,
            "notes": "Four runtime modules; three updated, one unchanged and two new synthetic fixtures. No DLL or Core hook change."}
with (DRAFT / "ready307_manifest_v2.json").open("x", encoding="utf-8", newline="\n") as stream:
    json.dump(manifest, stream, indent=2)
    stream.write("\n")
print(json.dumps(manifest, indent=2))
