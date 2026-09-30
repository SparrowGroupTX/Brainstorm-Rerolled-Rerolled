"""Preserve baseline and repaired cash-out/shop bookkeeping comparisons."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import zipfile

from tools.advisor_learning import simulator_patches as patches
from tools.advisor_learning.lifecycle_contract import compare_lifecycle
from tools.advisor_learning.lifecycle_reference_455 import source_rule_reference
from tools.advisor_learning.test_lifecycle_455 import (
    SIM, candidate_transition, cases, compare_case, manifest,
)

HERE = Path(__file__).resolve().parent
ARCHIVE = Path("C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe")
ARCHIVE_SHA256 = "0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47"
BUTTON_SHA256 = "c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101"


def main() -> None:
    if hashlib.sha256(ARCHIVE.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise RuntimeError("Original source archive drift")
    with zipfile.ZipFile(ARCHIVE) as source:
        actual = hashlib.sha256(source.read("functions/button_callbacks.lua")).hexdigest()
    if actual != BUTTON_SHA256:
        raise RuntimeError("Original cash-out callback drift")

    patches.apply_patches(SIM)
    fixtures = cases()
    baseline = []
    repaired = []
    for fixture in fixtures.values():
        baseline.append({
            "comparison": compare_case(fixture, baseline=True),
            "expected": source_rule_reference(fixture),
            "actual": candidate_transition(fixture, baseline=True),
        })
        repaired.append({
            "comparison": compare_case(fixture),
            "expected": source_rule_reference(fixture),
            "actual": candidate_transition(fixture),
        })
    (HERE / "BASELINE_COMPARISONS.json").write_text(
        json.dumps({"status": "preserved_pinned_mismatches", "cases": baseline},
                   indent=2, sort_keys=True) + "\n", encoding="utf-8")

    first = fixtures["minimal_stale_resources"]
    expected = source_rule_reference(first)
    wrong = deepcopy(expected)
    wrong["events"][0], wrong["events"][1] = wrong["events"][1], wrong["events"][0]
    negative_order_control = compare_lifecycle(
        first["id"] + "_wrong_order", manifest(first), expected, wrong,
        {"fixture_id": first["id"], "mutation": "swap first two observations"},
        classification="manufactured_negative_control")
    receipt = {
        "schema": "cashout_shop_bookkeeping_v1",
        "status": "manufactured_tested_only",
        "fixture_set_sha256": hashlib.sha256((HERE / "fixtures.json").read_bytes()).hexdigest(),
        "original_archive_sha256": ARCHIVE_SHA256,
        "original_button_callbacks_sha256": BUTTON_SHA256,
        "baseline_file": "BASELINE_COMPARISONS.json",
        "cases": repaired,
        "negative_order_control": negative_order_control,
        "execution": {"original_cash_out_callback": False, "episode": False,
                      "Balatro_process": False, "save_or_profile_read": False,
                      "training": False},
    }
    (HERE / "MANUFACTURED_COMPARISONS.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    by_id = {item["comparison"]["case_id"]: item["comparison"] for item in baseline}
    assert by_id["minimal_stale_resources"]["first_difference"] == {
        "field": "events[1].discards_left", "expected": 3, "actual": 0}
    assert all(item["comparison"]["agreement"] for item in repaired)
    assert negative_order_control["first_difference"]["field"].startswith("events[0]")


if __name__ == "__main__":
    main()
