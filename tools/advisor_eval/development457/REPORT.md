# Lifecycle slice 457 — physical booster slots

2026-09-29, branch `codex/exact-search-speedups`. This is a manufactured
qualification of a narrow no-tag shop-stock and booster-opening boundary in
the Python learning simulator. Installed451/2.226.0-alpha, the pinned Jackdaw
upstream files, settings, DLLs, public journals, player data and all prior
source receipts were untouched. No original-source worker, episode, full game,
training or Balatro process was run.

## Source finding and repair

Read-only inspection of the exact original archive (SHA-256
`0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`)
found that `game.lua:3145-3157` has two physical booster slots. Each slot
reuses its `current_round.used_packs[i]` key, calls `get_pack` only when empty,
suppresses `'USED'`, and puts physical `booster_pos=i` on a live offer.
`functions/button_callbacks.lua:2242` marks that physical slot `'USED'` when
its booster is used. Normal Arcana, Celestial and Standard packs each have a
source base cost of $4 (`game.lua:665,673,685`); ordinary `Card:set_cost` is
at `card.lua:369-383`. Source member hashes are in the
[manufactured receipt](MANUFACTURED_COMPARISONS.json).

The pinned simulator instead called `get_pack` twice on every population,
offered two packs even for used slots, did not store keys or physical positions,
and removed an opened offer without marking the stored slot. Its first minimal
case, `['USED', 'p_arcana_normal_1']`, made an unexpected pack draw before any
valid offer. An empty-slot control made its second draw against physical slot 1
again because it never stored the first key. The
[baseline receipt](BASELINE_COMPARISONS.json) preserves first differences for
eight stock cases and one opening case.

The [in-memory overlay](../../advisor_learning/lifecycle_457.py) now preserves
the pinned Joker/voucher branch, stocks boosters by physical slot, records
keys, skips used slots, attaches `booster_pos`, and marks that slot used after
a successful `OpenBooster`. It is integrated in
[simulator_patches.py](../../advisor_learning/simulator_patches.py) with
exact hashes for the unchanged pinned `shop.py` and `game.py`. The exact prior
integration bytes are preserved under `development455/frozen` and
`development456/frozen` for historical receipts.

## Independent manufactured comparisons

The [acceptance](ACCEPTANCE.md) preceded the patch. The
[handwritten source-rule model](../../advisor_learning/lifecycle_reference_457.py)
does not import Jackdaw. It compares ordered prescribed pack draws, stored
two-slot state, offered keys and physical positions, plain prices, cash and
legal `OpenBooster` indices. The picker rejects extra calls. Eight fixtures
cover empty, stored, used and mixed slots, an unaffordable shop, a sparse
first slot and reversed stored keys. A separate opening comparison checks
that compact offer index 0 can consume physical slot 2. Same-round
repopulation then leaves that slot empty; unaffordable opening leaves its key
intact. A mutated slot-position negative control is detected.

All **eight** repaired stock cases and **one** repaired opening case agree
with the source-rule model at this settled boundary. The unpatched stock and
opening paths disagree in all **nine** recorded cases. The 34 focused
lifecycle/overlay/runner tests passed, followed by 27 environment integration
tests. These are ordinary manufactured tests, not original-source execution.

The [Lua runner](../../../tests/run_lua_tests.py) now flushes the native UCRT
stdio buffer after each Lua fixture and before Python status lines. Two
manufactured 12 KB Lua records failed the pre-fix ordering test on success
and error paths ([baseline](RUNNER_BASELINE.txt)); both pass after the fix.
The exact pre-fix runner bytes are at
[development456/frozen/run_lua_tests.py](../development456/frozen/run_lua_tests.py)
and match the 456 prepared manifest.
This verifies capture for the tested Balatro Lua 5.1 DLL. The 456 source
attempt remains a preserved `parse_error`, with its separate offline recovery;
it was not rerun or reclassified.

## Supported scope and next gap

The agreement is for manufactured, prescribed pack outcomes in a stable
no-tag shop after the first-shop Buffoon guarantee was consumed. It does not
qualify the Buffoon variant, pack-weight distribution or RNG stream, nor full
`Game:update_shop` event timing, tags, voucher/Joker generation, modified
prices, pack contents, pack-opening callback order, Perkeo shop exit, next
blind, Red Deck/Gold Stake opening population, full-game fidelity, optimality
or win rate. The original callback marks `'USED'` before `Card:open`; this
overlay marks it after the simulator opening handler succeeds, so interacting
callback timing remains a separate gate. The runner's UCRT fix is verified for
the bundled Balatro DLL, not arbitrary alternate Lua libraries.

The next independent gate is a separately bounded original-source booster
branch comparison under prescribed `get_pack` outcomes, followed by tag and
full shop-event qualification. The consumed 454 and 456 one-use source leases
were not reused; a new original-source worker needs a concrete one-use
proposal and fresh numerical authorization. There is no training-readiness
or win-rate claim from this slice.
