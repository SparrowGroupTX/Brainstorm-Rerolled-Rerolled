"""Manufactured lifecycle comparisons; no episode or original-source execution."""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import unittest

from . import simulator_patches as patches
from .lifecycle_contract import compare_lifecycle
from .lifecycle_reference_453 import source_rule_reference

ROOT = Path(__file__).resolve().parents[2]
SIM = ROOT / "tools/advisor_eval/development355/external/jackdaw"
FIXTURES = ROOT / "tools/advisor_eval/development453/fixtures.json"
sys.path.insert(0, str(SIM))
from jackdaw.engine.card import Card
from jackdaw.engine import round_lifecycle


def fixture_cases():
    return {case["id"]: case for case in json.loads(FIXTURES.read_text(encoding="utf-8"))["cases"]}


def held_case():
    return json.loads(FIXTURES.read_text(encoding="utf-8"))["held_cases"][0]


def manifest(fixture):
    names = {
        "pinned_round_lifecycle": SIM / "jackdaw/engine/round_lifecycle.py",
        "pinned_game": SIM / "jackdaw/engine/game.py",
        "pinned_economy": SIM / "jackdaw/engine/economy.py",
        "pinned_card": SIM / "jackdaw/engine/card.py",
        "pinned_jokers": SIM / "jackdaw/engine/jokers.py",
        "retained_original_card": ROOT / "tools/advisor_eval/runs/chicot_order_source1/source/card.lua",
        "retained_state_events_excerpt": ROOT / "tools/advisor_eval/runs/gold299_20260914/M02/state_events_source_references.json",
        "candidate_overlay": ROOT / "tools/advisor_learning/lifecycle_453.py",
        "reference_model": ROOT / "tools/advisor_learning/lifecycle_reference_453.py",
        "comparator": ROOT / "tools/advisor_learning/lifecycle_contract.py",
        "overlay_integration": ROOT / "tools/advisor_learning/simulator_patches.py",
        "test_harness": ROOT / "tools/advisor_learning/test_lifecycle_453.py",
        "qualification_writer": ROOT / "tools/advisor_eval/development453/qualify_manufactured.py",
    }
    return {"sources_sha256": {key: hashlib.sha256(path.read_bytes()).hexdigest()
                                for key, path in names.items()},
            "fixture_sha256": hashlib.sha256(json.dumps(fixture, sort_keys=True).encode()).hexdigest(),
            "candidate_patch": patches.PATCH_ID,
            "reference": "source-derived handwritten rule model; original callbacks not executed"}


def candidate_transition(fixture, process=None):
    row = []
    for item in fixture["jokers"]:
        card = Card(center_key=item["center_key"], sort_id=item["physical_id"])
        card.set_ability(item["center_key"])
        if item["perishable"]:
            card.set_perishable(True)
        card.perish_tally = item["tally"]
        if item["perishable"]:
            card.ability["perish_tally"] = item["tally"]
        card.set_rental(item["rental"])
        card.debuff = item["debuff"]
        card.edition = item["edition"]
        assert card.ability.get("h_size", 0) == item["h_size"]
        row.append(card)
    gs = {"dollars": fixture["cash"], "hand_size": fixture["hand_size"],
          "rental_rate": 3, "_advisor_lifecycle_trace": []}
    runner = process or round_lifecycle.process_round_end_cards
    if process is not None:
        # The preserved upstream function has no trace hook. The minimal
        # one-Joker case has one settled boundary, reconstructed here.
        assert len(row) == 1
        card = row[0]
        before = {"cash": gs["dollars"], "hand_size": gs["hand_size"],
                  "tally": card.ability.get("perish_tally", card.perish_tally),
                  "debuff": card.debuff}
    runner(row, gs)
    if process is not None:
        gs["_advisor_lifecycle_trace"].append({
            "phase": "round_end", "event": "joker_maintenance_settled",
            "physical_id": card.sort_id, "center_key": card.center_key,
            "before": before,
            "after": {"cash": gs["dollars"], "hand_size": gs["hand_size"],
                      "tally": card.ability.get("perish_tally", card.perish_tally),
                      "debuff": card.debuff},
        })
    return {"events": gs["_advisor_lifecycle_trace"],
            "state": {"phase": "round_end", "cash": gs["dollars"],
                      "hand_size": gs["hand_size"],
                      "jokers": [
                          {"physical_id": c.sort_id, "center_key": c.center_key,
                           "rental": c.rental, "perishable": c.perishable,
                           "tally": c.ability.get("perish_tally", c.perish_tally),
                           "debuff": c.debuff, "edition": c.edition,
                           "h_size": c.ability.get("h_size", 0)} for c in row]}}


