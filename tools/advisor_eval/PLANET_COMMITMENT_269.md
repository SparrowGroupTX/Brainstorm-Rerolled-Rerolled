# 2.69 revealed Planet commitment — 2026-09-12

This component changes `Brainstorm/Advisor/strategy.lua` only. Installation,
combined validation and exact deployment hashes belong to the current checkpoint
and ledger. The evidence below is synthetic component evidence; it establishes
neither a rescued attempt nor a player win rate. Current and projected odds remain
unknown.

## Failure-driven hypothesis

The closed `focus268_development1` cohort demonstrated an early build deficiency
candidate: after one exceptional hand, a revealed Planet for that hand was chosen
and contributed nothing before the next blind's source-confirmed loss. The log
did not retain the rejected pack's complete comparison diagnostics. It therefore
did not establish that an alternate Planet dominated the original choice in every
composition world, or that changing that choice would rescue the attempt.

The mechanism behind the hypothesis was concrete: `favored_hand` uses prior plays
and levels, while `base_consumable_value` rates its matching Planet at 69 and
other Planets at 22. Revealed pack choices add a bounded tactical adjustment to
these priors. A single historical hand can thus override better supported
finishing evidence from the present deck. No spent attempt was replayed or
continued to test this hypothesis.

## Bounded repair

After all existing revealed pack comparisons complete, the strategy can exclude
a Planet whose supported fixed next-blind policy is strictly worse than another
revealed Planet on the same four common composition worlds. Every world must have:

- at least as much capped progress toward the known target;
- no additional hands or discards spent;
- at least as much remaining cash;
- no additional population loss;
- at least as much finishing reward.

Progress must improve by more than `0.000001` in at least one world. The comparison
requires the same target and identical baseline world measures, complete and
supported before/after policies, known mechanics, exactly four worlds, and finite
outcome measures. A candidate's fixed policy is used across all worlds; no best
branch is chosen separately for each hidden outcome.

All positive-rated, legal revealed Planets must have the required evidence before
any history override. A later incomplete or unsupported pack comparison, shared
scoring cutoff, missing world or uncertain mechanics preserves the prior decision.
The extra pass admits at most twelve pack candidates and adds **zero scoring
calls, draws or RNG calls**. It consumes existing paired evidence within the
unchanged 50,000 shop-scoring limit. Search and fast-clear allowances are unchanged.

The original scores remain visible. Diagnostics record excluded offer indices
and keys, the dominating revealed alternative, and the limited scope of the
comparison. The strategy then selects the highest existing score among remaining
choices. Neither challenge names, seed identities nor hand-name bans affect this
rule. An achievable rare hand can win the same comparison in the opposite
direction.

## Preserved tradeoffs and limits

Crossed-world results, worse action/cash/population/reward costs, or equal capped
progress do not establish dominance. In particular, when both choices already
clear every world, this rule leaves existing longer-term growth ratings in place.

Active Perkeo/copying engines and Observatory contexts retain the existing
whole-inventory valuation; their longer-term inventory tradeoffs cannot be proved
by the limited next-blind comparison. Direct pack-use transitions continue to
preserve all previously owned consumables, Negative slot contributions and exact
usage effects. Existing shop purchasing, paid-refresh, target-selection,
population and survival logic is unchanged.

The Arm also abstains because the finishing diagnostic omits permanent lost hand
levels. Every owned Joker must belong to an explicit vanilla static-scoring
allowlist; empty rows qualify naturally. Unrecorded future Joker/card growth,
copying, destruction/income-generation and unknown rows retain their existing
valuation, including currently debuffed growth cards that can return later.
This preserves Burnt/Yorick development, Hiker/Wee growth and other investments
that the six finishing measures cannot fully compare. The read-only final review
found no omitted vanilla permanent-growth path in the static allowlist.

This is a **revealed pack Planet** rule. It does not change blind sampling, hand
frequencies, unopened-pack estimates, shop cash spending, future offer acquisition,
or the global definition of a favored hand. Deck realizability is supplied by
the existing paired scoring/finishing outcomes rather than a new heuristic hand
probability. Four bounded composition worlds remain incomplete evidence about
future play and cannot prove global dominance or lifetime completion time.

## Frozen focused validation

`runs/planet_commitment269_focus2` contains copied Lua modules/fixtures, a
registration with file hashes, output log and report. A single hidden synthetic
fixture worker had a 30-second cap and completed in **1.0525301999878138 seconds**.
All seven fixtures passed:

| Fixture | Checks |
| --- | --- |
| `advisor_planet_commitment.lua` | 62 |
| `advisor_pack_scoring.lua` | 33 |
| `advisor_nonjoker_pack_scoring.lua` | 16 |
| `advisor_shop_survival.lua` | 15 |
| `advisor_shop_copy.lua` | 43 |
| `advisor_planet_reroll.lua` | 42 |
| `advisor_blind_finishing.lua` | 41 |

The new fixture includes controlled evidence counterexamples for every admission
and resource requirement, late incomplete coverage, exact owned Negative
inventory preservation, Perkeo/copy/Observatory abstention, deterministic output
and global RNG prohibition. Two real-scoring synthetic compositions each use
2,640 evaluations: a deck with two copies of each represented rank cannot realize
its previously played Four of a Kind, while a duplicate-rich opposite control
still selects Four of a Kind development. In the first case the unmodified raw
history rating remains greater even though complete paired progress is lower,
demonstrating the actual selection defect repaired by this pass. A tiny real
shared scoring budget confirms whole-decision fallback.

The preliminary `planet_commitment269_focus1` result is preserved: seven fixtures
passed in 1.078388400026597 seconds, with 39 new checks. Read-only review then
identified the omitted Arm/permanent-growth tradeoff; the refined admission and
23 additional controls justified the fresh second focused run. The first result
does not validate the final bytes. No failed test output was deleted or hidden.

No original-source worker, full episode, acquisition/filter experiment, save,
game process action, installation or version edit was performed by this component
work. No complete-attempt budget was renewed. Source and fixture SHA-256 at this
focused checkpoint:

- `Brainstorm/Advisor/strategy.lua`:
  `608256697fa32113b03f4bc8808d249b06810ba7f37c874467539d83f18c5d80`
- `tests/advisor_planet_commitment.lua`:
  `d5ae903bff7c292c010bea75f276612c8fad7f6553d4874b2fff1b9ee1aa9d16`
