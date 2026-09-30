# Complete blind-policy resource comparison — 285

This slice fixes a demonstrated integration omission in the shop's bounded
whole-blind forecast. It does not add policies, worlds, scoring calls, source
experiments, or evidence of a Jokerless win.

## Failure mechanism and repair

`blind_finishing.lua` already executed two fixed policies in four shared worlds:
play only, or one targeted observed discard. It recorded actual hands/actions,
cash, population cost and finishing rewards. At equal clearing counts and capped
progress it nevertheless selected fewer discards before considering population,
ignoring actual action count, unused-hand cash and Blue rewards.

The existing primary clearing/progress ordering is preserved. At an exact primary
tie, a new secondary comparison can select the alternative only when **all four
worlds clear under both policies** and every world has:

- At least as much supported cash after held-card/interest/unused-resource awards.
- No more actual play/discard actions, no larger population cost, and every
  physical survivor retained by the incumbent.
- At least as many Blue Planets; an incumbent Blue reward must retain its hand
  identity, and its existing whole-inventory utility cannot decrease.
- Identical developed hand levels/Chips/Mult and leading played-hand family,
  retaining every already-played hand category.

At least one compared quantity must improve. A mean cash/Blue gain cannot buy a
worse world, and no arbitrary dollar-to-action exchange rate is introduced.
Crossing advantages keep the previous policy. Full-family support and the
existing shared score budget are unchanged; incomplete families publish no winner.

The new comparison is deliberately limited to no owned Jokers, no Observatory,
nonfinal blinds, known held/Blue rewards, no active Arm, no permanent played-card
debuff modifier, and no cash-dependent hand-size modifier. Other situations keep
the prior complete-policy ordering. This is not a general proof of dominance over
future runs: future offers, hand-history frequencies beyond these guards, later
bosses and opportunity costs remain outside this horizon.

## Cash timing and inventory

The final detached state's cash already includes all scored dollars. The new
cash component adds held Gold income, then applies interest to that subtotal,
then adds unused-hand/discard awards. It does not add final-play dollars twice,
or allow unused-hand cash to earn same-round interest. The common blind award is
omitted from both sides. The result is a supported comparison of these components,
not a complete cashout or future-shop simulation.

Blue quantity and hand identity come from the existing `finish_rewards` module,
including physical capacity and held-card triggers. Its Planet utility remains
heuristic and explicitly labeled; this slice does not tune that utility, convert
it to a win probability, or trade a lower Blue quantity for more cash. Existing
whole-inventory, Perkeo/Negative/Observatory, Glass and population mechanisms remain.

## Routine synthetic evidence

The new fixture uses real detached scoring, transitions, draws, population and
reward code throughout. Its initial hand has four Hearts plus an off-suit Queen.
The fixed play-only route scores 15, 15, 16 and 15 (61 total) in four plays against
a 60-chip target. One targeted discard completes a 260-chip Flush, clearing in
one play. Both policies clear all four supplied worlds without losing deck cards.

The former ordering keeps four plays because it uses no discards. The repaired
ordering selects one discard plus one play: two fewer actions and $3 more
unused-hand cash in every world. At initial cash $4 it records $7, not fictitious
$8 from including hand cash in interest. Work remains 104 score/transition charges.

Other assertions cover a paid-discard loss of cash, equal-cash action gains,
cross-world cash tradeoffs, an actual held Blue generation that must not be traded
for extra cash/actions, no-extra-hand-money rules, missing reward support,
conservative scope exclusions, determinism, unchanged inputs, and whole-family
budget fallback. These are synthetic fixtures, not sampled run outcomes or a
representative cohort. No preserved continuation was replayed or rescued.

Draft fixture receipts and source drafts are retained under
`runs/blind_value285_development/`; final runtime validation/release is recorded
separately by the release coordinator. No new source, seed-search, replay or
complete-attempt worker is authorized or consumed by this document.

## Separate remaining integration

`shop_scoring.lua` still uses capped whole-blind progress for paid-build valuation;
`work_cost.lua` still estimates opening-decision effort rather than completed-policy
action counts. This slice improves which fixed policy supplies readiness and its
resource certificate. It does not claim those higher-level valuations now fully
credit unused-hand cash, Blue generation or actual later user actions.

`shop_sequences.lua` also retains opening-score rescue/override gates even when
complete whole-blind evidence exists. A separate coherent change should let
complete supported progress govern that narrow override while preserving cash,
inventory and existing comparison completeness. Unknown paid-pack outcomes cannot
be fixed simply by dropping the incumbent-action support guard.
