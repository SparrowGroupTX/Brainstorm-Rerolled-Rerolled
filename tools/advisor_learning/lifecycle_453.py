"""In-memory repair for the narrow, plain-Juggler round-end expiry transition.

Pinned upstream remains untouched. Broad episode censorship stays in force.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

PATCH_ID = "development453-plain-juggler-expiry-v1"
ROUND_LIFECYCLE_SHA256 = "8297786eb523127fe95304f1de8829aa7d93fb56e2819b93aab8cb04862e85dd"


def _card_state(card: Any, game_state: dict[str, Any]) -> dict[str, Any]:
    return {
        "cash": game_state.get("dollars", 0),
        "hand_size": game_state.get("hand_size", 0),
        "tally": card.ability.get("perish_tally", card.perish_tally),
        "debuff": bool(card.debuff),
    }


def install_round_end_patch(sim_root: Path | str) -> str:
    """Patch only the pinned maintenance function, preserving its other rules."""
    from jackdaw.engine import round_lifecycle as lifecycle

    expected_path = Path(sim_root).resolve() / "jackdaw" / "engine" / "round_lifecycle.py"
    if Path(lifecycle.__file__).resolve() != expected_path:
        raise RuntimeError("Round-end patch target differs from configured engine")
    if hashlib.sha256(expected_path.read_bytes()).hexdigest() != ROUND_LIFECYCLE_SHA256:
        raise RuntimeError("Simulator source drift: round_lifecycle.py")
    prior = getattr(lifecycle, "_advisor_lifecycle_patch_id", None)
    if prior == PATCH_ID:
        return PATCH_ID
    if prior is not None:
        raise RuntimeError("Conflicting round-end overlay: " + str(prior))
    original = lifecycle.process_round_end_cards

    def process_round_end_cards(jokers, game_state):
        # Upstream already loops in row order. Single-card calls let an expiry
        # settle before the next rental, as in the retained source loop.
        combined = lifecycle.RoundEndResult()
        trace = game_state.get("_advisor_lifecycle_trace")
        for joker in jokers:
            before = _card_state(joker, game_state) if isinstance(trace, list) else None
            active_plain_juggler = (
                joker.center_key == "j_juggler"
                and joker.edition is None
                and not joker.debuff
                and bool(joker.perishable or joker.ability.get("perishable"))
                and joker.ability.get("perish_tally", joker.perish_tally) == 1
                and joker.ability.get("h_size") == 1
            )
            result = original([joker], game_state)
            combined.perished.extend(result.perished)
            combined.rental_cost += result.rental_cost
            combined.rental_cards.extend(result.rental_cards)
            if active_plain_juggler and joker in result.perished:
                # Source set_debuff removes passive effects once on the
                # active->debuffed transition. Juggler has only h_size here.
                game_state["hand_size"] = game_state.get("hand_size", 0) - joker.ability["h_size"]
            if isinstance(trace, list):
                trace.append({
                    "phase": "round_end", "event": "joker_maintenance_settled",
                    "physical_id": joker.sort_id, "center_key": joker.center_key,
                    "before": before, "after": _card_state(joker, game_state),
                })
        return combined

    lifecycle._advisor_original_round_end_cards = original
    lifecycle.process_round_end_cards = process_round_end_cards
    lifecycle._advisor_lifecycle_patch_id = PATCH_ID
    return PATCH_ID
