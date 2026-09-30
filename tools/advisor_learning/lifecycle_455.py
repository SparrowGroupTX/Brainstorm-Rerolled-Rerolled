"""Source-grounded cash-out shop-entry bookkeeping for pinned Jackdaw.

Only settled fields are qualified. This wrapper does not model source event
frames, shop stock generation, tags, blind resets, or RNG equivalence.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

PATCH_ID = "development455-shop-entry-bookkeeping-v1"
GAME_SHA256 = "05ba662b03be86b7e879d9ef001844522497afe9653029e4da5251971bbb009c"


def install_cash_out_patch(sim_root: Path | str) -> str:
    from jackdaw.engine import game as G

    expected_path = Path(sim_root).resolve() / "jackdaw" / "engine" / "game.py"
    if Path(G.__file__).resolve() != expected_path:
        raise RuntimeError("Cash-out patch target differs from configured engine")
    if hashlib.sha256(expected_path.read_bytes()).hexdigest() != GAME_SHA256:
        raise RuntimeError("Simulator source drift: game.py")
    prior = getattr(G, "_advisor_shop_entry_patch_id", None)
    if prior == PATCH_ID:
        return PATCH_ID
    if prior is not None:
        raise RuntimeError("Conflicting shop-entry overlay: " + str(prior))
    original = G._handle_cash_out

    def _handle_cash_out(gs):
        # This is the pinned handler's small cash-out path with the shop-entry
        # block from button_callbacks.lua:2928-33 inserted after shuffle and
        # before payment/stock. Exact upstream hashing prevents silent drift.
        G._require_phase(gs, G.GamePhase.ROUND_EVAL)
        rng = gs.get("rng")
        if rng:
            from jackdaw.engine.round_lifecycle import reset_round_targets

            ante = gs.get("round_resets", {}).get("ante", 1)
            reset_round_targets(rng, ante, gs)
            deck: list = gs.get("deck", [])
            cashout_seed = rng.seed("cashout" + str(ante))
            rng.shuffle(deck, cashout_seed)

        cr = gs["current_round"]
        rr = gs["round_resets"]
        rb = gs["round_bonus"]
        cr["jokers_purchased"] = 0
        cr["discards_left"] = max(0, rr["discards"] + rb["discards"])
        cr["hands_left"] = max(1, rr["hands"] + rb["next_hands"])
        gs.pop("shop_free", None)
        gs.pop("shop_d6ed", None)

        earnings = gs.get("round_earnings")
        if earnings:
            gs["dollars"] = gs.get("dollars", 0) + earnings.total

        # Retain the pinned tag-payment path. Tags are outside this fixture
        # family; their ordering and shop effects are not qualified here.
        if gs.get("last_blind_was_boss"):
            from jackdaw.engine.tags import Tag

            for entry in gs.get("awarded_tags", []):
                if entry.get("eval_fired"):
                    continue
                result = Tag(entry.get("key", "")).apply(
                    "eval", gs, rng=rng, last_blind_is_boss=True)
                if result is not None and result.dollars:
                    gs["dollars"] = gs.get("dollars", 0) + result.dollars
                    entry["eval_fired"] = True

        # Source assigns a field, so the shop sees all other fields and the
        # same previous_round table, before stock generation begins.
        gs["previous_round"]["dollars"] = gs.get("dollars", 0)
        gs["phase"] = G.GamePhase.SHOP
        G._populate_shop(gs)
        return gs

    G._advisor_original_cash_out = original
    G._handle_cash_out = _handle_cash_out
    G._advisor_shop_entry_patch_id = PATCH_ID
    return PATCH_ID
