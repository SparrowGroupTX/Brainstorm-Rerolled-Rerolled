"""Narrow, source-grounded overlay for the pinned candidate simulator.

No episode initialization, file writes, source archive access, or game execution.
These repairs do NOT qualify the engine. See SIMULATOR_FIDELITY_AUDIT.md.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

PATCH_ID = "development455-source-fidelity-v4"
UPSTREAM_HASHES = {
    "jokers.py": "9b4c7ec916ea3e0a72a9e836be085dae6ac09606d187ff8abbc4d6e902e98fc7",
    "card.py": "690a7b50f294f9429e6b76a7ee9e37b96da9c24db6328b3903a02d605bda9486",
}
PATCHES = (
    "burnt_pre_discard_and_copy",
    "perkeo_copy",
    "sticker_compatibility_and_exclusion",
    "expired_perishable_debuff_latch",
    "plain_juggler_round_end_passive_removal",
    "plain_golden_final_life_cashout_bonus",
    "cash_out_shop_entry_bookkeeping",
)


def _flag(card: Any, name: str) -> bool:
    return bool(getattr(card, name, False) or getattr(card, "ability", {}).get(name))


def _tally(card: Any) -> int:
    return int(getattr(card, "ability", {}).get("perish_tally", getattr(card, "perish_tally", 5)))


def apply_patches(sim_root: Path | str) -> str:
    """Apply once to already importable Jackdaw, rejecting source drift.

    Supports the pinned checkout or an identical frozen experiment copy.
    This modifies Python objects in memory, never the upstream files.
    """
    from jackdaw.engine import card as C, jokers as J
    from .lifecycle_453 import install_round_end_patch
    from .lifecycle_454 import install_golden_cashout_patch
    from .lifecycle_455 import install_cash_out_patch

    engine = Path(sim_root).resolve() / "jackdaw" / "engine"
    for module in (C, J):
        path = Path(module.__file__).resolve()
        if path.parent != engine:
            raise RuntimeError("Simulator patch target differs from configured engine")
        if hashlib.sha256(path.read_bytes()).hexdigest() != UPSTREAM_HASHES[path.name]:
            raise RuntimeError("Simulator source drift: " + path.name)
    prior = getattr(J, "_brainstorm_patch_id", None)
    if prior == PATCH_ID:
        install_round_end_patch(sim_root)
        install_golden_cashout_patch(sim_root)
        install_cash_out_patch(sim_root)
        return PATCH_ID
    if prior is not None:
        raise RuntimeError("Conflicting simulator overlay: " + str(prior))

    def burnt(card, ctx):
        # Preserved card.lua:2749-2755. No blueprint exclusion: each
        # physical/copy Joker receives one pre_discard event, not one/card.
        if ctx.pre_discard and ctx.game.discards_used <= 0 and not ctx.hook:
            return J.JokerResult(level_up=True)
        return None

    def perkeo(card, ctx):
        # Preserved card.lua:2412-2424. The shop mutation consumer checks
        # inventory and applies descriptors in row order, growing the pool.
        if ctx.ending_shop and ctx.game.consumable_count > 0:
            return J.JokerResult(extra={"create": {
                "type": "consumable_copy", "edition": "negative", "key": "perkeo"}})
        return None

    def set_eternal(card, eternal):
        # Preserved card.lua:506-511. Failed application clears this sticker.
        card.eternal = False
        card.ability.pop("eternal", None)
        center = C._resolve_center(card.center_key)
        if center.get("eternal_compat", False) and not _flag(card, "perishable"):
            card.eternal = bool(eternal)
            card.ability["eternal"] = bool(eternal)

    def set_perishable(card, perishable):
        # Preserved card.lua:513-519 ignores its argument, applying true if
        # compatible. This overlay supports the default five-round lifetime;
        # audit_state_boundary rejects nondefault lifetimes.
        card.perishable = False
        card.ability.pop("perishable", None)
        center = C._resolve_center(card.center_key)
        if center.get("perishable_compat", False) and not _flag(card, "eternal"):
            card.perishable = True
            card.perish_tally = 5
            card.ability.update(perishable=True, perish_tally=5)

    original_debuff = C.Card.set_debuff

    def set_debuff(card, should_debuff):
        # Preserved card.lua:526-533. Only the permanent-expiration latch is
        # repaired here; passive add/remove side effects remain censored.
        if _flag(card, "perishable") and _tally(card) <= 0:
            card.debuff = True
        else:
            original_debuff(card, should_debuff)

    install_round_end_patch(sim_root)
    install_golden_cashout_patch(sim_root)
    install_cash_out_patch(sim_root)
    J._REGISTRY["j_burnt"] = burnt
    J._REGISTRY["j_perkeo"] = perkeo
    C.Card.set_eternal = set_eternal
    C.Card.set_perishable = set_perishable
    C.Card.set_debuff = set_debuff
    J._brainstorm_patch_id = PATCH_ID
    return PATCH_ID


# Card.add/remove_from_deck effects whose debuff transitions need run state.
_PASSIVE_KEYS = frozenset({
    "j_credit_card", "j_chaos", "j_turtle_bean", "j_oops", "j_to_the_moon",
    "j_troubadour", "j_stuntman",
})


def audit_state_boundary(gs: dict[str, Any]) -> str | None:
    """Latch conservative audit-only truncation, never change action ranking.

    Call before observation and before/after transitions. Reads simulator
    internals solely to reject the WHOLE episode, not to reveal them to policy.
    Expiration is censored at tally <= 1, ahead of the potentially bad round.
    """
    reason = gs.get("learning_unsupported")
    if reason:
        return str(reason)
    jokers = gs.get("jokers", [])
    if gs.get("perishable_rounds", 5) != 5:
        reason = "fidelity_nondefault_perishable_lifetime"
    for card in jokers:
        if reason:
            break
        ability = getattr(card, "ability", {})
        if _flag(card, "perishable") and _tally(card) <= 1:
            # Upstream batches all end-of-round Joker callbacks before all
            # expiry events; source interleaves them per Joker. Also expiry
            # omits passive remove_from_deck. Do not continue through either.
            reason = "fidelity_perishable_expiry_order"
        elif getattr(card, "debuff", False) and (
            getattr(card, "center_key", "") in _PASSIVE_KEYS
            or ability.get("h_size", 0) or ability.get("d_size", 0)
        ):
            reason = "fidelity_debuff_passive_side_effects"

    # Source state_events held-card repetition loop is absent from upstream
    # game._round_won: Mime repeats held Gold/Blue effects.
    active_mime = any(getattr(j, "center_key", "") == "j_mime"
                      and not getattr(j, "debuff", False) for j in jokers)
    if not reason:
        for card in gs.get("hand", []):
            if getattr(card, "debuff", False):
                continue
            ability = getattr(card, "ability", {})
            blue = getattr(card, "seal", None) == "Blue"
            # A card cannot have both Red and Blue seals. Red on Gold is
            # already implemented upstream. Only Mime needs a guard here.
            if active_mime and (blue or ability.get("h_dollars", 0)):
                reason = "fidelity_mime_round_end_repetition"
                break
    if reason:
        gs["learning_unsupported"] = reason
        return str(reason)
    return None