def compare_case(fixture, process=None):
    expected = source_rule_reference(fixture)
    actual = candidate_transition(fixture, process=process)
    receipt = manifest(fixture)
    if process is not None:
        receipt["candidate_patch"] = "pinned_unpatched_round_lifecycle"
    return compare_lifecycle(
        fixture["id"], receipt, expected, actual,
        {"fixture_id": fixture["id"],
         "command": "python -m unittest tools.advisor_learning.test_lifecycle_453 -v"},
    )


class Lifecycle453Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        patches.apply_patches(SIM)
        cls.cases = fixture_cases()

    def test_pinned_candidate_fails_at_first_passive_capacity_difference(self):
        old = round_lifecycle._advisor_original_round_end_cards
        result = compare_case(self.cases["rental_juggler_last_tally"], process=old)
        self.assertFalse(result["agreement"])
        self.assertEqual(result["first_difference"], {
            "field": "events[0].after.hand_size", "expected": 8, "actual": 9})
        self.assertEqual(result["common_event_prefix"], [])

    def test_repair_controls_and_heldout_order(self):
        for case in self.cases.values():
            with self.subTest(case=case["id"]):
                result = compare_case(case)
                self.assertTrue(result["agreement"], result["first_difference"])
        heldout = candidate_transition(self.cases["heldout_juggler_rental_order"])
        self.assertEqual([event["physical_id"] for event in heldout["events"]], [201, 202, 203])
        self.assertEqual([(event["after"]["cash"], event["after"]["hand_size"])
                          for event in heldout["events"]], [(14, 9), (11, 9), (8, 8)])

    def test_game_round_end_helper_reaches_overlay_and_rent_precedes_interest(self):
        # No initialize_run, game.step, blind play, or original callbacks.
        from types import SimpleNamespace
        from jackdaw.engine.game import _joker_end_of_round_effects
        from jackdaw.engine.economy import calculate_round_earnings
        card = Card(center_key="j_juggler", sort_id=301)
        card.set_ability("j_juggler")
        card.set_perishable(True)
        card.ability["perish_tally"] = 1
        card.perish_tally = 1
        card.set_rental(True)
        gs = {"jokers": [card], "dollars": 10, "hand_size": 9,
              "current_round": {"hands_left": 0, "discards_left": 0},
              "rental_rate": 3, "_advisor_lifecycle_trace": []}
        eor = _joker_end_of_round_effects(gs)
        self.assertEqual((gs["dollars"], gs["hand_size"], card.debuff), (7, 8, True))
        self.assertEqual(len(gs["_advisor_lifecycle_trace"]), 1)
        earnings = calculate_round_earnings(
            blind=SimpleNamespace(dollars=0), hands_left=0, discards_left=0,
            money=gs["dollars"], jokers=gs["jokers"], game_state=gs,
            joker_dollars=eor["dollars_earned"])
        self.assertEqual((earnings.rental_cost, earnings.interest, earnings.total), (0, 1, 1))

    def test_comparator_catches_wrong_order_and_never_mutates(self):
        case = self.cases["heldout_juggler_rental_order"]
        expected = source_rule_reference(case)
        actual = deepcopy(expected)
        actual["events"][0], actual["events"][1] = actual["events"][1], actual["events"][0]
        expected_before, actual_before = deepcopy(expected), deepcopy(actual)
        result = compare_lifecycle(case["id"], manifest(case), expected, actual,
                                   {"fixture_id": case["id"]})
        self.assertFalse(result["agreement"])
        self.assertEqual(result["first_difference"]["field"], "events[0].after.cash")
        self.assertEqual(expected, expected_before)
        self.assertEqual(actual, actual_before)

    def test_adjacent_paths_stay_unsupported(self):
        expiring = Card(center_key="j_juggler")
        expiring.set_ability("j_juggler")
        expiring.set_perishable(True)
        expiring.ability["perish_tally"] = 1
        self.assertEqual(patches.audit_state_boundary({"jokers": [expiring]}),
                         "fidelity_perishable_expiry_order")
        expiring.edition = {"negative": True}
        self.assertEqual(patches.audit_state_boundary({"jokers": [expiring]}),
                         "fidelity_perishable_expiry_order")
        separate = held_case()
        self.assertEqual(separate["qualification"], "unsupported")
        self.assertEqual(separate["source_derived_held_dollars"], 6)
        mime = Card(center_key=separate["active_jokers"][0]); mime.set_ability("j_mime")
        held = separate["held_cards"][0]
        held_gold = type("Held", (), {"ability": {"h_dollars": held["h_dollars"]},
                                      "debuff": held["debuff"], "seal": held["seal"]})()
        self.assertEqual(patches.audit_state_boundary({"jokers": [mime], "hand": [held_gold]}),
                         "fidelity_mime_round_end_repetition")


if __name__ == "__main__":
    unittest.main()
