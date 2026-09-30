# 2.68 Planet refresh component — 2026-09-12

Runtime installation and final combined validation are recorded by the current
checkpoint and deployment ledger. This note describes the component's exact
scope; its focused fixtures are synthetic and do not establish player win rates
or a rescued complete attempt. Current and projected odds remain unknown.

The separately registered `runs/planet_pool_source1` original-source worker
subsequently passed all 10 synthetic cases / 74 assertions in 0.086772 seconds
under its one-use 10-second cap. Its frozen product exactly matches installed
2.68. Registration digest:
`6153225e4fae8d349f641d4a6216e41422b99bfc1f017064dd90ce5da7848048`.
This checks first-slot eligibility, duplicate exclusions and actual prices,
including Showman, Astronomer, discounts and existing inflation. It is not a
complete reroll/acquisition/retention attempt. The lease is spent; do not retry
or renew it. The report, raw case records, source/helpers and hashes are retained.

## Demonstrated gap and resulting behavior

The source `no_shop_jokers` rule sets `G.GAME.joker_rate=0`; it does not prohibit
shop refreshes. Existing paid-refresh advice required positive Joker rate and
available or replaceable Joker capacity. A shop containing only non-Joker offer
types therefore had no supported paid-refresh opportunity, including ordinary
source Jokerless shops.

`Strategy.shortfall_reroll` now dispatches an additional Planet path when the
**actual Joker rate is zero**. No challenge name selects this path. Existing
Joker refresh guards, rarity/catalog logic, replacement comparisons, and free
refresh behavior are unchanged. Nonzero Joker-rate shops continue using the
existing Joker path; mixed Joker/Planet optimization is outside this slice.

## Public source metadata and scope

`snapshot.lua` adds optional shop/pack-only fields:

- `consumable_pool_schema="source_shop_consumables_v1"`;
- `planet_pool` and `tarot_pool`, with detached key, name, source cost, config,
  set, effect and order;
- `consumable_used`, separate from the existing Joker used-key map.

Eligibility applies source unlock, ban and pool-flag rules, Planet softlocks
requiring the corresponding hand's positive played count, applicable Tarot
enhancement gates, and exclusion of Soul/Black Hole from ordinary pools. Pool
entries are sorted by key; neither game RNG nor hidden future offers are read.
At forecast time old shop offers are released from duplicate exclusions, held
consumables are restored to the used-key set, and an active Showman permits
duplicates. Empty-pool fallback Pluto is unassessed and supplies no credit.

Source references, read only from the executable ZIP:

- `functions/common_events.lua:1963–2053`: `get_current_pool`, duplicate rules,
  Planet softlocks and fallback behavior;
- `functions/UI_definitions.lua:742–799`: ordinary shop type rates and
  `create_card(..., nil, 'sho')`, without a Soul/Black Hole roll;
- `functions/button_callbacks.lua:2855–2904`: refresh payment, old-offer removal,
  new sequential offers and later refresh callbacks;
- `card.lua:369–384`: price rounding, inflation offset, discount and Astronomer;
- `card.lua:4727–4748`: used-key removal;
- `game.lua:2119–2120`: the actual zero-Joker-rate rule.

Tarot metadata is captured for future work, but Tarot target search and generated
identities receive no opportunity credit in this slice. The separate source pool
parity result is recorded above; the focused results below are ordinary synthetic
unit fixtures. No game process or save was read, changed or controlled here.

## Complete comparisons and retained limits

The path requires supported under-pressure opening evidence, a paid refresh
cost of **$1–$8**, Ante at most 8, actual consumable capacity, complete source pool
metadata, finite nonnegative type rates, and a valid observed shop size. Forced
shop/tag/tutorial rules decline the ordinary pool model.

Only the **first newly created shop slot** contributes opportunity credit. Its
type-rate share and eligible Planet-pool share are known before new offers alter
duplicate exclusions. Later slots are ignored; there is no independent-slot
probability approximation, seed prediction, win probability or percentage claim.
Unassessed types, candidates and unsupported comparisons remain explicit unknown
mass with zero scoring credit.

At most six deterministically ranked Planet entries are compared. Each entry
has a complete hold endpoint and, when preservation permits, a complete exact
use endpoint: at most twelve paired endpoint comparisons plus one miss comparison
and the existing baseline comparison. All calls use the existing shared shop
scoring context and its 50,000-evaluation cap. A cutoff in any admitted comparison
invalidates the whole refresh recommendation; partial favorable results cannot
win. The search and fast-clear budgets are unchanged.

Both hit endpoints pay the refresh and actual purchase price before scoring.
Pricing includes the current inflation offset, source discount rounding and an
active Astronomer's zero price. **Purchase-triggered global Inflation repricing
is unsupported** and declines this path. Full inventory cannot be bypassed by an
imagined sale, preemptive use, or miscounting a Negative slot.

Hold/use endpoints preserve whole-inventory Perkeo and Observatory valuation.
Last useful copying types are protected; holding a new card cannot silently
dilute future copying value. Supported sampled finishing regressions and
unfunded post-purchase reserves also receive no credit. Comparisons use exact
existing Planet transitions, including usage counters and Constellation growth.

Every miss pays the refresh and retains the actual inventory/Joker row. A
complete cash-only miss comparison charges negative scoring consequences;
positive unmodeled refresh growth receives no speculative credit. Rental,
paid-discard and observed debt allowances remain protected through existing
liquidity logic. The bounded gain/spend estimate must clear the existing target
gain threshold and beat the complete visible choice's gain per dollar by the
existing margin. After the user clicks refresh, revealed offers require fresh
advice; no speculative purchase or use is executed.

## Focused frozen evidence

`runs/planet268_focus1` contains the registration, copied Lua modules and
fixtures under `frozen/`, output log and report. One hidden synthetic fixture
worker had a 30-second cap and completed in **0.6237138999858871 seconds**:

| Fixture | Result |
| --- | --- |
| `advisor_planet_reroll.lua` | 42 checks; real scorer component 3,488 evaluations |
| `advisor_snapshot.lua` | 107 checks |
| `advisor_paid_reroll.lua` | 49 checks |
| `advisor_reroll_integration.lua` | 8 checks |
| `advisor_reroll_miss.lua` | 9 checks; real scorer component 3,488 evaluations |
| `advisor_reroll_magnitude.lua` | 24 checks |
| `advisor_shop_copy.lua` | 43 checks |

All seven fixtures passed. Coverage includes deterministic metadata and advice,
ordinary rate/price/duplicate rules, capacity/debt/reserves, forced/unsupported
shops, unknown mass, charged misses, late cutoffs, visible alternatives, full
Perkeo inventory protection, exact Planet-use endpoints and real bounded scoring.
No complete-attempt evaluation budget was spent or renewed by this fixture run.

Stable component SHA-256 hashes at handoff:

- `Brainstorm/Advisor/snapshot.lua`:
  `8d0194c1bf1e30fa57a8edbcbb7693d02d092386dbae50cc727f2a5689c3e217`
- `Brainstorm/Advisor/paid_reroll.lua`:
  `547d35a4c3d8e6fbbdd8891b016429f39c9c754fa32a975353f606fd528728f3`
- `Brainstorm/Advisor/strategy.lua`:
  `7e8df1a498fa7113a01f312220779b519ce2948399bc7a4f3d5d5a6ec183ef09`
- `tests/advisor_planet_reroll.lua`:
  `2d55e48c1958556cabc33fc6d1a35d581ed308b58813be286df0d2feac667463`
