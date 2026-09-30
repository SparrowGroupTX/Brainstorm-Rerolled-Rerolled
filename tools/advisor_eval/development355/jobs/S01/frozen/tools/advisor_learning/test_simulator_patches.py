"""Manufactured cards/contexts only; no initialize_run, step, or source Lua."""
from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace as NS
import sys
import unittest

from . import simulator_patches as P

SIM = Path(__file__).resolve().parents[1] / "advisor_eval/development355/external/jackdaw"
sys.path.insert(0, str(SIM))
from jackdaw.engine.card import Card
from jackdaw.engine import jokers as J


def joker(key):
    card = Card(center_key=key)
    card.set_ability(key)
    return card


def dispatch(row, **flags):
    return [J.calculate_joker(card, J.JokerContext(jokers=row, **flags)) for card in row]


class SimulatorPatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        P.apply_patches(SIM)

    def test_overlay_idempotent_and_files_unchanged(self):
        before = J._REGISTRY["j_burnt"]
        self.assertEqual(P.apply_patches(SIM), P.PATCH_ID)
        self.assertIs(before, J._REGISTRY["j_burnt"])

    def test_reject_wrong_source_root(self):
        with self.assertRaisesRegex(RuntimeError, "configured engine"):
            P.apply_patches(SIM.parent)

    def test_burnt_blueprint_brainstorm_once_before_cards(self):
        row = [joker("j_blueprint"), joker("j_burnt"), joker("j_brainstorm")]
        results = dispatch(row, pre_discard=True, game=J.GameSnapshot(discards_used=0))
        self.assertEqual(sum(bool(r and r.level_up) for r in results), 3)
        hand = [Card() for _ in range(5)]
        for card in hand:
            self.assertTrue(all(r is None for r in dispatch(
                row, discard=True, other_card=card, full_hand=hand,
                game=J.GameSnapshot(discards_used=0))))

    def test_burnt_skips_later_discard_hook_and_debuff(self):
        row = [joker("j_blueprint"), joker("j_burnt")]
        for kwargs in ({"game": J.GameSnapshot(discards_used=1)}, {"hook": True}):
            self.assertTrue(all(r is None for r in dispatch(row, pre_discard=True, **kwargs)))
        row[1].debuff = True
        self.assertTrue(all(r is None for r in dispatch(row, pre_discard=True)))

    def test_copy_loops_and_leftmost_brainstorm_do_not_add_effect(self):
        row = [joker("j_brainstorm"), joker("j_burnt")]
        self.assertIsNone(dispatch(row, pre_discard=True)[0])
        row = [joker("j_blueprint"), joker("j_brainstorm")]
        self.assertTrue(all(r is None for r in dispatch(row, pre_discard=True)))

    def test_perkeo_all_copy_paths_and_empty_inventory(self):
        row = [joker("j_blueprint"), joker("j_perkeo"), joker("j_brainstorm")]
        results = dispatch(row, ending_shop=True, game=J.GameSnapshot(consumable_count=1))
        self.assertEqual([r.extra["create"]["type"] for r in results], ["consumable_copy"] * 3)
        self.assertTrue(all(r is None for r in dispatch(row, ending_shop=True)))
        self.assertTrue(all(r is None for r in dispatch(row, joker_main=True)))

    def test_yorick_grows_physically_once_per_discarded_card(self):
        row = [joker("j_blueprint"), joker("j_yorick"), joker("j_brainstorm")]
        row[1].ability.update(yorick_discards=2, x_mult=1)
        for _ in range(5):
            dispatch(row, discard=True, other_card=Card())
        self.assertEqual(row[1].ability["x_mult"], 2)
        self.assertEqual(row[1].ability["yorick_discards"], 20)
        results = dispatch(row, joker_main=True)
        self.assertEqual([r.Xmult_mod for r in results], [2, 2, 2])

    def test_perkeo_descriptors_grow_pool_in_row_order(self):
        # Isolated mutation helper, never initialize_run/engine.step/episode.
        from jackdaw.engine.game import _fire_shop_joker_context, _apply_shop_mutations
        class FakeRng:
            def __init__(self): self.pool_sizes = []
            def seed(self, key):
                self_key = key
                if self_key != "perkeo": raise AssertionError(self_key)
                return 0
            def element(self, cards, seed):
                self.pool_sizes.append(len(cards))
                return cards[-1], len(cards) - 1
        row = [joker("j_blueprint"), joker("j_perkeo"), joker("j_brainstorm")]
        consumable = joker("c_hermit")
        rng = FakeRng()
        gs = {"jokers": row, "consumables": [consumable], "consumable_slots": 2,
              "rng": rng, "round_resets": {"ante": 1}}
        mutations = _fire_shop_joker_context(gs, ending_shop=True)
        _apply_shop_mutations(gs, mutations)
        self.assertEqual(rng.pool_sizes, [1, 2, 3])
        self.assertEqual(len(gs["consumables"]), 4)
        self.assertEqual(gs["consumable_slots"], 5)
        self.assertTrue(all(c.edition["negative"] for c in gs["consumables"][1:]))
        self.assertEqual(len({id(c.ability) for c in gs["consumables"]}), 4)

    def test_sticker_compatibility(self):
        banana = joker("j_gros_michel"); banana.set_eternal(True)
        self.assertFalse(banana.eternal)
        green = joker("j_green_joker"); green.set_perishable(True)
        self.assertFalse(green.perishable)
        plain = joker("j_joker"); plain.set_perishable(True)
        self.assertTrue(plain.perishable)
        self.assertEqual(plain.ability["perish_tally"], 5)

    def test_stickers_mutually_exclusive(self):
        first = joker("j_joker"); first.set_eternal(True); first.set_perishable(True)
        self.assertTrue(first.eternal); self.assertFalse(first.perishable)
        second = joker("j_joker"); second.set_perishable(True); second.set_eternal(True)
        self.assertTrue(second.perishable); self.assertFalse(second.eternal)

    def test_expired_perishable_cannot_be_revived(self):
        card = joker("j_joker"); card.set_perishable(True)
        card.perish_tally = 0; card.ability["perish_tally"] = 0
        card.set_debuff(False)
        self.assertTrue(card.debuff)
        fresh = joker("j_joker"); fresh.set_debuff(True); fresh.set_debuff(False)
        self.assertFalse(fresh.debuff)

    def test_expiry_and_passive_debuff_boundaries_latch(self):
        card = joker("j_juggler"); card.set_perishable(True)
        gs = {"jokers": [card]}
        self.assertIsNone(P.audit_state_boundary(gs))
        card.ability["perish_tally"] = 1
        self.assertEqual(P.audit_state_boundary(gs), "fidelity_perishable_expiry_order")
        gs["jokers"] = []
        self.assertEqual(P.audit_state_boundary(gs), "fidelity_perishable_expiry_order")
        card = joker("j_juggler"); card.debuff = True
        self.assertEqual(P.audit_state_boundary({"jokers": [card]}), "fidelity_debuff_passive_side_effects")

    def test_mime_held_resource_boundary(self):
        mime = joker("j_mime")
        gold = NS(ability={"h_dollars": 3}, debuff=False, seal=None)
        blue = NS(ability={}, debuff=False, seal="Blue")
        for held in (gold, blue):
            self.assertEqual(P.audit_state_boundary({"jokers": [mime], "hand": [held]}),
                             "fidelity_mime_round_end_repetition")
        mime.debuff = True
        self.assertIsNone(P.audit_state_boundary({"jokers": [mime], "hand": [gold]}))


if __name__ == "__main__":
    unittest.main()
