# Fixed-row family preflight component

This staged change adds `context:preflight_family(states)` to the frozen346
`shop_scoring.lua`. No production runtime file was changed by this component.
The method is limited to `current_order_opening_only` contexts and a dense
array of one through128 declared states. It prepares each supplied state
afresh, deduplicates the existing exact prepared `plan.key`, and sums costs
only for uncached profiles. A cached failed profile is explicitly unsupported.
Successful cached profiles need zero additional calls; existing spent work
still reduces the available allowance.

The returned table always includes `complete`, `supported`, `fits`,
`required_evaluations`, `available_evaluations`, `unique_profiles`,
`cached_profiles`, `uncached_profiles` and `reason`. Cost/count fields on an
incomplete result are partial diagnostics, never permission to score a prefix.
Budget insufficiency produces complete supported arithmetic with `fits=false`,
without setting `context.truncated`, changing existing profile entries or
calling the scorer. This lets the caller choose its existing fixed family
before scoring any expanded candidate. The actual root state is not implicit:
the caller must include it along with every endpoint it will compare.

The preflight is a work bound, not evidence that future scores are supported or
safe. Runtime comparisons must still complete, preserve common-world/floor
semantics and charge every actual call. Unexpected scoring failure or
truncation cannot authorize a partial-family choice. Existing `compare` and
`readiness` implementations are unchanged. No pointer-based preparation cache
was added.

`validation_02.json` records the final **96-check manufactured fixture pass**,
with unchanged inputs,0.1559999999590218seconds under its60-second suite cap.
`validation_01.json` separately preserves the initial90-check pass before the
128-state boundary tests. The fixture uses a synthetic constant scorer for
accounting; it is not a captured state replay, original-source component,
search, terminal attempt or timing calibration.

Final staged hashes:

- `Brainstorm/Advisor/shop_scoring.lua`:
  `965061d359adcda7054f83e26aea3ae65a946f0fed872ae72f038626d21bc61f`.
- `tests/advisor_shop_family_preflight.lua`:
  `4f7d4f63b0731e67a12f647f8c3ca1ebc42bd4034620865df94f0aa60546911d`.

## Static findings that motivated this change

The current346 acquisition loop does **not** rescore the hold endpoint for
every paid plan. One Shop context caches completed profiles by prepared key;
`compare(s,s)` evaluates the root once, and later paired comparisons reuse it.
However, `compare` checks the budget only for its next pair, not for the whole
acquisition family. It can spend substantial work and then fail on a late
endpoint, forcing complete-family fallback. Expanding the order family makes
that avoidable wasted work more likely.

For one fixed row with an unchanged nonempty public deck, one scenario and
five-card maximum plays, exact subset work is four times the sum of binomial
coefficients for subset sizes1 through5. This gives872 calls at eight cards,
1,524 at nine and2,548 at ten. Twenty-two distinct current-row profiles require
19,184 /33,528 /56,056 calls respectively, before any order multiplication.
Eight layouts multiply these by eight. Two eight-layout eight-card profiles
already require13,952 calls, exceeding the existing8,000 retention reserve.
This is arithmetic from the declared loops, not a measured runtime forecast.

Additional findings remain outside this staged change:

- Root `prepare` still clones/normalizes/encodes the same original state on
  every comparison, even when its score profile is cached. A future immutable
  preparation cache could avoid non-score work, but it must not reuse stale
  mutable states. Current preparation also normalizes fresh-round counters,
  row-derived values and blind restrictions, so a raw pointer alone is unsafe.
- Acquisition and retention use separate Shop contexts. Their unchanged hold
  can therefore be scored twice in one decision. The decision-wide
  `score_cache` already shares classification work, but does not memoize full
  score results. Sharing full profiles requires the same original-root common
  worlds, lower-bound semantics, ordering contract and one cumulative budget.
  Ordinary `score` results cannot stand in for `lower_bound` results.
- Each profile reconstructs an equivalent row table per world/layout, so its
  pointer-keyed flag and copy-row caches may rebuild identical data. Reusing a
  row per scenario/layout is a possible later optimization only after an
  immutability audit. No full-score memo or row-sharing change is included.
- `work_cost.lua` estimates a bounded strategic preference using explicitly
  uncalibrated score-time/action assumptions. It does not supply the exact
  cost of the declared acquisition/order family and must not replace this
  preflight or justify a cap increase.
- Exact inventory certification repeats across endpoints but depends on the
  complete original inventory, physical IDs, cash/capacity, row activity and
  copy routing. Any future split validation cache must preserve those distinct
  dependencies and each endpoint's complete receipt.

## Physical action mapping constraints

A projected reorder must name the original owned physical cards before any
sale or purchase. A purchase appends the incoming Joker; a sale shifts owned
indices; a purchase removes its offer from the shop row. An endpoint order
containing a not-yet-owned Joker cannot be directly executed as a current-row
reorder. Prefix reorder projections must remap subsequent sale indices by
physical ID, then replay the paid transition in the changed row. Pinned slots,
Eternal restrictions, Negative slot changes and retained-card effects remain
part of that legality check.

Retention's exit must keep the compared arrangement. Existing decision-level
suppression of `phase_copy` on a certified retained exit prevents later
Perkeo-oriented postprocessing from silently invalidating that comparison.
An expanded order contract must retain an equivalent explicit protection.

The passive346 ordering timeline is read-only motivation: the observed shop
row copied Perkeo, while the next hand reordered to copy Caino before other
intervening actions. It does not establish an alternate purchase floor or a
terminal rescue. No new gameplay evidence was produced here.
