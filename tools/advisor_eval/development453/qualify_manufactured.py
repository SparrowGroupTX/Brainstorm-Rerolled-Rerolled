"""Write deterministic manufactured comparison receipts for lifecycle slice 453.

No run initialization, source callback execution, or game process interaction.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path

from tools.advisor_learning import simulator_patches as patches
from tools.advisor_learning.lifecycle_contract import compare_lifecycle
from tools.advisor_learning.lifecycle_reference_453 import source_rule_reference
from tools.advisor_learning.test_lifecycle_453 import (
    SIM, candidate_transition, compare_case, fixture_cases, held_case, manifest,
)
from jackdaw.engine import round_lifecycle


def main() -> None:
    root = Path(__file__).resolve().parent
    patches.apply_patches(SIM)
    cases = fixture_cases()
    main_case = cases["rental_juggler_last_tally"]
    old = round_lifecycle._advisor_original_round_end_cards
    baseline = {
        "comparison": compare_case(main_case, process=old),
        "expected": source_rule_reference(main_case),
        "actual": candidate_transition(main_case, process=old),
    }
    (root / "MISMATCH_BEFORE.json").write_text(
        json.dumps(baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    comparisons = []
    for fixture in cases.values():
        result = {
            "comparison": compare_case(fixture),
            "expected": source_rule_reference(fixture),
            "actual": candidate_transition(fixture),
        }
        comparisons.append(result)
    heldout = cases["heldout_juggler_rental_order"]
    expected_order = source_rule_reference(heldout)
    wrong_order = deepcopy(expected_order)
    wrong_order["events"][0], wrong_order["events"][1] = (
        wrong_order["events"][1], wrong_order["events"][0])
    negative_order_control = compare_lifecycle(
        heldout["id"] + "_wrong_order", manifest(heldout),
        expected_order, wrong_order, {"fixture_id": heldout["id"], "mutation": "swap first two events"},
        classification="manufactured_negative_control")
    receipt = {
        "schema": "round_end_plain_juggler_v1",
        "status": "manufactured_tested_only",
        "patch_id": patches.PATCH_ID,
        "fixture_set_sha256": hashlib.sha256((root / "fixtures.json").read_bytes()).hexdigest(),
        "baseline_mismatch_file": "MISMATCH_BEFORE.json",
        "comparisons": comparisons,
        "negative_order_control": negative_order_control,
        "unsupported_cases": [{
            "fixture": held_case(),
            "reason": "fidelity_mime_round_end_repetition",
            "comparison_executed": False,
        }],
        "execution": {"original_source_callbacks": False, "episode": False,
                      "Balatro_process": False, "save_or_profile_read": False},
    }
    (root / "MANUFACTURED_COMPARISONS.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    assert baseline["comparison"]["first_difference"] == {
        "field": "events[0].after.hand_size", "expected": 8, "actual": 9}
    assert all(item["comparison"]["agreement"] for item in comparisons)
    assert negative_order_control["first_difference"]["field"] == "events[0].after.cash"


if __name__ == "__main__":
    main()
