# Midrun mixed-inventory Planet planning: read-only assessment

Exact public run4 event3344 has eight Negative Venus and one ordinary Hermit (nine cards total), not nine Venus plus Hermit. The nine-card inventory persists to terminal event3388 (18340/37500). Three of a Kind is level4 and played four times at3344, but no later observed hand contains three equal ranks. Consuming Venus alone therefore cannot be called a rescue. Public source: `public_trace/run4.json`, snapshot `public_trace/snapshots/b9b1cb9730d1b3dc2b916571c699505a2f648e1356c971be803721238192906f.json`.

## Existing boundaries

- `blind_prep.lua:363` only prepares Planets in no-Joker, no-Observatory states; shop keeps the actually played main hand, blind selection can include another actually played hand.
- `gold_planet_policy.lua` only considers supported final bosses with retained Gold targets. Its `perkeo_inventory.planet_family` requires homogeneous qualified Planets and at most eight cards. Neither matches this midrun mixed inventory.
- `consumables.suggest` compares exact held uses against current-hand plays, with shared25000/140000 score limits and whole-inventory preservation. It has no general Planet-then-draw continuation; its existing resource-use scope excludes Planets, Jokers and Observatory.
- `consumables.apply` already carries exact level, consumption counters/last Tarot-Planet, Constellation, Negative capacity and population effects. This is the transition to reuse.
- `strategy.preservation_cost` compares the entire inventory copying pool and Observatory holding utility, including last-source loss. Its future-copy utility is heuristic, not a proven terminal bound. `shop_sequences.transition` uses this and rejects positive loss. Relaxing those guards alone would be unsound.

## Smallest useful complete extension

Use a new bounded blind-selection family, before an unknown draw. Retain every non-Planet card in every endpoint; enumerate hold and exact qualified Planet use counts for every actually played represented hand, split ordinary/Negative classes. Collapse interchangeable copies only after proving equivalence of all relevant ability/provenance fields; preserve exact selected IDs in emitted first actions. Count classes/endpoint products before scoring and decline the whole family if the existing cap cannot finish it. This admits a mixed retained Hermit without pretending to evaluate arbitrary Tarot sequences.

Compare each fixed endpoint with hold across the same complete public-composition draw worlds and supported complete remaining-blind policies. Do not force the profile main hand or select a different root use count in each world. Reuse exact transition/scoring/cash/population/boss support; reject unsupported mechanics, uncertain concealed information and incomplete worlds. Preserve Perkeo copy sources using the existing whole-inventory loss rule at first; retain Observatory multipliers in real score and copying pool, and qualify any future relaxation separately. Include actual use/reorder/play/discard actions and prefer fewer uses when the same survival floor is attained.

This is a bounded Planet-use comparison with non-Planet inventory retained, not a complete mixed-consumable planner. Hermit/Temperance use and arbitrary targeted Tarot alternatives must either enter a separately complete resource family or remain explicitly outside its claim. Exact all-ordinary-consumable joint planning requires additional transition/order qualification (cash changes, Luxury Tax, Fool history, copy-pool changes); it should not be smuggled into a relaxed homogeneous guard.

No policy was evaluated on this snapshot, no runtime was edited, and no experiment lease was consumed by this assessment. Manufactured coverage should include two Planet types with played-history ties, an unplayed stronger hand, retained Hermit/Death, all-remaining-copy-source loss, Negative capacity, Observatory reversal, inventory-order non-equivalence, zero-use/current-clear choice, boss hand restrictions and cap/unsupported fallback.
