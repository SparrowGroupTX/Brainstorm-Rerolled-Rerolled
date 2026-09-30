"""Handwritten source-rule model for manufactured no-tag booster slots.

Read from original game.lua:3145-57, button_callbacks.lua:2240-47,
game.lua:665/673/685 and card.lua:369-83. No Jackdaw imports.
"""
from __future__ import annotations

from copy import deepcopy


NORMAL_PACK_COST = {
    "p_arcana_normal_1": 4,
    "p_celestial_normal_1": 4,
    "p_standard_normal_1": 4,
}


def source_rule_stock(fixture: dict) -> dict:
    used = deepcopy(fixture["used_packs"])
    draws = iter(fixture["draws"])
    draw_events = []
    offers = []
    for slot in (1, 2):
        key = used[slot - 1] if slot <= len(used) else None
        if key is None or key is False:
            key = next(draws)
            draw_events.append({"event": "pack_draw", "slot": slot, "key": key})
            if slot <= len(used):
                used[slot - 1] = key
            else:
                used.append(key)
        if key == "USED":
            continue
        offers.append({"slot": slot, "key": key, "price": NORMAL_PACK_COST[key]})
    try:
        next(draws)
    except StopIteration:
        pass
    else:
        raise ValueError("Fixture has an unused prescribed pack draw")
    return {
        "events": draw_events + [
            {"event": "booster_offer", **offer} for offer in offers
        ],
        "state": {
            "used_packs": used,
            "offers": offers,
            "cash": fixture["cash"],
            "legal_open_indices": [
                i for i, offer in enumerate(offers)
                if offer["price"] <= fixture["cash"]
            ],
        },
    }


def source_rule_open(stock: dict, index: int) -> dict:
    state = deepcopy(stock["state"])
    offer = state["offers"].pop(index)
    if offer["price"] > state["cash"]:
        raise ValueError("Manufactured action is unaffordable")
    state["cash"] -= offer["price"]
    state["used_packs"][offer["slot"] - 1] = "USED"
    state = {"used_packs": state["used_packs"], "offers": state["offers"],
             "cash": state["cash"], "phase": "pack_opening"}
    return {"events": [{"event": "booster_open", "slot": offer["slot"],
                        "key": offer["key"], "price": offer["price"]}],
            "state": state}
