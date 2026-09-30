# Lifecycle slice 453 — manufactured round-end qualification

**454 correction:** original `ease_dollars` queues rental payment. The
per-Joker cash values in 453's manufactured trace are projected settled
values, not source frame/callback timing evidence. Final settled cash and the
Juggler capacity mismatch remain source-derived. See
[slice 454 acceptance](../development454/ACCEPTANCE.md).

2026-09-29. Branch `codex/exact-search-speedups`; installed451/2.226.0-alpha
was left untouched. This is a tooling/learning-simulator overlay, not a product
release or loaded-game observation. The accepted direction remains simulator
fidelity for Red Deck/Gold Stake Perkeo/Yorick win-first play; this narrow row
does not claim to represent that full conditional opening or run population.
Read-only hashing found all 110 candidate and installed policy files matched
their installed451 receipt; its recorded digest remains
`b302060aff407e963955a02be6ee55f9f764aa897917be95916ac98c23555b59`.

## Result

Source inspection found that `Card:calculate_perishable` expires a Joker through
`Card:set_debuff`; an active Joker's passive deck contribution is removed once.
The pinned Jackdaw maintenance function set `debuff=True` directly. In the
minimal rental Perishable Juggler case (cash 10, hand capacity 9, tally 1), the
source-derived expectation is cash 7, tally 0, debuffed and capacity 8. The
old pinned function yielded capacity 9. [The full preserved failing
comparison](MISMATCH_BEFORE.json) reports first difference
`events[0].after.hand_size`, expected 8, actual 9.

The new [in-memory overlay](../../advisor_learning/lifecycle_453.py) lets each
Joker's maintenance settle in row order and removes the ordinary Juggler's +1
capacity on its active-to-expired transition. It is integrated through
[simulator_patches.py](../../advisor_learning/simulator_patches.py), with pinned
`round_lifecycle.py` SHA-256
`8297786eb523127fe95304f1de8829aa7d93fb56e2819b93aab8cb04862e85dd`
checked before patching. The upstream file was not edited.

The [source-derived reference](../../advisor_learning/lifecycle_reference_453.py)
and [pure comparator](../../advisor_learning/lifecycle_contract.py) use separate
code from the candidate. The comparator checks ordered per-Joker settled events
before final state, reports the first field difference, and leaves both inputs
unchanged. It caught a deliberately swapped event order at
`events[0].after.cash`. These settled events do not observe within-Joker
callback/rental/expiry timing.

[Five manufactured comparisons](MANUFACTURED_COMPARISONS.json) agree exactly:
last-tally rental expiry, tally-two nonexpiry, already-expired no-double-removal,
nonrental expiry, and a held-out two-Juggler/rental-Joker row. The held-out row
ends after each Joker at `(cash, capacity)` `(14,9)`, `(11,9)`, `(8,8)`.
The game round-end helper reached the overlay in a separate manufactured test;
the native top-level rental representation deducted once before a simple
interest calculation. This is not a general cash-out qualification.

Targeted tests: `python -m unittest tools.advisor_learning.test_lifecycle_453
tools.advisor_learning.test_simulator_patches -q` — **18 passed**. The receipt
includes fixture and source hashes, the failed old comparison, every repaired
comparison, the wrong-order negative control, and the separate held Gold/Mime
unsupported fixture. No episode, original-source callback harness, source
worker, whole game, captured-policy evaluation, training, Balatro control, or
save/profile read was run.

## Qualification matrix

| Mechanics | Status after 453 | Limit |
|---|---|---|
| Plain Perishable Juggler expiry with/without rental | Manufactured-tested | One round-end maintenance boundary; source-derived handwritten expectation |
| Tally 2, already expired, and held-out row order | Manufactured-tested | No round-end callback effects in selected row |
| Native top-level rental then simple interest | Manufactured integration smoke | General cash-out and dual-field rental remain unqualified |
| Held Gold with Mime | Unsupported; guard tested | Separate fixture retained; no candidate/source parity executed |
| Negative expiry, later sale/re-add, queued blind refresh | Unsupported | Original source has distinct slot/event and one-time removal semantics |
| General callback interleaving and final-life Golden Joker dollar bonus | Known ordering mismatch | Candidate still batches callbacks/bonuses before maintenance |
| Cash-out, shop, Perkeo shop exit, next blind, RNG, uninterrupted run | Unsupported by this slice | No sequence or distributional claim |

The learning environment's conservative `fidelity_perishable_expiry_order`
audit guard remains active. It still censors such episodes before this
transition, so this repair does **not** make training episodes or win-rate
estimates complete. Sale after expiry could otherwise remove Juggler capacity
again; removing that guard requires a separately qualified transition. No
model, game runtime, setting or DLL was changed or installed.

## Provenance and next gate

Retained original `card.lua` SHA-256:
`5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`.
The retained state-events excerpt and all candidate/reference/comparator/test
hashes are in the JSON receipt. The source-derived expectation is **not** an
independently executed original-source comparison. A future bounded harness
must reproduce the same callbacks and queued blind refresh before upgrading
this row to independent-transition-qualified, then address callback/dollar
ordering and cash-out/shop sequencing separately. No numerical experiment
authority was inferred from the accepted direction or old budgets.
