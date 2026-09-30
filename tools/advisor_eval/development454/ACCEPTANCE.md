# Round-end to cash-out slice 454: prospective acceptance

Selected before implementing the candidate repair. This slice covers only
ordinary-edition Golden Jokers plus ordinary `j_joker` rental controls, with no
round-end callback mutation, copy, held-card effect, or blind side effect. It
uses the pinned Jackdaw game helper and economy function; the independent
expectation is a small handwritten source-derived model. Original source is
read, not executed, until a separate bounded proposal is authorized.

## Source-derived semantics and event boundary

The retained state-events excerpt calls each Joker's end callback, rental and
Perishable maintenance in row order. `Card:calculate_perishable` synchronously
sets the final-life debuff. `Card:calculate_dollar_bonus` later returns no value
for a debuffed Golden Joker, so its final-life bonus is zero. Source
`ease_dollars` queues rental payment unless called `instant`; this slice does
not assert that cash changes before the next Joker callback. Compare ordered
Joker maintenance identities/tallies/debuffs, **settled** rental cash, later
bonus total, simple interest and paid cash-out. The event queue and blind reset
remain unqualified.

## Frozen fixture family

- Minimal: active plain Golden Joker at Perishable tally 1, no rental,
  zero initial cash/blind/hands income. Expected bonus 0; old candidate 4.
- Rental composition: same Golden with native top-level rental, starting cash
  10. At the settled boundary cash 7; bonus 0; one ordinary interest dollar;
  cash after payout 8.
- Negative controls: tally 2, already expired/debuffed, and active
  nonperishable Golden.
- Held-out composition/order: expiring Golden, nonexpiring rental ordinary
  Joker, active Golden; repeat with the physical row reversed. Preserve IDs,
  ordered maintenance observations, bonus 4 and settled resources.
- A separate held Gold/Mime fixture stays unsupported. Negative editions,
  copy/callback mutations, destruction, dual rental fields, queued blind
  refresh, sale and full shop behavior remain excluded.

## Acceptance

1. The previous unpatched cash-out value fails at the first bonus/paid-cash
   difference. Preserve the full failing comparison and the exact manifests.
2. A narrow in-memory overlay repairs the Golden final-life bonus without
   changing pinned upstream or product runtime. Main, controls and held-out
   cases agree exactly with the independent model; deliberately wrong event
   order is detected without mutating comparison inputs.
3. Existing near-expiry learning-episode censorship remains. No training,
   episode, original-source execution, Balatro control or save/profile read.
4. The source-execution harness and its bounded proposal, if prepared, are
   separate from manufactured acceptance and are not run under old budgets.

Retained original `card.lua` SHA-256:
`5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`.
Retained `common_events.lua` SHA-256:
`522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc`.

## Post-acceptance result

The prospective manufactured acceptance above was frozen before the repair.
The user's subsequent “Go for it!” authorized the separately registered
[one-use source probe](SOURCE_EXECUTION_PROPOSAL.md). Its
[receipt](source_attempt_001/report.json) shows agreement for all seven cases
on settled cash, final ordered Joker state, bonus, interest and evaluation
total. The source probe did **not** execute the cash-out payment action; the
paid-cash values above remain manufactured arithmetic only. See [the report](REPORT.md)
for the exact qualification boundary and remaining gaps.
