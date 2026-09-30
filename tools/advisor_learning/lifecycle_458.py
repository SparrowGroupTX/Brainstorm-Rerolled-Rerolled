"""Move physical booster consumption before opening callbacks.

Original button_callbacks.lua:2242 marks used_packs before Card:open at 2247.
This covers that ordering within the pinned Python opening handler only.
"""
from __future__ import annotations

import hashlib
from pathlib import Path


PATCH_ID = "development458-booster-open-order-v1"
GAME_SHA256 = "05ba662b03be86b7e879d9ef001844522497afe9653029e4da5251971bbb009c"
SLOT_OVERLAY_SHA256 = "2bfef93040a2e31539fdfeefad2ce091a0ab9ee03b72b3cc97f786cdb052ee53"


def install_booster_open_order_patch(sim_root: Path | str) -> str:
    from jackdaw.engine import game as G
    from . import lifecycle_457

    engine = Path(sim_root).resolve() / "jackdaw" / "engine"
    game_path = engine / "game.py"
    if Path(G.__file__).resolve() != game_path or hashlib.sha256(
            game_path.read_bytes()).hexdigest() != GAME_SHA256:
        raise RuntimeError("Booster-open patch target drift")
    if hashlib.sha256(Path(lifecycle_457.__file__).read_bytes()).hexdigest() != SLOT_OVERLAY_SHA256:
        raise RuntimeError("Booster-slot overlay drift")
    if getattr(G, "_advisor_booster_slot_patch_id", None) != lifecycle_457.PATCH_ID:
        raise RuntimeError("Booster-slot patch must be installed first")
    prior = getattr(G, "_advisor_booster_open_order_patch_id", None)
    if prior == PATCH_ID:
        return PATCH_ID
    if prior is not None:
        raise RuntimeError("Conflicting booster-open-order overlay")

    previous_open = G._handle_open_booster
    pinned_open = G._advisor_original_open_booster

    def open_booster(gs, idx):
        # Recheck the pinned handler's reject conditions before changing the
        # physical slot. A rejected action must leave both cash and slot intact.
        G._require_phase(gs, G.GamePhase.SHOP)
        boosters = gs.get("shop_boosters", [])
        if idx < 0 or idx >= len(boosters):
            raise G.IllegalActionError(f"Invalid booster index {idx}")
        pack = boosters[idx]
        if pack.cost > gs.get("dollars", 0):
            raise G.IllegalActionError("Cannot afford booster")

        position = pack.ability.get("booster_pos")
        if position is not None:
            used_packs = gs.get("current_round", {}).get("used_packs", [])
            if (not isinstance(position, int) or position not in (1, 2)
                    or not isinstance(used_packs, list) or len(used_packs) < position
                    or used_packs[position - 1] != pack.center_key):
                raise RuntimeError("Booster physical slot disagrees with stored pack key")
            used_packs[position - 1] = "USED"
        return pinned_open(gs, idx)

    G._advisor_previous_open_booster_457 = previous_open
    G._handle_open_booster = open_booster
    G._advisor_booster_open_order_patch_id = PATCH_ID
    return PATCH_ID
