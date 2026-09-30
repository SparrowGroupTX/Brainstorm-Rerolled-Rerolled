"""Independent source-derived settled-boundary model for plain Golden rows.

Rental scheduling is distinguished from its later settled balance. This is a
handwritten expectation, not executed original-source parity.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any


def _card_view(card: dict[str, Any]) -> dict[str, Any]:
    return {"tally": card["tally"], "debuff": card["debuff"]}


def source_rule_reference(fixture: dict[str, Any], rental_rate: int = 3) -> dict[str, Any]:
    row = deepcopy(fixture["jokers"])
    if not row or any(card["center_key"] not in {"j_golden", "j_joker"}
                      or card["edition"] is not None for card in row):
        raise ValueError("Reference family excludes this row")
    events = []
    rental_requests = 0
    for card in row:
        before = _card_view(card)
        if card["rental"]:
            rental_requests += 1
        if card["perishable"] and card["tally"] > 0:
            card["tally"] -= 1
            if card["tally"] == 0:
                card["debuff"] = True
        events.append({"phase": "round_end", "event": "joker_maintenance_settled",
                       "physical_id": card["physical_id"],
                       "rental_requested": card["rental"],
                       "before": before, "after": _card_view(card)})
    settled_cash = fixture["cash"] - rental_requests * rental_rate
    events.append({"phase": "round_end", "event": "rental_queue_settled",
                   "requests": rental_requests, "cash_before": fixture["cash"],
                   "cash_after": settled_cash})
    bonus = sum(4 for card in row if card["center_key"] == "j_golden"
                and not card["debuff"])
    events.append({"phase": "cashout_eval", "event": "joker_bonus_total",
                   "dollars": bonus})
    interest = min(settled_cash // 5, 5) if settled_cash >= 5 else 0
    reward = bonus + interest
    events.append({"phase": "cashout_eval", "event": "earnings",
                   "joker_dollars": bonus, "interest": interest, "total": reward})
    events.append({"phase": "cashout_paid", "event": "payment",
                   "cash_before": settled_cash, "cash_after": settled_cash + reward})
    return {"events": events,
            "state": {"phase": "cashout_paid", "cash": settled_cash + reward,
                      "jokers": row}}
