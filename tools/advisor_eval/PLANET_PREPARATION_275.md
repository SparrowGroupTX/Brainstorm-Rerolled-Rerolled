# Exact main-hand Planet preparation — 2026-09-13

## Latest extension: played secondary hands before a blind — 2.81 candidate

The latest scope supersedes the main-hand-only blind gate below. Shop-phase
preparation remains main-hand-only. In blind selection, the scan first considers
the main-hand Planet regardless of inventory position, then considers ordinary
Planets for other hands with positive, finite actual played history and valid
public levels. No unplayed hand receives a speculative preparation action.
Every original exact transition, resource, population, inventory, Fool identity,
Joker, Observatory, and Negative-card safeguard remains in force. The new path
uses no score evaluations or RNG and makes no readiness or clear claim.

The demonstrated omission is source attempt `11_dependent280_p83r`: its Blue seal
generated Mercury after the Psychic, but the card remained held through the
Ante 2 Flint loss while Pair stayed level 1. Exported blind-selection step 27
has one prior Pair play, Pair 10 Chips / 2 Mult, Mercury plus Chariot, no Jokers,
Observatory or Fool, and Telescope as the only voucher. The old action selects
Small Blind. This is a fresh correction after the complete-attempt allowance
was exhausted; it does not imply that the lost episode is rescued.

`runs/planet_preparation281_secondary1` passes four isolated fixtures in
0.1559999999590218 seconds under a 30-second cap, with all tested hashes unchanged:
55 preparation, 34 Dagger preparation, 58 finish-reward and 79 consumable checks.
The real `Decision.run` secondary-hand test disables all score/context work,
confirms exact Pair level 1 → 2, Chips 10 → 25 and Mult 2 → 3, and tests main-hand
priority, shop exclusion, positive history, both Observatory fields, Perkeo,
Fool identity, protected Negative inventory and the preservation hook.

Candidate hashes:

- `Brainstorm/Advisor/blind_prep.lua`:
  `89a6c0c6a000b4da638a0808cbbfe4895f5839b5949b4c8085a27fb14ff3130b`
- `tests/advisor_planet_preparation.lua`:
  `fc5207a85262beee562efd36f85a2e427d112e0e9c7ad9cf455a6fb5bb0a9cb8`

Root owns any actual-source component comparison, combined regression and
installation. This component agent launched no source or episode worker.

## Original 2.75 main-hand preparation

Source attempt `05_dependent274_to6o` reached the final Cerulean Bell and ended
in an audited loss, 38,802 against 100,000. Two owned Saturn remained unused
through shop steps 218–221, blind selection 222 and the subsequent hands. The
public Straight state was level 19, 570 Chips and 58 Mult, with 21 prior plays.
No Jokers or Observatory were owned. Random boss scoring could not establish
readiness, and existing hand-use thresholds did not select either Planet.
The strategy text said to use Saturn, but the executable action did not.

`Brainstorm/Advisor/blind_prep.lua` now supplies an exact preparation action in
shop or blind-selection phases. It uses the existing `Consumables.apply`
transition for an owned, ordinary, revealed Planet matching the profile's
played main hand. The proposed level must increase by exactly one, finite
Chips/Mult must not decrease and at least one must increase. Cash, hand size,
Joker capacity, consumable capacity and population count must remain unchanged;
one actual inventory item is consumed. No scorer, draw sampler, random boss
model or optimistic future-use sequence is invoked. The result explicitly
makes no readiness or clear claim.

The gate excludes every owned Joker and both Observatory metadata forms.
The selected Planet must be editionless; other owned Negative cards and their
capacity remain intact. Existing whole-inventory preservation and last-source
checks must allow consumption. An owned Fool blocks a use that would overwrite
its different previous-consumable identity. Modified configs/names, concealed
cards, unresolved levels, pending inventory generation and inventories above
20 retain prior planning. Hand and pack phases keep their existing tactical
policies. The hand mapping is generic: Four/Five of a Kind and Flush are tested
alongside Straight. Nothing is keyed by challenge or seed.

The existing `Decision.run` preparation call already precedes shop spending and
blind selection. `shop_scoring.prepared_order` is unaffected: it checks Dagger
or startup-copy Jokers before consulting the preparation module, while this
new action requires no owned Jokers. Dagger/copy setup retains its previous
behavior and bounds. Each use remains a separate user-clickable Product Execute
action followed by fresh advice.

## Focused validation

`runs/planet_preparation275_focus1`: eight fixtures pass in
0.4529999999795109 seconds under a 30-second hidden synthetic Lua-fixture cap.
Recorded runtime and fixture hashes remained unchanged. New
`tests/advisor_planet_preparation.lua` has 35 checks. Full `Decision.run` with
scorer/context functions deliberately disabled uses the two source-shaped
Planets sequentially: level 19 → 20 → 21, Chips 570 → 600 → 630, Mult
58 → 61 → 64. These exact upgrades do not establish a rescued attempt.

Companions: blind preparation 34, blind start 49, shop start 30, revealed Planet
commitment 62, shop Planet commitment 32, equal-history shop Planet 47 and retry
policy 90 checks. The actual exported source step 222 was inspected read-only;
this component agent did not execute a new source or detached replay worker.

Component hashes:

- `Brainstorm/Advisor/blind_prep.lua`:
  `4feaa9ac74c7e94cd2588b6f54a1d4a027873cf67f4fd6815ca8308135e344fc`
- `tests/advisor_planet_preparation.lua`:
  `6146b8588f999e85c13e2ddede69c49fe9d7f30b03cd1632d706e9f9efed989e`

Root owns combined regression, installation, source validation and checkpoint
records. This note does not itself assert release installation. No live game,
save, native DLL, neural training or win-rate estimate was involved.


## Final 281 release status — 2026-09-13

The secondary played-hand extension is installed in2.81.0-alpha. Final candidate
and exact-installed regression pass113 Lua fixtures and253 Python tests. Actual
source11 step27 was compared in the separately registered root component7:
baseline selects Small with218 score calls; candidate uses Mercury with0 calls,
Pair level2/25 Chips/3 Mult, preserving Chariot, cash and population. Root6's
baseline-zero-call harness assertion error is retained separately. No281 full
attempt was run; all complete-attempt leases were already spent. See current281
checkpoint, release receipt and FINAL_BUDGET_281.json for authoritative closure.
