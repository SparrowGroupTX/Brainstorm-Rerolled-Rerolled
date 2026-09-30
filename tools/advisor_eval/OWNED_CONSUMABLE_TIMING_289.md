# 289 — ordinary owned-consumable timing inside resource policies

The current tactical consumable comparison can prefer an immediate local scoring
upgrade without comparing its timing with the remaining plays and discards.
The resource specialist previously declined whenever that tactical recommendation
existed. This slice admits a small complete family containing the exact current
ordinary use and the supported first play/discard alternatives. It publishes only
the first action, then requires fresh advice after execution.

## Source observation and scope of evidence

In the fresh authorized current286 C2 development attempt, step48 uses Moon on
cards1,3,4 and step49 uses **Justice** on card1 against Ante2 Flint1600. The local
forecasts are219 and438. Both decisions exclude the resource specialist because
the existing tactical action takes priority. The later three discards and four
plays end in a loss. This is evidence of a missing comparison; it does not prove
that either use was wrong or that289 rescues the attempt.

The preserved source is
`runs/diagnostic287_20260913_222344/C2/attempt.log` and its frozen286 receipts.
These selected dependent synthetic-profile traces are development data. The
runtime change below has routine synthetic fixture evidence, not a terminal
counterfactual, player cohort, win-rate estimate or verified Jokerless win.

## Complete declared comparison

The existing no-Joker specialist adds the targeted-consumable scope only for two
through four hands, at most eight visible/future held cards, and one or two known
ordinary targeted owned cards. Known suit Tarots, enhancement Tarots, Strength
and Hanged Man are supported. Generators, compound incumbent consumable
sequences, hand reordering, unknown identities/editions, concealed inventory,
Perkeo, Observatory and invalid inventory/capacity metadata retain the existing
action or specialist route. Ordinary Negative consumption carries its exact
capacity reduction. The existing small owned-Planet specialist remains intact.

At most four first actions are declared: incumbent play, incumbent discard, the
legal play of those discarded indices, and one ordinary owned use. When a
tactical use exists, its index and targets are copied exactly and its key is the
baseline. An existing reliable immediate play or consumable clear keeps priority.
Without a tactical use, one current public target proposal may supply the use
first action.

Each first action crosses all five288 discard schedules and two use rules:

- Hold the remaining owned inventory.
- At later observations, compare one existing public development-target proposal
  per remaining owned card and use the best admitted proposal. A use-first branch
  can consider the second card before its first play/discard. A play/discard-first
  branch acts first, then sees its actual replacement observation.

The target rule receives the current visible hand and canonical public deck,
population and discard lists. It never receives the internal sampled future deck
order. Target sets are fixed before further replacement draws. Every admitted
proposal receives the complete existing structural play comparison. Its public
rule admits a current score gain greater than max(10chips,15%) or a positive
existing development gain, then ranks current score followed by development.
This is a fixed heuristic target rule, not a complete target search or evidence
that using the card is free. The hold family represents the option to retain it.

The maximum40 plans use the same four deterministic composition worlds. All
12,000-score and150,000-classification limits, safe yields, exact observation memo,
140,000 ordinary-search /50,000 shop /25,000 consumable limits and the274
resource override guard remain; these are existing module allowances, not a
single whole-decision cap. Any
unsupported admitted transition, incomplete proposal or cap stops the entire
comparison. There is no partial winner. Replacing a current tactical use or
introducing a new use first action additionally requires nondecreasing win/progress
in each of its four baseline worlds, followed
by the existing clearing-uplift and extra-action/cash allowance.

Each use removes exactly one physical owned identity and shares a persistent
within-policy count bounded by the original inventory of at most two. Exact
transitions carry target identities, cash, capacity, usage and population. Hanged
Man removes cards without drawing; the next play/discard is the next opportunity
to refill. Future Lucky/Glass outcomes are resolved only by the selected actual
sampled play. Blue rewards use the actual final hand and remaining inventory
capacity. `inventory_before_finish_rewards` names the retained inventory before
the separately recorded finishing reward; it does not claim Blue Planets were
created in the input snapshot.

Use actions count in policy tie-breaks and the extra-action allowance. Existing
`population_loss` remains scored-play exposure. Exact intentional removal is
reported separately as `intentional_population_removed`, with total population
change and per-use counts also preserved. No arbitrary removal-to-win coefficient
or future unseen voucher value is introduced.

## Source and test navigation

- `Brainstorm/Advisor/consumables.lua`: embedded `resource_policy` admission,
  public target proposals and exact owned-use projection. It uses the existing
  module and therefore needs no source-adapter loader change.
- `Brainstorm/Advisor/resource_finish.lua`: fixed use first action, paired hold/use
  policies, exact tactical baseline, use receipts/costs and full-family guards.
- `Brainstorm/Advisor/decision.lua`: helper-aware admission and a narrow
  `replaces_consumable` override flag; unrelated priorities are unchanged.
- `Brainstorm/Advisor/runtime.lua`: exact owned index/targets and the selected
  resource action are displayed; Product Execute remains user-clicked.
- `tests/advisor_resource_consumables.lua`: real eight-card two-consumable full
  family, exact targets, shifted identity, Negative capacity, Hanged no-refill,
  input/deck-order invariance, cap/unsupported/compound guards, and controlled
  crossed/noncrossed baseline examples.
- Existing `tests/advisor_resource_finish.lua`, `advisor_consumables.lua`,
  `advisor_deck_development.lua`, `advisor_decision_integration.lua` and
  `advisor_runtime.lua` supply the neighboring regression coverage.

Focused receipts are under `development289/`. The real eight-card two-consumable
case completes40 plans with1,285 scores and59,539 classifications. Controlled
synthetic models separately show a crossed3/4-versus1/4 result being rejected and
a noncrossed4/4-versus1/4 result producing the supported first action. Those
numbers describe fixture worlds only. Final exact-byte full candidate/installed
validation and deployment hashes are recorded by the parent release ledger.

The final focused receipt is `development289/integration_focused9/report.json`:
six fixtures pass in6.1743516seconds under the60-second cap, including909 new
checks. Earlier `integration_focused5` through `integration_focused8` are retained
as failed fixture evidence. Their injected no-hint counterexample incorrectly
assumed the public rule selected Moon; the actual rule selected Justice. The
fixture now recognizes any actual use before the first resource action, without
changing the public target rule or weakening the crossed-world guard. No source
run failed or was retried as part of these routine fixture checks.

## Deferred observed target gap

C1 step55 picks Strength on its two9s, converting them to10s. Opening mean rises
291.5→599.75 while the selected whole-blind progress falls.973875→.84375. This is
not an opening-bonus bug: `shop_scoring` already applies−21.449156 from complete
progress, and the remaining strategic prior48 beats Fool35−14=21. The selected
Fool policy spends one more discard in each world, while the same-policy
play-only comparison crosses by3chips in the failing world. A simple veto would
overstate the evidence. Complete Strength target comparison remains deferred;
this slice does not reweight pack scores or claim Fool was optimal.
