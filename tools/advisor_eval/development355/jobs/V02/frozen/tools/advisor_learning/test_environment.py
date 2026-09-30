"""Manufactured wrapper checks. Never initializes or steps a real episode."""
from __future__ import annotations
import copy
from types import SimpleNamespace as NS
import unittest
from unittest.mock import patch
import numpy as np
from . import environment as E
from .heuristic import heuristic_index


def card(rank=2,suit="Hearts",key="c_base",kind="Default",**fields):
    c=NS(facing="front",center_key=key,base=NS(id=rank,suit=suit),
         ability={"set":kind},edition={},seal=None,debuff=False,cost=1,base_cost=1,
         sell_cost=1,eternal=False,perishable=False,rental=False,perish_tally=5)
    if kind not in ("Default","Enhanced"): c.base=None
    for k,v in fields.items(): setattr(c,k,v)
    return c


def state(phase="selecting_hand",n=5):
    return {"phase":phase,"hand":[card(i+2) for i in range(n)],"jokers":[],"consumables":[],
            "current_round":{"hands_left":4,"discards_left":3},"round_resets":{"ante":1},
            "dollars":10,"blind":NS(chips=300,name="Small Blind"),"blind_on_deck":"Small",
            "chips":0,"stake":8,"joker_slots":5,"consumable_slots":2,"win_ante":8}


def env(gs=None,max_steps=1200):
    # Explicit bypass of __init__: no initialize_run, RNG, or game transition.
    value=object.__new__(E.Environment)
    value._gs=gs if gs is not None else state()
    value._initialize_tracking(max_steps)
    return value


class PoisonJoker:
    facing="back"
    def __getattr__(self,name): raise AssertionError("Hidden Joker field read: "+name)


class PoisonPlaying:
    facing="back"
    ability={"forced_selection":False}
    def __getattr__(self,name): raise AssertionError("Hidden card field read: "+name)


