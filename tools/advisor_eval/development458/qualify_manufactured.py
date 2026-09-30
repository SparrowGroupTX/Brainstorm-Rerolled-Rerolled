"""Freeze Booster opening callback-order comparison; no original source execution."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from tools.advisor_learning import simulator_patches as patches
from tools.advisor_learning.test_lifecycle_457 import SIM
from tools.advisor_learning.test_lifecycle_458 import compare_open


HERE = Path(__file__).resolve().parent


def main() -> None:
    patches.apply_patches(SIM)
    baseline = compare_open(baseline=True)
    repaired = compare_open()
    if baseline["first_difference"] != {
            "field": "events[0].stored_key", "expected": "USED",
            "actual": "p_arcana_normal_1"} or not repaired["agreement"]:
        raise RuntimeError("Opening callback-order comparison drift")
    prepared = json.loads((HERE / "SOURCE_PROBE_PREPARED.json").read_text(encoding="utf-8"))
    report = {
        "schema": "booster_open_order_manufactured_458_v1",
        "source_executed": False,
        "source_archive_sha256": prepared["source_archive_sha256"],
        "source_member_sha256": prepared["source_member_sha256"],
        "candidate_patch_id": patches.PATCH_ID,
        "baseline": baseline, "repaired": repaired,
        "qualifier_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    (HERE / "MANUFACTURED_COMPARISONS.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("Old callback-order mismatch preserved; repaired manufactured case agrees")


if __name__ == "__main__":
    main()
