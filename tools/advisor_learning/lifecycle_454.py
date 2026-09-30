"""Narrow in-memory Golden Joker final-life cash-out correction.

This does not qualify general end-of-round callback or event-queue behavior.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

PATCH_ID = "development454-plain-golden-final-life-v1"
GAME_SHA256 = "05ba662b03be86b7e879d9ef001844522497afe9653029e4da5251971bbb009c"


def _eligible_row(jokers: list[Any]) -> bool:
    """Only dollar-only Golden and inert ordinary Joker callbacks are in scope."""
    return bool(jokers) and any(j.center_key == "j_golden" for j in jokers) and all(
        j.center_key in {"j_golden", "j_joker"}
        and j.edition is None
        and not j.ability.get("rental")  # native top-level rental only
        for j in jokers
    )


def install_golden_cashout_patch(sim_root: Path | str) -> str:
    from jackdaw.engine import game as G, jokers as J

    expected_path = Path(sim_root).resolve() / "jackdaw" / "engine" / "game.py"
    if Path(G.__file__).resolve() != expected_path:
        raise RuntimeError("Cash-out patch target differs from configured engine")
    if hashlib.sha256(expected_path.read_bytes()).hexdigest() != GAME_SHA256:
        raise RuntimeError("Simulator source drift: game.py")
    prior = getattr(G, "_advisor_golden_cashout_patch_id", None)
    if prior == PATCH_ID:
        return PATCH_ID
    if prior is not None:
        raise RuntimeError("Conflicting cash-out overlay: " + str(prior))
    original = G._joker_end_of_round_effects

    def _joker_end_of_round_effects(gs):
        # The pinned function performs callbacks and maintenance, but its
        # dollar total was computed before a final-life expiry. In this
        # restricted row, callbacks have no mutation and Golden's bonus
        # depends only on its post-maintenance debuff and fixed extra.
        supported = _eligible_row(gs.get("jokers", []))
        result = original(gs)
        if supported:
            cr = gs.get("current_round", {})
            snap = J.GameSnapshot(
                money=gs.get("dollars", 0),
                hands_left=cr.get("hands_left", 0),
                discards_left=cr.get("discards_left", 0),
            )
            result["dollars_earned"] = sum(
                J.calc_dollar_bonus(card, snap) for card in gs.get("jokers", []))
        return result

    G._advisor_original_joker_eor = original
    G._joker_end_of_round_effects = _joker_end_of_round_effects
    G._advisor_golden_cashout_patch_id = PATCH_ID
    return PATCH_ID
