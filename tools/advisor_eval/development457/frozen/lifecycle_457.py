"""Source-grounded physical booster slots for the pinned shop simulator.

Qualifies a narrow no-tag, plain-price family at the settled shop boundary.
Original-source Game:update_shop and pack opening are not executed here.
"""
from __future__ import annotations

import hashlib
from pathlib import Path


PATCH_ID = "development457-booster-slot-lifecycle-v1"
SHOP_SHA256 = "ce45ba3936151f8098ea2204be0daba781176d4d24d3a071c71c381b37bf5d0f"
GAME_SHA256 = "05ba662b03be86b7e879d9ef001844522497afe9653029e4da5251971bbb009c"


def install_booster_slot_patch(sim_root: Path | str) -> str:
    from jackdaw.engine import game as G, shop as S

    engine = Path(sim_root).resolve() / "jackdaw" / "engine"
    for module, name, expected_hash in ((G, "game.py", GAME_SHA256),
                                        (S, "shop.py", SHOP_SHA256)):
        path = engine / name
        if Path(module.__file__).resolve() != path:
            raise RuntimeError("Booster-slot patch target differs from configured engine")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
            raise RuntimeError("Simulator source drift: " + name)
    prior = getattr(S, "_advisor_booster_slot_patch_id", None)
    if prior == PATCH_ID:
        return PATCH_ID
    if prior is not None or getattr(G, "_advisor_booster_slot_patch_id", None) is not None:
        raise RuntimeError("Conflicting booster-slot overlay")

    original_populate = S.populate_shop
    original_open = G._handle_open_booster

    def populate_shop(rng, ante, gs):
        # Preserve the pinned Joker/voucher construction. The booster branch
        # below implements game.lua:3145-57 without unconditional pack draws.
        from jackdaw.engine.card import Card
        from jackdaw.engine.card_factory import create_card, create_voucher

        shop_joker_max = gs.get("shop", {}).get("joker_max", 2)
        banned_keys = set(gs.get("banned_keys") or {})
        has_illusion = bool((gs.get("used_vouchers") or {}).get("v_illusion"))
        jokers = []
        for _ in range(shop_joker_max):
            tag_card = S.apply_store_joker_create_tag(gs, rng, ante)
            if tag_card is not None:
                jokers.append(tag_card)
                continue
            card_type = S.select_shop_card_type(
                rng, ante,
                joker_rate=gs.get("joker_rate", 20.0),
                tarot_rate=gs.get("tarot_rate", 4.0),
                planet_rate=gs.get("planet_rate", 4.0),
                spectral_rate=gs.get("spectral_rate", 0.0),
                playing_card_rate=gs.get("playing_card_rate", 0.0),
                has_illusion=has_illusion,
            )
            card = create_card(
                card_type, rng, ante, area="shop", soulable=False,
                append=S._SHOP_APPEND, game_state=gs,
            )
            if card_type in ("Base", "Enhanced") and has_illusion:
                S.apply_illusion_shop_edition(rng, card)
            jokers.append(card)

        voucher = None
        voucher_key = gs.get("current_round", {}).get("voucher")
        if voucher_key:
            voucher = create_voucher(voucher_key)
            voucher.set_cost(
                inflation=gs.get("inflation", 0),
                discount_percent=gs.get("discount_percent", 0),
                ante=ante,
            )

        current_round = gs.setdefault("current_round", {})
        used_packs = current_round.setdefault("used_packs", [])
        if not isinstance(used_packs, list):
            raise TypeError("Expected list-backed current_round.used_packs")
        boosters = []
        for slot in (1, 2):
            key = used_packs[slot - 1] if slot <= len(used_packs) else None
            if key is None or key is False:
                first_shop = not gs.get(S._FIRST_SHOP_BUFFOON_KEY, False)
                key = S.get_pack(
                    rng, ante, "shop_pack", first_shop=first_shop,
                    banned_keys=banned_keys,
                )
                if first_shop and S._FIRST_SHOP_BUFFOON_PACK not in banned_keys:
                    gs[S._FIRST_SHOP_BUFFOON_KEY] = True
                if slot <= len(used_packs):
                    used_packs[slot - 1] = key
                else:
                    used_packs.append(key)
            if key == "USED":
                continue
            card = Card()
            card.set_ability(key)
            card.set_cost(
                inflation=gs.get("inflation", 0),
                discount_percent=gs.get("discount_percent", 0),
                ante=ante,
                booster_ante_scaling=gs.get("booster_ante_scaling", False),
                has_astronomer=S.astronomer_active(gs),
            )
            card.ability["booster_pos"] = slot
            boosters.append(card)

        return {"jokers": jokers, "voucher": voucher, "boosters": boosters}

    def open_booster(gs, idx):
        # button_callbacks.lua:2242 marks the physical slot consumed. The
        # candidate action index addresses the compact list of live offers.
        boosters = gs.get("shop_boosters", [])
        position = None
        if 0 <= idx < len(boosters):
            card = boosters[idx]
            position = card.ability.get("booster_pos")
            if position is not None:
                used_packs = gs.get("current_round", {}).get("used_packs", [])
                if (not isinstance(position, int) or position not in (1, 2)
                        or len(used_packs) < position
                        or used_packs[position - 1] != card.center_key):
                    raise RuntimeError("Booster physical slot disagrees with stored pack key")
        result = original_open(gs, idx)
        if position is not None:
            gs["current_round"]["used_packs"][position - 1] = "USED"
        return result

    S._advisor_original_populate_shop = original_populate
    G._advisor_original_open_booster = original_open
    S.populate_shop = populate_shop
    G._handle_open_booster = open_booster
    S._advisor_booster_slot_patch_id = PATCH_ID
    G._advisor_booster_slot_patch_id = PATCH_ID
    return PATCH_ID
