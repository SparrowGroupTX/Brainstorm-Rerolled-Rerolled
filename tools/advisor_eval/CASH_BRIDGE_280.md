# Declared-purchase cash bridge — 2.80, 2026-09-13

Installed 2.80 adds `Core/jokerless_opening.lua`'s exported
`M.cash_bridge(snapshot, declared_purchase, options)`. The helper has no seed or
challenge-name condition. Its current caller is the existing qualified first-shop
recipe, after the selected Planet has been bought/used and its declared Telescope
voucher remains unaffordable. This is conditional financing of an already-wanted
purchase, not evidence that the purchase beats using the free Planet or keeping cash.

The first action buys a visible ordinary couponed Planet for $0. Fresh advice
then recognizes the sole held continuation by its unique public identity, exact
original predicted leftover key, and absence from current stock. It can recommend
selling that card for its observed, source-consistent resale value. Advice checks
the voucher identity and price again at every step. After funding, the voucher
purchase follows the ordinary fresh affordability check. The receipt lists three
remaining actions before buying the Planet, two before selling it, and exact cash
amounts. It queues no actions and uses no score calls or RNG.

The selected target Planet is protected. Mixed held inventory, arbitrary held
cards, ambiguous identities, unsupported/modified Planet config, missing prices,
insufficient funds, reserved/full capacity, editions including Negative, debuff,
concealment, eternal/rental/perishable cards, any Joker row, either Observatory
field, inflation and challenge cash/resource modifiers abstain. No broader shop
graph, population, growth, inventory or scoring allowance changed. Signed debt
affordability is corrected to `cash - bankrupt_at`, matching the original callback.

## Source basis and demonstrated opportunity

Read-only original ZIP excerpts: `card.lua` 369–384 calculates resale before the
shop Coupon zeroes purchase cost; 1590–1638 pays the actual resale value;
`functions/button_callbacks.lua` 96–103 uses the signed debt limit, 2318–2325
broadcasts sale effects, and 2404–2461 handles purchases and inflation repricing.
These effects explain the initial Joker/inflation abstentions. No source probe
was run by the component implementer.

Source 7 development snapshots at steps 12/14/16 had $9, an ordinary couponed
Uranus priced $0 with base cost $3/resale $1, empty two-slot inventory, and a $10
Telescope. The previous recipe opened its free packs and eventually left without
the voucher. Those spent records are unchanged under
`runs/jokerless271_push_20260912_214242/source_attempts/07_flush277_ff7p`.

Root's separately registered component lease 5 at
`runs/jokerless271_push_20260912_214242/root_component05_cash_bridge` completed
in 0.218s under a 15s cap. On the detached source 7 step 12 observation, the baseline
opened the pack and the candidate bought Uranus, with a complete cash certificate
$9 → $10 → $0. Both decisions used zero score calls and preserved the input.
This component was not a source continuation or an independent outcome sample.

Source 12, `source_attempts/12_dependent280_ff7p`, then executed frozen 280 against
the original rules. Steps 12/13/14 bought free Uranus, sold it, and bought Telescope;
step 15 observed $0 and `used_vouchers.v_telescope=true`. Acquisition is therefore
demonstrated on this selected dependent development attempt. The attempt still
**lost at Ante 2 Big Blind**, terminal decision 45, 466/1,200 chips with no hands or discards left, in 36.8844087s. It is not a win,
independent rate sample, or evidence of an improved win probability. Trace SHA256:
`58535828a144511d336a0f98400e5ba98c8758b01f1626fbec0119cfeb91f491`.
All twelve complete-attempt leases are now spent; none may be renewed or rerun.

## Tests and installed checkpoint

`runs/cash_bridge280_focus1`: six fixtures  / 489 checks, including 51 new cash-bridge
checks, pass in 0.1196093s under a 30s cap. Tests cover the public buy/sell/purchase
sequence, stale prices, exact identities, signed borrowing limits, all principal
abstentions, purity and determinism. One existing fixture expectation was corrected
because it had explicitly expected the old debt-sign bug.

Core file SHA256:
`a6f857d4a1a929a1332d9c530ddfb0e8ab0c241b85b024c6b9f1098205353934`.
New fixture SHA256:
`8076ddc444bc9b48f6a702ebbe966e1b02ea52dc6ae357f83ac0c6588b2b808c`.
`runs/jokerless280_candidate` passed 113 Lua fixtures and 253 Python tests with
unchanged frozen hashes under separate 60s caps (14.36s / 12.515s).
Final exact-installed regression also passes in
`runs/jokerless280_installed_validation`: 113 Lua fixtures / 253 Python tests,
16.047s / 12.906s, unchanged policy and test hashes.

Installed receipt: `runs/jokerless280_installed/record.json`,
2026-09-13T19:01:26.4070511Z; backup `advisor-20260913-140125`.
All 66 product/dependency hashes match the recorded repository and installation.
Policy digest:
`63b9c29f0c318e66da82f4cd01c956f0790bab2e9cc3715d2682d5bca6a13308`.
Settings remain
`083f6c62a485cceceae4f0c55708ddde2750d18a0912e39cfcca47fc0e722f6c`;
native binaries were preserved. No game control or save evaluation occurred.
Loaded game version remains unknown and activation waits for a normal restart.

## Remaining limits

The helper finances one already-declared voucher with one qualified ordinary
Planet. It does not optimize the value of keeping/using that Planet, the loss of
cash reserves after the purchase, or a different opening route. Its continuation
qualification relies on the caller's verified first-shop recipe and initially
empty inventory; it is not a general authorization to sell previously held cards.
The helper has no demonstrated independent correctness blocker within that narrow
scope. Acquiring Telescope does not establish survival, retention benefits or odds.
