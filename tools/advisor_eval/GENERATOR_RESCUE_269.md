# Owned Judgement and bounded plain-card order equivalence — 2026-09-12

This note describes the installed269component; SESSION_RESET_269 and its exact
validation/installation ledger own final status. It extends `GENERATOR_RESCUE_268.md`; it is not a source rescue, challenge
win, measured player rate, speedup or evidence of running-game activation.

## Behavior and source boundary

`consumables.lua` now recognizes owned Judgement through the same last-hand,
zero-discard generator fallback as Emperor and High Priestess. It requires an
actual free observed Joker slot, the known Tarot identity/type, empty source
generation configuration and valid inventory capacity. Static original-source
ZIP inspection confirms that owned Judgement requires `#G.jokers.cards` below
the Joker limit and creates one Joker without selected hand targets. It consumes
the actual owned card, including its Negative slot, without inventing extra
Joker capacity. Product Execute remains user-clicked and invokes source legality.

There is no generated identity, projected score, rescue probability or pure
transition. The only action is the owned use; actual public revelation requires
fresh advice. Existing complete deterministic rescue keeps priority. Prior
truncated comparisons decline this fallback. Mr. Bones, active Perkeo, unknown
mechanics, copy routing and whole-inventory preservation safeguards remain.

## Complete comparison within the existing cap

For more than eight held cards, `scoring.upper_bound_order_independent` can prove
a narrow plain-card additive domain. It admits only visible, unenhanced,
unsealed, uneditioned cards with ordinary rank chips and no score modifiers,
plus bounded independent additive Joker effects or explicitly admitted passive
effects. Copies, individual multipliers/retriggers, card editions, Observatory,
balancing and unsupported effects decline. The existing supported random maximum
still applies, including Misprint's possible maximum rather than its mean.

The proof requires at most 20 held cards and 20 Jokers, complete deck/population
lists no larger than 120 each, and at most 120 held consumables. Relevant score
inputs must be actual nonnegative integers no larger than 2^20; finite integral
cash may be negative with magnitude at most 2^20. Numeric strings, fractional or
oversized inputs decline. Main added terms are bounded by 2^40 and aggregate
chips/Mult remain below 2^46, so their additions are exact in binary64. Plain
card category/scoring membership depends on the subset, and equal-rank cards
have equal nominal chips. Thus every ordering of each admitted subset shares
its maximum; the same final product is computed in each equivalent order.

Every nonempty subset of at most five cards still receives a supported
`upper_bound` call. Unsupported or incomplete results abstain. Diagnostics
separately report actual representative evaluations and covered ordered plays.
For ten cards, 637 complete subset comparisons cover 36,100 ordered plays.
The whole pass must fit in the unchanged 25,000 consumable allowance, including
prior work. No partial pass certifies impossibility. Hands of eight or fewer
retain the existing full ordered enumeration. Ordinary search and the 70-score
fast-clear budget remain unchanged; fast clears bypass generator admission.

## Development evidence and bounded validation

The completed `focus268_development1` cohort had four source losses, no timeouts
and no action divergences. Both allowances are spent and must not be rerun. Its
Knife's Edge pair reached the same Ante 4 The Arm loss with ten plain held cards,
one hand, zero discards, 6,800/10,000 chips, Dagger +30, Juggler, two of five Joker
slots occupied and unused Judgement. The best final local play scored 1,386;
both source runs finished at 8,186. This motivates a generic action opportunity,
not a claim that a random Joker would rescue that run. No challenge/seed dispatch
or outcome imputation was added.

`tests/advisor_judgement_rescue.lua`: **445 checks pass**. It covers the generic
ten-card 637-comparison case; all 325 ordered selections of a five-card fixture
with duplicate ranks, unequal debuffs and random maximum; raw/cache parity and
exact score-call counts; insufficient budget; small-hand behavior; normal and
Negative capacity; known-generator reuse; random-clear counterexamples;
malformed/string/fractional/oversized inputs; oversized inventory; unknown
mechanics; whole-inventory safeguards; normal decision integration; and fast
clear preservation. `tests/advisor_generator_rescue.lua`: **94 checks pass**.
Earlier focused consumables, inventory development, fast-clear and decision
integration fixtures also passed before the final admission-only tightening.

Only ordinary isolated Lua unit fixtures and read-only source inspection were
used for this component. No new source worker or complete attempt was executed.
Any further source validation needs a fresh prospective bounded registration;
the spent development allowances are not renewed. No game launch/control, save
access, native change, settings restoration or installation was performed here.
