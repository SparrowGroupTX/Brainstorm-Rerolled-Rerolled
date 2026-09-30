"""Red/Gold public-conditioned post-Soul training scaffold, never real awards.

The starting public situation follows the recorded YAEARC31 development opening:
Small skipped, Big selected next, round zero, $4, ordinary Perkeo then Yorick,
fresh X1/23-discard Yorick, and no consumables. A fresh simulator world supplies
hidden cards/RNG. No Charm/Soul rolls are executed or reproduced; this is NOT an
actual seed-equivalent opening, retail replay, or source-validated full game.
Constructing this class consumes one preregistered simulator episode.

The base environment's public projection, concrete candidates, fidelity guards,
caps, and final-boss win latch remain in force. Objective status is public input.
Reward is the number of DISTINCT known-missing held vanilla Joker keys only at a
verified qualifying simulator win. No separate win bonus and no actual awards.
"""
from __future__ import annotations

from .environment import Environment, _catalog_ids, UnsupportedState
from .objective import CompletionGoal
from jackdaw.engine.card import Card
from jackdaw.engine.actions import GamePhase

GLOBAL_DIM, ENTITY_DIM, CANDIDATE_DIM = 530, 67, 163
SCOPE = "public_conditioned_post_soul_training"
OPENING_KEYS = ("j_perkeo", "j_yorick")
OPENING_REFERENCE = {
    "seed": "YAEARC31", "file": "session-20260916T144933Z-1-000010.brj",
    "sequence": 2201,
    "event_sha256": "beb7d6c50e34d1175cc2577c71bb2178e88d3dc03a9b7cc3726dc988d696c89f",
}


def _install_public_opening(gs: dict) -> None:
    """Install only the declared public scaffold on a freshly initialized world.

    This does not step the simulator, consume RNG, open packs, pre-grow a Joker,
    grant shops/vouchers/cash beyond the reference, or replace the hidden deck.
    """
    if (gs.get("stake") != 8 or gs.get("round", 0) != 0
            or gs.get("round_resets", {}).get("ante") != 1
            or gs.get("challenge") or gs.get("jokers") or gs.get("consumables")):
        raise UnsupportedState("specialized_opening_requires_fresh_red_gold_state")
    gs["phase"] = GamePhase.BLIND_SELECT
    gs["blind_on_deck"] = "Big"
    gs["round_resets"]["blind_states"] = {
        "Small": "Skipped", "Big": "Select", "Boss": "Upcoming"}
    gs["skips"], gs["round"], gs["dollars"], gs["chips"] = 1, 0, 4, 0
    gs["won"] = False
    # This flag models eligibility of the observed normal filtered public run.
    # It is synthetic, is explicitly labelled below, and cannot award a profile.
    gs["seeded"] = False
    gs["challenge"] = None
    gs["blind"] = None
    for area in ("hand", "discard_pile", "consumables", "pack_cards",
                 "shop_cards", "shop_vouchers", "shop_boosters"):
        gs[area] = []
    gs["pack_choices_remaining"] = 0
    gs["last_tarot_planet"] = None
    for key in OPENING_KEYS:
        card = Card()
        card.set_ability(key, hands_played=0)
        card.set_cost()
        if card.cost != 20 or card.sell_cost != 10:
            raise UnsupportedState("specialized_opening_catalog_cost_changed")
        if key == "j_yorick" and (card.ability.get("yorick_discards") != 23
                or card.ability.get("extra") != {"discards": 23, "xmult": 1}):
            raise UnsupportedState("specialized_opening_yorick_defaults_changed")
        card.add_to_deck(gs)
        gs.setdefault("jokers", []).append(card)
        gs.setdefault("used_jokers", {})[key] = True
    # Consumed Soul is not retained in used_jokers: the pinned pack-use path
    # calls _release_used_key. No last Tarot/Planet is created by a Soul.


class SpecializedEnvironment(Environment):
    def __init__(self, seed: str, deck: str = "b_red", stake: int = 8,
                 max_steps: int = 800, *, goal_spec: dict):
        if deck != "b_red" or type(stake) is not int or stake != 8:
            raise ValueError("Specialized environment requires Red Deck / Gold Stake")
        self._goal = CompletionGoal.from_spec(goal_spec)
        super().__init__(seed, deck, stake, max_steps)
        _install_public_opening(self._gs)

    def observe(self):
        observation = self._goal.augment(super().observe(), _catalog_ids)
        self._last_observation = observation
        return observation

    def _info(self, outcome: str, **kwargs) -> dict:
        return {**super()._info(outcome, **kwargs), "scope": SCOPE,
                "objective": "completionist_distinct_v1",
                "simulated": True, "actual_awards": 0,
                "goal_digest": self._goal.digest, "new_gold_keys": [],
                "new_gold_count": 0,
                "seed_equivalent_opening": False,
                "opening_reference": dict(OPENING_REFERENCE)}

    def step(self, index: int):
        observation, _base_reward, terminated, truncated, info = super().step(index)
        gs = self._gs
        won = (terminated and not truncated and info.get("outcome") == "win"
               and self._won_latched and info.get("won") is True)
        eligible = (type(gs.get("stake")) is int and gs["stake"] == 8
                    and gs.get("seeded") is False and not gs.get("challenge")
                    and gs.get("win_ante", 8) == 8)
        # Terminal award accounting is not a candidate feature or future-state
        # query. Duplicate physical copies count once, irrespective of stickers.
        keys = ([card.center_key for card in gs.get("jokers", [])]
                if won and eligible else [])
        new_keys = self._goal.missing_held(keys, eligible=eligible, won=won)
        info["new_gold_keys"] = list(new_keys)
        info["new_gold_count"] = len(new_keys)
        return observation, float(len(new_keys)), terminated, truncated, info