class PublicEnvironmentTests(unittest.TestCase):
    def setUp(self):
        # These tests isolate public projection from the separate audit-only
        # simulator fidelity boundary, whose private-state checks have their
        # own manufactured suite. The boundary may censor an entire episode.
        self.audit_patch=patch.object(E,"audit_state_boundary",return_value=None)
        self.audit=self.audit_patch.start()
        self.addCleanup(self.audit_patch.stop)

    def test_manufactured_observation_no_initialization(self):
        with patch.object(E,"initialize_run",side_effect=AssertionError("No source reset")):
            observation=env().observe()
        self.assertEqual(observation["global"].shape,(80,))
        self.assertEqual(observation["entities"].shape,(5,64))
        self.assertEqual(observation["candidates"].shape[1],160)
        self.assertTrue(all(a.dtype==np.float32 for a in observation.values()))

    def test_poison_concealed_fields_never_read(self):
        gs=state();gs["hand"][0]=PoisonPlaying();gs["jokers"]=[PoisonJoker()]
        observation=env(gs).observe()
        self.assertEqual(observation["entities"][0,7],0)
        self.assertEqual(observation["entities"][-1,7],0)
        self.assertFalse(np.any(observation["entities"][-1,9:]))

    def test_hidden_identity_and_rng_invariance(self):
        a=state();b=copy.deepcopy(a)
        a["hand"][0].facing=b["hand"][0].facing="back"
        b["hand"][0].base.id=14;b["hand"][0].base.suit="Spades"
        a["seed"]="FIRST";b["seed"]="SECOND"
        a["rng"]=object();b["rng"]=object()
        a["deck"]=[PoisonPlaying()];b["deck"]=[PoisonJoker()]
        ao,bo=env(a).observe(),env(b).observe()
        for key in ao:np.testing.assert_array_equal(ao[key],bo[key])

    def test_forced_card_all_play_discard_candidates(self):
        gs=state();gs["hand"][3].ability["forced_selection"]=True
        value=env(gs);value.observe()
        for action in value._actions:
            if isinstance(action,(E.A.PlayHand,E.A.Discard)):
                self.assertIn(3,action.card_indices)
                self.assertEqual(len(action.card_indices),len(set(action.card_indices)))

    def test_targeted_pack_has_all_distinct_pairs(self):
        gs=state("pack_opening",3)
        gs["pack_cards"]=[card(key="c_death",kind="Tarot")]
        gs["pack_cards"][0].ability["consumeable"]={"max_highlighted":2,"min_highlighted":2}
        gs["pack_choices_remaining"]=1
        value=env(gs);ob=value.observe()
        picks=[a for a in value._actions if isinstance(a,E.A.PickPackCard)]
        self.assertEqual([a.target_indices for a in picks],[(0,1),(0,2),(1,2)])
        index=next(i for i,a in enumerate(value._actions) if isinstance(a,E.A.PickPackCard))
        np.testing.assert_allclose(ob["candidates"][index,149:151],[1/128,2/128])
        self.assertGreater(ob["entities"][-1,9],0) # pack Tarot identity encoded

    def test_ordered_swap_descriptor_is_not_sorted(self):
        value=env();ob=value.observe()
        i=next(i for i,a in enumerate(value._actions) if isinstance(a,E.A.SwapHandLeft) and a.idx==2)
        np.testing.assert_allclose(ob["candidates"][i,149:151],[3/128,2/128])

    def test_entities_are_not_silently_truncated(self):
        gs=state(n=9);gs["jokers"]=[card(key="j_joker",kind="Joker") for _ in range(7)]
        self.assertEqual(env(gs).observe()["entities"].shape,(16,64))
        gs["jokers"]*=20
        with self.assertRaisesRegex(E.UnsupportedState,"entity_capacity"):env(gs).observe()

    def test_candidate_overflow_is_explicit(self):
        with self.assertRaisesRegex(E.UnsupportedState,"candidate_capacity"):env(state(n=16)).observe()

    def test_poker_base_estimate_pair_scores_only_pair(self):
        gs=state();gs["hand"]=[card(10),card(10,"Spades"),card(14,"Clubs")]
        value=env(gs);ob=value.observe()
        i=next(i for i,a in enumerate(value._actions) if isinstance(a,E.A.PlayHand) and a.card_indices==(0,1,2))
        # Pair level 1: (10 base chips + 10 + 10) * 2 = 60, Ace excluded.
        self.assertAlmostEqual(float(np.expm1(ob["candidates"][i,159])),60,places=4)
        self.assertAlmostEqual(float(ob["candidates"][i,158]),10/11,places=6)

    def test_wheel_straight_and_flush_base(self):
        gs=state();gs["hand"]=[card(r) for r in (14,2,3,4,5)]
        value=env(gs);ob=value.observe()
        i=next(i for i,a in enumerate(value._actions) if isinstance(a,E.A.PlayHand) and len(a.card_indices)==5)
        self.assertAlmostEqual(float(np.expm1(ob["candidates"][i,159])),(100+25)*8,places=2)

    def test_win_latches_at_final_boss_not_later_loss(self):
        gs=state();gs["round_resets"]["ante"]=8;gs["blind_on_deck"]="Boss"
        value=env(gs);value.observe()
        def fake_step(g,a):g.update(phase="round_eval",won=True,chips=300);g["round_resets"]["ante"]=9
        with patch.object(E,"engine_step",side_effect=fake_step):
            ob,reward,terminated,truncated,info=value.step(0)
        self.assertIsNone(ob);self.assertEqual(reward,1);self.assertTrue(terminated);self.assertFalse(truncated)
        self.assertEqual(info["outcome"],"win");self.assertEqual(info["blinds_cleared"],1)
        with self.assertRaises(RuntimeError):value.step(0)

    def test_fabricated_early_win_is_unsupported(self):
        value=env();value.observe()
        with patch.object(E,"engine_step",side_effect=lambda g,a:g.update(won=True,phase="round_eval")):
            result=value.step(0)
        self.assertEqual(result[4]["outcome"],"unsupported");self.assertEqual(result[1],0)
        self.assertFalse(result[2]);self.assertTrue(result[3])

    def test_timeout_not_loss_and_loss_not_timeout(self):
        value=env(max_steps=1);value.observe()
        with patch.object(E,"engine_step",return_value=None):result=value.step(0)
        self.assertEqual(result[4]["outcome"],"censored");self.assertTrue(result[3]);self.assertFalse(result[2])
        value=env(max_steps=1);value.observe()
        with patch.object(E,"engine_step",side_effect=lambda g,a:g.update(phase="game_over",won=False)):
            result=value.step(0)
        self.assertEqual(result[4]["outcome"],"loss");self.assertTrue(result[2]);self.assertFalse(result[3])

    def test_engine_error_is_explicit_no_retry(self):
        value=env();value.observe()
        with patch.object(E,"engine_step",side_effect=ValueError("fixture failure")) as step:
            result=value.step(0)
        self.assertEqual(step.call_count,1);self.assertEqual(result[4]["outcome"],"error")
        self.assertTrue(result[3]);self.assertFalse(result[2]);self.assertEqual(result[1],0)

    def test_detached_arrays_and_deterministic_candidates(self):
        value=env();one=value.observe();two=value.observe()
        for key in one: np.testing.assert_array_equal(one[key],two[key])
        one["entities"][:]=123
        self.assertFalse(np.any(value.observe()["entities"]==123))

    def test_stale_shop_and_pack_contents_are_not_observed(self):
        gs=state(); gs["shop_cards"]=[PoisonJoker()]; gs["pack_cards"]=[PoisonJoker()]
        self.assertEqual(env(gs).observe()["entities"].shape,(5,64))

    def test_under_target_clear_requires_explicit_saved_result(self):
        value=env();value.observe()
        with patch.object(E,"engine_step",side_effect=lambda g,a:g.update(phase="round_eval",chips=100)):
            result=value.step(0)
        self.assertEqual(result[4]["outcome"],"unsupported")
        self.assertEqual(result[4]["blinds_cleared"],0)
        gs=state();gs["current_round"]["hands_left"]=1
        value=env(gs);value.observe()
        def saved(g,a):
            g.update(phase="round_eval",chips=100,last_score_result=NS(saved=True))
            g["current_round"]["hands_left"]=0
        with patch.object(E,"engine_step",side_effect=saved):result=value.step(0)
        self.assertEqual(result[4]["outcome"],"ongoing")
        self.assertEqual(result[4]["blinds_cleared"],1)
        self.assertTrue(result[4]["clear_receipt"]["saved"])
        self.assertFalse(result[4]["clear_receipt"]["threshold_met"])

    def test_loss_outweighs_stray_win_marker(self):
        value=env();value.observe()
        with patch.object(E,"engine_step",side_effect=lambda g,a:g.update(phase="game_over",won=True)):
            result=value.step(0)
        self.assertEqual(result[4]["outcome"],"loss")
        self.assertEqual(result[1],0)

    def test_catalog_ids_have_declared_embedding_denominator(self):
        gs=state("pack_opening",0); gs["pack_cards"]=[card(key="j_joker",kind="Joker")]
        gs["pack_choices_remaining"]=1
        ob=env(gs).observe();key_id=float(ob["entities"][0,9])*(E.CATALOG_SIZE+1)
        self.assertAlmostEqual(key_id,round(key_id),places=4)
        self.assertGreater(key_id,0)

    def test_negative_and_capacity_purchase_candidates(self):
        gs=state("shop",0);gs["jokers"]=[card(kind="Joker")]*5
        gs["shop_cards"]=[card(key="j_joker",kind="Joker"),
            card(key="j_joker",kind="Joker",edition={"negative":True})]
        value=env(gs);value.observe()
        self.assertEqual([a.shop_index for a in value._actions if isinstance(a,E.A.BuyCard)],[1])

    def test_concealed_shop_eligibility_never_inspected(self):
        gs=state("shop",0)
        for area in ("shop_cards","shop_vouchers","shop_boosters"):
            gs[area]=[PoisonJoker()]
        value=env(gs);value.observe()
        self.assertFalse(any(isinstance(a,(E.A.BuyCard,E.A.RedeemVoucher,E.A.OpenBooster)) for a in value._actions))

    def test_overlay_applied_before_run_initialization(self):
        calls=[]
        with patch.object(E,"apply_patches",side_effect=lambda p:calls.append("overlay")), \
             patch.object(E,"initialize_run",side_effect=lambda *a:calls.append(a) or state()):
            value=E.Environment("MANUFACTURED","b_red",8,15)
        self.assertEqual(calls,["overlay",("b_red",8,"MANUFACTURED")])
        self.assertEqual(value.max_steps,15)

    def test_pretransition_fidelity_censor_never_executes(self):
        value=env();value.observe();self.audit.return_value="fixture_fidelity_boundary"
        with patch.object(E,"engine_step",side_effect=AssertionError("Must not step")) as step:
            result=value.step(0)
        step.assert_not_called()
        self.assertEqual(result[4]["outcome"],"unsupported")
        self.assertEqual(result[4]["steps"],0)

    def test_posttransition_fidelity_censor_overrides_win_credit(self):
        gs=state();gs["round_resets"]["ante"]=8;gs["blind_on_deck"]="Boss"
        value=env(gs);value.observe()
        self.audit.side_effect=[None,"fixture_posttransition_boundary"]
        def win(g,a):
            g.update(phase="round_eval",won=True,chips=300);g["round_resets"]["ante"]=9
        with patch.object(E,"engine_step",side_effect=win):result=value.step(0)
        self.assertEqual(result[4]["outcome"],"unsupported")
        self.assertEqual(result[1],0);self.assertFalse(result[2]);self.assertTrue(result[3])

    def test_gold_red_parameters_without_run_initialization(self):
        from jackdaw.engine.stakes import apply_stake_modifiers
        from jackdaw.engine.back import Back
        gs={"starting_params":{"discards":3},"modifiers":{}}
        apply_stake_modifiers(8,gs)
        self.assertEqual(gs["starting_params"]["discards"],2)
        self.assertTrue(all(gs["modifiers"][k] for k in (
            "enable_eternals_in_shop","enable_perishables_in_shop","enable_rentals_in_shop")))
        self.assertEqual(gs["modifiers"]["scaling"],3)
        self.assertTrue(gs["modifiers"]["no_blind_reward"]["Small"])
        self.assertEqual(Back("b_red").apply_to_run(gs)["discards_delta"],1)

    def test_heuristic_selects_visible_straight_flush(self):
        value=env();ob=value.observe();i=heuristic_index(ob)
        self.assertIsInstance(value._actions[i],E.A.PlayHand)
        self.assertEqual(value._actions[i].card_indices,(0,1,2,3,4))

    def test_baseline_leaves_shop_without_rearrangement_loop(self):
        gs=state("shop",0);gs["jokers"]=[card(key="j_joker",kind="Joker")]*2
        value=env(gs);ob=value.observe()
        self.assertIsInstance(value._actions[heuristic_index(ob)],E.A.NextRound)


if __name__=="__main__":unittest.main()
