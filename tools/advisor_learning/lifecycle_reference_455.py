"""Independent source-derived settled cash-out/shop bookkeeping model.

This is handwritten from button_callbacks.lua:2912-2956. It does not execute
the original Lua callback or model queue frames, shop stock, tags, or RNG.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any


def source_rule_reference(fixture: dict[str, Any]) -> dict[str, Any]:
    cash = fixture["cash"] + fixture["earnings_total"]
    current_round = deepcopy(fixture["current_round"])
    resets = fixture["round_resets"]
    bonus = fixture["round_bonus"]
    current_round["jokers_purchased"] = 0
    current_round["discards_left"] = max(0, resets["discards"] + bonus["discards"])
    current_round["hands_left"] = max(1, resets["hands"] + bonus["next_hands"])
    previous_round = deepcopy(fixture["previous_round"])
    previous_round["dollars"] = cash
    stock_input = {
        "cash": cash,
        "shop_phase": "shop",
        "hands_left": current_round["hands_left"],
        "discards_left": current_round["discards_left"],
        "jokers_purchased": current_round["jokers_purchased"],
        "shop_free_present": False,
        "shop_d6ed_present": False,
        "previous_round": deepcopy(previous_round),
    }
    return {
        "events": [
            {"phase": "cash_out", "event": "payment_settled",
             "cash_before": fixture["cash"], "delta": fixture["earnings_total"],
             "cash_after": cash},
            {"phase": "shop_entry", "event": "shop_population_input",
             **stock_input},
        ],
        "state": {
            "phase": "shop", "cash": cash,
            "current_round": current_round,
            "round_resets": deepcopy(resets),
            "round_bonus": deepcopy(bonus),
            "previous_round": previous_round,
            "shop_free_present": False,
            "shop_d6ed_present": False,
            "shop_cards": [], "shop_vouchers": [], "shop_boosters": [],
        },
    }
