"""Manufactured source-rule comparisons of physical booster slots."""
from __future__ import annotations

from contextlib import nullcontext
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from . import simulator_patches as patches
from .lifecycle_contract import compare_lifecycle
from .lifecycle_reference_457 import source_rule_open, source_rule_stock

ROOT = Path(__file__).resolve().parents[2]
SIM = ROOT / "tools/advisor_eval/development355/external/jackdaw"
HERE = ROOT / "tools/advisor_eval/development457"
FIXTURES = HERE / "fixtures.json"
sys.path.insert(0, str(SIM))
from jackdaw.engine import actions as A, game as G, shop as S


class UnexpectedPackDraw(RuntimeError):
    pass


def cases() -> list[dict]:
    return json.loads(FIXTURES.read_text(encoding="utf-8"))["cases"]


def manifest(fixture: dict, *, baseline: bool = False) -> dict:
    paths = {
        "fixtures": FIXTURES,
        "reference": ROOT / "tools/advisor_learning/lifecycle_reference_457.py",
        "candidate": ROOT / "tools/advisor_learning/lifecycle_457.py",
        "integration": ROOT / "tools/advisor_learning/simulator_patches.py",
        "adapter_and_tests": ROOT / "tools/advisor_learning/test_lifecycle_457.py",
        "pinned_shop": SIM / "jackdaw/engine/shop.py",
        "pinned_game": SIM / "jackdaw/engine/game.py",
    }
    return {
        "files_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest()
                         for name, path in paths.items()},
        "source_archive_sha256": "0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47",
        "fixture_sha256": hashlib.sha256(json.dumps(fixture, sort_keys=True).encode()).hexdigest(),
        "candidate": "pinned_unpatched_stock" if baseline else patches.PATCH_ID,
        "classification": "manufactured_source_rule; original shop source not executed",
    }


def _offers(gs: dict) -> list[dict]:
    return [{"slot": card.ability.get("booster_pos"),
             "key": card.center_key, "price": card.cost}
            for card in gs.get("shop_boosters", [])]


def candidate_stock(fixture: dict, *, baseline: bool = False) -> tuple[dict, dict]:
    gs = {
        "phase": A.GamePhase.SHOP,
        "rng": object(),
        "round_resets": {"ante": 2},
        "current_round": {"voucher": None, "used_packs": deepcopy(fixture["used_packs"]),
                          "reroll_cost": 5, "free_rerolls": 0},
        "shop": {"joker_max": 0},
        "jokers": [], "consumables": [], "awarded_tags": [],
        "dollars": fixture["cash"], "first_shop_buffoon": True,
        "shop_cards": [], "shop_vouchers": [], "shop_boosters": [],
    }
    draws = []

    def prescribed_pack(_rng, _ante, _key, **_kwargs):
        used = gs["current_round"]["used_packs"]
        slot = next((i for i in (1, 2)
                     if i > len(used) or used[i - 1] is None or used[i - 1] is False), None)
        if len(draws) >= len(fixture["draws"]):
            raise UnexpectedPackDraw(f"extra get_pack call for slot {slot}")
        key = fixture["draws"][len(draws)]
        draws.append({"event": "pack_draw", "slot": slot, "key": key})
        return key

    try:
        with patch.object(S, "get_pack", new=prescribed_pack):
            context = patch.object(S, "populate_shop", new=S._advisor_original_populate_shop) \
                if baseline else nullcontext()
            with context:
                G._populate_shop(gs)
    except UnexpectedPackDraw as error:
        return {"events": draws + [{"event": "unexpected_pack_draw", "message": str(error)}],
                "state": {"error": str(error)}}, gs

    offers = _offers(gs)
    legal = A.get_legal_actions(gs)
    result = {
        "events": draws + [{"event": "booster_offer", **offer} for offer in offers],
        "state": {
            "used_packs": deepcopy(gs["current_round"]["used_packs"]),
            "offers": offers,
            "cash": gs["dollars"],
            "legal_open_indices": [action.card_index for action in legal
                                   if isinstance(action, A.OpenBooster)],
        },
    }
    return result, gs


