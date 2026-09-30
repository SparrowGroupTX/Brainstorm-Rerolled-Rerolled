# Lifecycle slice 455 — cash-out bookkeeping at shop entry

2026-09-29. Branch `codex/exact-search-speedups`. This is a manufactured
qualification of the Python learning simulator's `CashOut()` path. Installed
451/2.226.0-alpha, settings, DLLs, public journals and the pinned upstream355
checkout were left untouched. The user's actual Red Deck/Gold Stake
Perkeo/Yorick win-first opening and full game are outside this small fixture
family.

## Source finding and mismatch

Read-only inspection of original `functions/button_callbacks.lua:2912-2956`
found that cash-out enters the shop after resetting purchase count to 0,
hands to `max(1, round_resets.hands + round_bonus.next_hands)` and discards
to `max(0, round_resets.discards + round_bonus.discards)`. It clears
`shop_free` and `shop_d6ed`. After the queued `ease_dollars` payment, it
assigns `previous_round.dollars`, retaining other fields in that table.
Original source member SHA-256 is
`c88a74ca3a8fa8ace0ce46ad10a97238f347c292842c9164d11136fe9952c101`.

The pinned Jackdaw cash-out handler left hands, discards, purchase count and
`shop_free` stale, populated the shop while still in `ROUND_EVAL`, and
replaced the entire `previous_round` dictionary. In the minimal fixture,
cash 7 plus prescribed earnings 1 correctly becomes 8, but the state passed
to shop population still has 0 discards where source rules require 3. The
[preserved baseline comparisons](BASELINE_COMPARISONS.json) report first
difference `events[1].discards_left`, expected 3, actual 0. All six baseline
fixtures expose at least one shop-boundary mismatch; the already-correct
resource control differs only on the phase seen by shop population.

The [in-memory overlay](../../advisor_learning/lifecycle_455.py) follows the
exact-pinned handler's cash-out path, inserts the source reset before shop
population, clears both shop flags, enters SHOP before stocking, and assigns
only `previous_round.dollars`. It pins upstream `game.py` SHA-256
`05ba662b03be86b7e879d9ef001844522497afe9653029e4da5251971bbb009c`.
The old handler remains available inside the test process for adverse
comparisons. No upstream or product runtime file was edited.

## Evidence and limits

The [independent handwritten reference](../../advisor_learning/lifecycle_reference_455.py)
and [actual `CashOut()` adapter](../../advisor_learning/test_lifecycle_455.py)
compare six fixtures: stale counters, already-correct counters, bonus
composition, lower bounds, zero payment with a retained previous-round field,
and negative payment. The [manufactured receipt](MANUFACTURED_COMPARISONS.json)
preserves each old/repaired comparison and a deliberately swapped-observation
negative control. All six repaired cases agree exactly on settled cash,
current-round fields, retained round-reset/bonus state, shop flags, phase,
previous-round fields and the state handed to shop population. An invalid-phase
test confirms the overlay does not reset counters before rejecting `CashOut()`.

The test replaces shop population with an empty recording sink. It prescribes
the already-evaluated earnings total and uses no Boss, tags or RNG. Thus this
is **manufactured-tested cash-out bookkeeping**, not an executed original
`cash_out` comparison, shop-stock qualification, RNG or event-frame parity.
The ordered records are comparison observations at settled payment and
shop-population input; they are not source callback-frame traces. The source
payment is queued, while the candidate applies it synchronously, so only the
settled amount is supported. The copied tag path remains unqualified.

Verification: `python -m unittest tools.advisor_learning.test_lifecycle_455
tools.advisor_learning.test_lifecycle_454 tools.advisor_learning.test_lifecycle_453
tools.advisor_learning.test_simulator_patches -v` passed **27 tests**.
`python -m tools.advisor_eval.development455.qualify_manufactured` completed
and verified the original archive/member hashes read-only. No original-source
worker, episode, whole game, training, Balatro process, save/profile read or
installation was used in slice 455.

## Qualification matrix and next gate

| Boundary | Current status | Limit |
|---|---|---|
| Plain Golden final-life bonus through cash-out evaluation (454) | Seven isolated original-source cases agreed | Settled cash and evaluation only; no payment action |
| Cash-out payment and shop-entry bookkeeping (455) | Six manufactured comparisons agreed | Prescribed earnings; empty shop sink; no source callback execution |
| Previous-round field preservation at shop-population input | Manufactured-tested | No general shop-generation claim |
| Shop stock, tag effects, Boss/reset-blinds path, shuffle/RNG | Unsupported here | Requires independent boundary/sequence qualification |
| Perkeo shop exit, next blind, full Red Deck/Gold Stake game | Unsupported | No win-rate, optimality or full-run evidence |

The conservative near-expiry learning-episode guard remains. The consumed
454 source lease was not reused. The live integration module advanced to
development455; exact 454 bytes are retained at
[development454/frozen/simulator_patches.py](../development454/frozen/simulator_patches.py)
with the 454 manifest hash, so its historical receipt remains reconstructable.
The next coherent gate is real shop stock/tag generation or a bounded isolated
original `cash_out` source comparison. A new source worker requires its own
concrete registration and fresh authority.
