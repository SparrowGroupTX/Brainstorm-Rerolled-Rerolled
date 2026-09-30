"""Small independent, source-derived model for the declared manufactured family.

This is handwritten expectation, not executed original game source. It accepts
only plain Juggler/ordinary Joker round-end maintenance with no callbacks.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any


def _card_state(card: dict[str, Any], cash: int, hand_size: int) -> dict[str, Any]:
    return {"cash": cash, "hand_size": hand_size,
            "tally": card["tally"], "debuff": card["debuff"]}


def source_rule_reference(fixture: dict[str, Any], rental_rate: int = 3) -> dict[str, Any]:
    """Model source card.lua 526-538, 2271-2289 and row loop 97-110."""
    row = deepcopy(fixture["jokers"])
    if any(card["center_key"] not in {"j_juggler", "j_joker"}
           or card["edition"] is not None for card in row):
        raise ValueError("Reference family excludes this Joker or edition")
    cash = fixture["cash"]
    hand_size = fixture["hand_size"]
    events = []
    for card in row:
        before = _card_state(card, cash, hand_size)
        # Declared row has no end-of-round calculate_joker mutation.
        if card["rental"]:
            cash -= rental_rate
        if card["perishable"] and card["tally"] > 0:
            card["tally"] -= 1
            if card["tally"] == 0 and not card["debuff"]:
                card["debuff"] = True
                if card["center_key"] == "j_juggler":
                    hand_size -= card["h_size"]
        events.append({
            "phase": "round_end", "event": "joker_maintenance_settled",
            "physical_id": card["physical_id"], "center_key": card["center_key"],
            "before": before, "after": _card_state(card, cash, hand_size),
        })
    return {"events": events,
            "state": {"phase": "round_end", "cash": cash,
                      "hand_size": hand_size, "jokers": row}}
