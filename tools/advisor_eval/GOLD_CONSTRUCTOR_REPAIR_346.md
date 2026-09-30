# Gold consumable constructor repair 346

## Observed failure on loaded 2.145

The new passive session `session-20260916T050034Z-1` confirms loaded
**Brainstorm v2.145.0-alpha** in 1,846 versioned events. Its latest verified
win is sequence **2242**, the previously studied development seed `YVYN2Z11`:
Verdant Leaf, **686,952 / 400,000 chips**, **$98**, 232 automatic actions in
302.6271422 seconds. Original `set_joker_win` and `set_deck_win` callbacks verify
the result. Caino, Yorick, Cartomancer, Devious Joker and Brainstorm already had
Gold; the confirmed new-sticker count is **zero**, and progress stays **59/150**.
This is a real win but a failure to advance the collection objective.

The run left 22 shops, including 12 with visible missing-Joker offers, and made
no paid rerolls. Those offers do not establish that a legal safe retained
purchase existed. The same frozen prefix includes an earlier Serpent loss and
a subsequent unfinished run; neither is omitted or imputed. Repeated seeds and
selected passive sessions are not an independent performance cohort.

| Recorded decision | Relevant public state | Actual collection gate |
| --- | --- | --- |
| Pre-Small action 2073 / exit 2089 | Missing Loyalty Card $5; cash $85/$81; 22 consumables in 23 slots; buffer zero | Owned-row guard, zero comparisons; Cartomancer still has a free slot |
| Pre-Big exit 2152 | No missing visible Joker; 24/24 consumables; buffer zero; cash $76 | Full-capacity row admitted, no eligible missing offer, zero score calls |
| Pre-Leaf exit 2195 | Missing Eternal Crafty Joker $4; cash $89; 26/26 consumables; buffer zero | Whole-inventory Tarot certificate rejected, zero comparisons and score calls |

At the last decision all **26 freshly captured** held Tarot certificates are
unsupported with the same reason: “The copied Tarot ability, edition, front or
parameters are unsupported.” The inventory is 23 Negative Temperance, one
Negative Sun, ordinary Wheel of Fortune and ordinary Hanged Man. The census of
every already-public held/shop/pack Tarot observation in the entire frozen
2,450-event prefix finds **no supported certificate**. These are new loaded345
captures, not stale344 snapshots. Repeated card observations are not independent
tests. The raw `card.params`, registered-center object and raw front table are
absent from failed-certificate output, so the logs alone cannot identify which
member of the combined guard failed.

## Source-derived mismatch and repair boundary

Already-preserved `functions/common_events.lua:2126–2130` shows vanilla
`create_card` passing `bypass_back = G.GAME.selected_back.pos`; its
`copy_card` code at 2174–2176 retains the parameter table. This is normal
constructor metadata, also retained by Perkeo copies. Installed345
`gold_tarot_hold.lua:168–171` permits only four Boolean parameter keys, so it
rejects this ordinary back-position table. The separate Planet-copy source
qualification in `perkeo_inventory.lua` has the corresponding restriction.

This is an exact source-derived admission mismatch, independently reproduced
in source-shaped manufactured fixtures. It is consistent with the observed
generic failure. **The raw `bypass_back` value was not observed in these failed
public snapshots**, and the recorded certificates remain unchanged. No captured
state was refreshed, filled in or assigned a positive certificate.

The candidate repair covers both Tarot fixed-hold and Planet-copy helpers.
It admits optional `bypass_back` as a plain position table with exactly finite,
nonnegative integer `x` and `y`, plus optional Boolean `viewed_back` and the
known Boolean discovery/lock fields; it preserves the whole
qualified parameter table in source receipts and symbolic copies. It does not
admit unknown parameters, playing-card identities, callable/metatable data or
malformed values. Ordinary raw absent `pinned` remains an unpinned default.
Hidden-card rejection still occurs before identity or constructor reads.
Granular Tarot `reason_code` values distinguish `copy_parameters`,
`front_shape`, `base_shape`, `ability_shape`, `physical_state`, `price_shape`,
`edition_shape`, `center_shape` and `visibility` failures without dumping raw
parameter content.

This is constructor qualification, not a new Tarot-use model or a broader
collection strategy. Whole-inventory, physical-ID, center/config/ability,
price/edition, capacity/buffer, Observatory, Negative and copy-chain guards
remain. The four-world comparison family and ordinary 140,000 / shop 50,000 /
consumable 25,000 / fast-clear 70 budgets remain unchanged. Free-slot
Cartomancer remains unsupported. No native DLL change or new experiment is
part of this slice; all345 captured-evaluation leases remain closed.

## Observed ordering boundary remains separate

Final shop exit2195 has this exact row: **Perkeo, Yorick, Cartomancer, Caino,
Devious Joker, Brainstorm**. Yorick is x3 with 16 discards remaining to its next
increment; Caino is x6. Brainstorm therefore copies Perkeo at shop exit. At the
first hand, sequence2206 requests order `[4,2,3,1,5,6]`, putting **Caino** first;
the next public snapshot confirms that row. Brainstorm then copies Caino,
not Yorick. The recorded advisor comparison reports approximately 48,000 for
Two Pair versus approximately 12,000 in the current row, from 252 bounded order
comparisons. These are logged model estimates, not fresh evaluation or exact
source-score receipts.

