# Slice 457: physical booster slots in a no-tag shop

Acceptance fixed before the repair. Read-only original source:
`game.lua:3145-3157`, `functions/button_callbacks.lua:2240-2247`,
`functions/common_events.lua:1944-1960`, and `card.lua:369-383` in the
Balatro archive with SHA-256
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.

At a stable, stocked shop boundary with no tags, voucher, Joker slots,
discounts, inflation, Astronomer, tutorial surcharge, or ante scaling, compare:

1. Ordered physical slot decisions for slots 1 and 2: reuse a stored key,
   draw a prescribed key only for an empty slot, suppress `'USED'`.
2. Persisted `current_round.used_packs`, including physical positions and
   exact count/order of prescribed `get_pack` outcomes consumed.
3. Offered pack key, `ability.booster_pos`, ordinary price, and affordable
   `OpenBooster` legal indices. Compact action indices must not replace physical
   slot identity.
4. On opening a legal offered pack, mark its physical slot `'USED'`; a later
   shop population within the same round must not create a replacement there.

Use a handwritten source-rule state/event model independent of the pinned
candidate and record first differences from the unpatched baseline and repaired
candidate. Include stored/used/empty/mixed and held-out gap/reversed-slot
fixtures. The manufactured pack picker must reject unexpected or extra calls.
Set `first_shop_buffoon=true` in this family, leaving its nondeterministic
variant and first-shop distribution outside the claim.

The source Lua runner also must preserve complete structured output ordering
across C/Python buffering on success and failure. Verify with manufactured
Lua output larger than the native buffer; retain the exact pre-fix runner
bytes under development456/frozen so the historical receipt remains
reconstructable. This test does not execute original game source.

Out of scope: original-source worker execution, full `Game:update_shop`
event timing, tag hooks, voucher/Joker pools, broader pricing modifiers,
RNG distribution or seed parity, pack contents, pack-exit/Perkeo copying,
next blind, episodes, training, and whole-game win rate.
