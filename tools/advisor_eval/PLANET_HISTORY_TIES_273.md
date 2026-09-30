# Paid Planet development when hand histories tie — 2026-09-13

Component: `Brainstorm/Advisor/strategy.lua`; candidate for the next coherent
runtime slice. Root owns release selection, full regression, installation and
checkpoint records. This note does not claim deployment or a completed win.

The observed 2.70 development trace at shop step 50 exposed an admission gap:
Pair, Straight and Flush each had three plays and level two, so fixed hand order
gave Pair the main-hand priority. A visible $3 Jupiter received the other-hand
priority while an unknown $4 Arcana pack won the shop choice with $5 available.
The preserved detached diagnostic's independently valid prefix showed complete
Jupiter-use mean progress increasing from 0.63703125 to 0.72640625 in the same
four worlds, with one clearing world before and after. Its full receipt remains
an **error** because stdout interleaved inside a fingerprint; no rescue or
complete-result parity is imputed. See `VISIBLE_DEVELOPMENT_271.md` for that
unchanged provenance and the separately spent component lease.

The candidate now permits a visible Planet to receive the existing main-hand
priority when its hand has exactly the same positive played count and level as
the history-selected hand. The only credit is the existing 69 minus 22 priority
gap. This does not change unopened pack ratings, make an assertion about their
contents, or calibrate a new coefficient.

Admission requires no owned Jokers and no Observatory. Every admitted tied
offer must have an existing complete supported exact purchase/use comparison
with four matching baseline worlds and targets. Any unknown, incomplete,
truncated or mismatched family preserves the prior. The Arm is excluded because
its permanent hand-level costs exceed this certificate. No comparison or scoring
call is added: the selector reuses the evidence the shop already computes.

For an individual credit, the fixed after-policy must strictly improve capped
progress in at least one world and worsen none. It may not spend more hands or
discards, lose more population or finishing rewards, or lose more cash than the
observed purchase price. The actual paid endpoint must preserve existing
consumable count and capacity, and fully fund the existing conservative cash
reserve, including paid discards and any valid debt allowance. Existing purchase
penalties and the ordinary purchase threshold remain applied. No alternate
policy is selected separately for each hidden world. The result is bounded
development evidence, not a win probability or proof of lifetime superiority.

Diagnostics expose the tied hands and history, 47-point credit, actual price,
remaining cash, reserve, family size and before/after capped mean progress.
The mechanism has no seed or challenge-name condition. The existing exact
Planet transition retains owned Negative inventory and its capacity. Owned
Jokers, Perkeo, Observatory and other protected whole-inventory paths retain
their previous decisions.

## Validation

`runs/planet_ties273_focus5`: nine fixtures passed in 0.9839999999967404 seconds
under one 30-second hidden synthetic Lua-fixture cap. The recorded strategy and
fixture hashes remained unchanged. New `advisor_shop_planet_ties.lua` has 47
checks, covering the demonstrated tied-history shape, price and reserve,
crossed-world regressions, incomplete later offers, baseline mismatch, strict
gain, target mismatch, The Arm, inventory capacity, owned Negative inventory,
Observatory/Joker exclusion, another hand family and challenge independence.

Two real scorer controls each use 1,760 existing scoring calls: a visible tied
Flush upgrade with actual improvement receives the credit, while a stronger
unchanged Straight Flush does not. The 50,000 shop cap is unchanged. Companion
fixtures also pass: shop Planet commitment 32 checks; revealed Planet commitment
62; complete enhancement targets 33; shop survival 15; shop copying 43;
liquidity 34; shop sequences 55; retry policy 90.

The final fixture also exercises the actual `Decision.run` entry point with
Economy, shop sequences, paid reroll/shortfall handling, conditional value and
liquidity wired. The positive case still recommends buying the visible Planet
after a complete continuation comparison, using 2,640 scoring calls; the
negative unchanged Straight Flush keeps the previous pack recommendation, using
1,760 calls. Repetition is deterministic and does not mutate the input. A
one-evaluation cap forces the whole-decision fallback to the old pack choice
without retaining any incomplete tie credit. No additional runtime change was
needed for integration. Focus4 preserves the earlier 41-check passing fixture.

Earlier focused outputs remain in `planet_ties273_focus1`, `focus2` and `focus3`.
Their failure was the positive fixture's accidental all-Hearts 2–9 population:
a Straight Flush already outscored the upgraded Flush, so the runtime correctly
refused a credit. That case is now an explicit negative control; the positive
control uses a nonconsecutive rank population. Runtime behavior was not relaxed
to satisfy the fixture.

Final component hashes:

- `Brainstorm/Advisor/strategy.lua`:
  `94aa8c4ae9012d62e8e8cd597b0c5ec8124c7cbd2b919d01ad825e42cf245fb1`
- `tests/advisor_shop_planet_ties.lua`:
  `f41e3142075b7bb4012305be9e6d66671aab70a5eb95ba6568bb051d01f323aa`

No source attempt, live gameplay, save access, game launch, native change,
training, full-attempt outcome or numerical win-rate claim occurred in this
component work. No source-worker lease was allocated to or consumed by this
component agent after the restart.