The actual first and only final-boss play occurs later at2239, after three
discard actions, Sun use and the2234 sale of Negative Perkeo to disable Leaf.
The logged prediction and actual terminal score are686,952. Selling Negative
Perkeo reduces both row size and Joker limit from six to five and creates no
spare slot. This observed continuation uses actions outside the fixed-shop-row,
hold-consumables acquisition family. It identifies a further integration
boundary, but proves neither a missing-Joker purchase floor nor a rescued
counterfactual. The final score cannot be attributed to reordering alone.

## Validation and evidence

The shared runtime fixture factory was changed to include normal source-shaped
constructor parameters. Against unchanged345 runtime, **all three** affected
fixtures fail: acquisition runtime, Cartomancer and retention runtime.
`development346/root_component/before345/report.json` preserves the exact
inputs and failure log; this exposed why simpler manufactured cards previously
missed the constructor mismatch. After integrating both helpers, the same
source-shaped shared factory and the new tests, **10/10 focused fixtures pass**
in `development346/root_component/after346/report.json`, including the three
formerly failing runtime fixtures. Its log SHA256 is
`6b1ba054faa0f010752480b19153344d43305a6a5466737c8a787242655bf8cc`.

The isolated constructor component separately reproduces failure for old Tarot
qualification and old Planet qualification, then passes **206 checks** with
both candidate helpers. It covers shop, pack and held construction, ordinary
and copied Negative cards, whole-inventory dependency/capacity conservation,
Planet projection, malformed inputs and hidden metadata guards. Its receipt is
`development346/constructor_component/validation_01.json`. The independent
source-shaped lifecycle fixture also passes the isolated candidate in
`development346/shape_audit/validation2.json`. These are manufactured fixture
checks, not original-source execution, captured-policy comparisons or terminal
attempts. The promoted tests are `tests/advisor_consumable_constructor_params.lua`
(206 checks) and `tests/advisor_gold_tarot_lifecycle_shape.lua` (112 checks).
No improved purchase, retention, new sticker or win-rate benefit has
yet been observed for candidate346.

Frozen passive evidence lives under `development346/log_analysis/`:

| Artifact | SHA256 |
| --- | --- |
| `passive_audit.json` | `0aefcae0d9ccc1388e66c41585b772c50ce0ecb927acb910359de9e62e83b1e3` |
| `summary.json` | `ad7fd678ffadaa3f86b3d5174383737b7d77217f050f63dbb842ace60da6ea8c` |
| `public_failure_fields.json` | `2f426f657879c1a4e684b6f61b67544df848e84999905059ae4dff72f6053e39` |
| `certificate_census.json` | `944ed3e6f41f9fe97270930d06c86f4cbfd488a613606d6d19280abaeb6ffd2f` |
| `ordering_timeline.json` | `cf87377e86f568d6ab4580140bb7a5009b0465f9b9c766d76bb76f8a2bb1872d` |

The audit records exact byte counts/hashes for six journal segments, each
original stored frame and reconstructed event anchor, and append-active status
for the last segment. Its 2,450-event prefix has no decode errors. An active
file may subsequently grow; the hash binds the captured bytes, not its future
whole-file contents. Public failure fields preserve every final held card's
identity, ability, base, price, edition and normalized physical state while
explicitly identifying unlogged raw fields.

Preserved source hashes:

- `runs/chicot_order_source1/source/functions/common_events.lua`:
  `522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc`.
- `runs/chicot_order_source1/source/card.lua`:
  `5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`.
- Frozen345 `policy/Brainstorm/Advisor/gold_tarot_hold.lua`:
  `4e49ddf51f4099b7ed6262ceb14444fc046a0975baf0d9976a3ce722f216642b`.
- Frozen345 `policy/Brainstorm/Advisor/perkeo_inventory.lua`:
  `34840071e1956a8d6f743f962af30cc6945b76d024271b42ab2e518de2769710`.

## Release record

Full candidate and exact-installed regression passed **209 Lua fixtures and
361 Python tests**, with unchanged frozen policy and test hashes. Installed
**2.146.0-alpha** at `2026-09-16T00:21:45.6589358-05:00`; backup
`advisor-20260916-002144`. All 86 deployment and 102 frozen product/dependency
files match repository and installation. Policy digest:
`ef4545108629102264c4ca72afed05c0d94c355bb5e5c9e177c3826c62d25a14`.
Current settings and all existing native DLLs are preserved. Activation awaits
normal user restart; no process was controlled. Exact receipts are
`runs/gold346_candidate/validation/report.json`, `runs/gold346_installed/record.json`,
`runs/gold346_installed_validation/report.json`, and final deployment/navigation
verification at `runs/gold346_final/final_verification.json`.

This release ran no new captured policy comparison, source component, seed
search or complete attempt. Every previous experiment allowance remains closed;
the historical four calls from345 are not fresh346 authority or outcomes.
