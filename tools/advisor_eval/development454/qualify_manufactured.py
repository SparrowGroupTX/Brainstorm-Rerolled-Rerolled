"""Preserve all manufactured baseline and repaired Golden comparisons."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path

from tools.advisor_learning import simulator_patches as patches
from tools.advisor_learning.lifecycle_contract import compare_lifecycle
from tools.advisor_learning.lifecycle_reference_454 import source_rule_reference
from tools.advisor_learning.test_lifecycle_454 import (
    SIM, candidate_transition, cases, compare_case, manifest,
)
from jackdaw.engine import game as G


def main() -> None:
    output = Path(__file__).resolve().parent
    patches.apply_patches(SIM)
    fixtures = cases()
    baseline = []
    repaired = []
    for fixture in fixtures.values():
        baseline.append({
            "comparison": compare_case(fixture, end_fn=G._advisor_original_joker_eor),
            "expected": source_rule_reference(fixture),
            "actual": candidate_transition(fixture, end_fn=G._advisor_original_joker_eor),
        })
        repaired.append({
            "comparison": compare_case(fixture),
            "expected": source_rule_reference(fixture),
            "actual": candidate_transition(fixture),
        })
    (output / "BASELINE_COMPARISONS.json").write_text(
        json.dumps({"status": "preserved_pinned_mismatches", "cases": baseline},
                   indent=2, sort_keys=True) + "\n", encoding="utf-8")
    heldout = fixtures["heldout_golden_row"]
    expected = source_rule_reference(heldout)
    wrong_order = deepcopy(expected)
    wrong_order["events"][0], wrong_order["events"][1] = (
        wrong_order["events"][1], wrong_order["events"][0])
    negative_order_control = compare_lifecycle(
        heldout["id"] + "_wrong_order", manifest(heldout), expected, wrong_order,
        {"fixture_id": heldout["id"], "mutation": "swap first two events"},
        classification="manufactured_negative_control")
    receipt = {
        "schema": "plain_golden_round_cashout_v1",
        "status": "manufactured_tested_only",
        "fixture_set_sha256": hashlib.sha256((output / "fixtures.json").read_bytes()).hexdigest(),
        "baseline_file": "BASELINE_COMPARISONS.json",
        "cases": repaired,
        "negative_order_control": negative_order_control,
        "execution": {"original_source_callbacks": False, "episode": False,
                      "Balatro_process": False, "save_or_profile_read": False,
                      "training": False},
    }
    (output / "MANUFACTURED_COMPARISONS.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    by_id = {item["comparison"]["case_id"]: item["comparison"] for item in baseline}
    assert by_id["golden_final_life_minimal"]["first_difference"] == {
        "field": "events[2].dollars", "expected": 0, "actual": 4}
    assert all(item["comparison"]["agreement"] for item in repaired)
    assert negative_order_control["first_difference"]["field"] == "events[0].after.debuff"


if __name__ == "__main__":
    main()
