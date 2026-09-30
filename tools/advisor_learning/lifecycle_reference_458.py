"""Source-derived selected Booster use order, no simulator imports."""
from __future__ import annotations


def source_rule_open_callback(initial_used: list[str], *, slot: int,
                              key: str, cash: int, price: int) -> dict:
    """button_callbacks.lua:2242 writes USED before Card:open at 2247."""
    if initial_used[slot - 1] != key or cash < price:
        raise ValueError("Invalid manufactured opening fixture")
    after = list(initial_used)
    after[slot - 1] = "USED"
    return {
        "events": [{"event": "opening_callback_input", "slot": slot,
                    "stored_key": after[slot - 1]}],
        "state": {"used_packs": after, "cash": cash - price,
                  "phase": "pack_opening"},
    }