def compare_stock(fixture: dict, *, baseline: bool = False) -> dict:
    candidate, _ = candidate_stock(fixture, baseline=baseline)
    return compare_lifecycle(
        fixture["id"], manifest(fixture, baseline=baseline),
        source_rule_stock(fixture), candidate,
        {"command": "python -B -m unittest tools.advisor_learning.test_lifecycle_457 -v",
         "fixture": fixture["id"]},
    )


def candidate_open(fixture: dict, index: int, *, baseline: bool = False) -> dict:
    stock, gs = candidate_stock(fixture)
    offer = deepcopy(stock["state"]["offers"][index])
    gs["rng"] = None  # Pack contents are outside this boundary.
    context = patch.object(G, "_handle_open_booster", new=G._advisor_original_open_booster) \
        if baseline else nullcontext()
    with context:
        G.step(gs, A.OpenBooster(card_index=index))
    return {
        "events": [{"event": "booster_open", **offer}],
        "state": {"used_packs": deepcopy(gs["current_round"]["used_packs"]),
                  "offers": _offers(gs), "cash": gs["dollars"],
                  "phase": gs["phase"].value},
    }


class Lifecycle457Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        patches.apply_patches(SIM)
        cls.fixtures = cases()

    def test_pinned_baseline_has_preserved_first_difference(self):
        by_id = {case["id"]: case for case in self.fixtures}
        for name in ("used_first_stored_second", "two_empty_slots"):
            with self.subTest(case=name):
                comparison = compare_stock(by_id[name], baseline=True)
                self.assertFalse(comparison["agreement"])
                self.assertIsNotNone(comparison["first_difference"])
        self.assertEqual(compare_stock(by_id["used_first_stored_second"], baseline=True)
                         ["first_difference"]["field"], "events[0].event")
        self.assertEqual(compare_stock(by_id["two_empty_slots"], baseline=True)
                         ["first_difference"]["field"], "events[1].slot")

    def test_repaired_stock_and_legal_offers(self):
        for fixture in self.fixtures:
            with self.subTest(case=fixture["id"]):
                comparison = compare_stock(fixture)
                self.assertTrue(comparison["agreement"], comparison["first_difference"])

    def test_opening_compact_offer_marks_physical_slot_used(self):
        fixture = self.fixtures[0]  # Only physical slot 2 is offered at index 0.
        expected = source_rule_open(source_rule_stock(fixture), 0)
        actual = candidate_open(fixture, 0)
        comparison = compare_lifecycle(
            fixture["id"] + "_open", manifest(fixture), expected, actual,
            {"command": "python -B -m unittest tools.advisor_learning.test_lifecycle_457 -v"},
        )
        self.assertTrue(comparison["agreement"], comparison["first_difference"])
        self.assertEqual(actual["state"]["used_packs"], ["USED", "USED"])
        baseline = compare_lifecycle(
            fixture["id"] + "_open_baseline", manifest(fixture, baseline=True),
            expected, candidate_open(fixture, 0, baseline=True),
            {"command": "python -B -m unittest tools.advisor_learning.test_lifecycle_457 -v"},
        )
        self.assertEqual(baseline["first_difference"],
                         {"field": "state.used_packs[1]", "expected": "USED",
                          "actual": "p_arcana_normal_1"})

    def test_opened_slot_stays_consumed_on_same_round_repopulation(self):
        fixture = self.fixtures[2]
        _, gs = candidate_stock(fixture)
        gs["rng"] = None
        G.step(gs, A.OpenBooster(card_index=0))
        self.assertEqual(gs["current_round"]["used_packs"],
                         ["USED", "p_arcana_normal_1"])
        gs["phase"] = A.GamePhase.SHOP
        gs["rng"] = object()
        with patch.object(S, "get_pack", side_effect=AssertionError("unexpected replacement")):
            G._populate_shop(gs)
        self.assertEqual(_offers(gs), [{"slot": 2, "key": "p_arcana_normal_1",
                                        "price": 4}])

    def test_unaffordable_booster_rejection_does_not_consume_slot(self):
        fixture = next(case for case in self.fixtures
                       if case["id"] == "stored_first_empty_second_unaffordable")
        _, gs = candidate_stock(fixture)
        before = deepcopy(gs["current_round"]["used_packs"])
        with self.assertRaises(G.IllegalActionError):
            G.step(gs, A.OpenBooster(card_index=0))
        self.assertEqual(gs["current_round"]["used_packs"], before)


if __name__ == "__main__":
    unittest.main()
