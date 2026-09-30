# Gold Stake ordinary reroll subset — component 350

This staged runtime slice removes a blanket sticker-modifier exclusion from the existing tactical paid-reroll comparison. It admits only the original-source event that produces an ordinary, unstickered catalog Joker. It does not assign an expected value to Eternal, Perishable, Rental, premium-edition, unsupported, omitted or incompatible-sticker outcomes. Forced `all_eternal` remains blocked. Modifier flags must be nil/boolean in a plain table.

`Brainstorm/Advisor/paid_reroll.lua` is staged here for root review/integration. The final intended fixture path is `tests/advisor_gold_reroll.lua`. No shared runtime was changed by this component and no installation was performed here.

## Preserved original-source evidence

Read-only source files already extracted before this task:

- `tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua`, SHA-256 `522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc`, lines 2133–2150. `create_card` handles `all_eternal` first; one `etperpoll` determines Eternal (>0.7) or Perishable (>0.4 and <=0.7) in mutually exclusive branches. A distinct `ssjr` poll determines Rental (>0.7). Edition polling follows.
- `tools/advisor_eval/runs/chicot_order_source1/source/card.lua`, SHA-256 `5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`, lines 506–523. Eternal/Perishable setters can reject incompatible centers or mutually exclusive stickers. Rental sets its field and recalculates cost. Compatibility can add ordinary outcomes outside the credited event; this implementation credits none of them.

With enabled flags E/P/R in {0,1}, the credited no-sticker catalog factor is `(1 - 0.3*E - 0.3*P) * (R == 1 and 0.7 or 1)`. All three Gold Stake flags give `0.4 * 0.7 = 0.28`. At edition rate 1, existing ordinary-edition mass is 0.96; the combined subset is 0.2688. This is a conservative subset within the existing public catalog probability model, not an empirical chance, seed prediction, rigorous multi-offer probability bound, blind-win chance or improvement in win rate. The existing approximate independent-slot expression is unchanged; its correlation and duplicate-exclusion limitations remain.

The hypothetical scored card remains ordinary and full priced. No sampled actual sticker outcome is created, no seeded RNG is read, and no sticker liabilities are removed from the actual owned row. Candidate rarity/pool denominators, six-offer shortlist, complete full-row victim families (maximum twelve paired comparisons), first paid refresh, cash-sensitive miss comparison, reserves, price/ante limits and the 50,000 shared shop-score cap are unchanged. Unsupported later victims and incomplete comparisons still invalidate the candidate/family. Visible complete upgrades still compete against paid search; weak or zero expected gains still decline.

## Validation receipts

All invocations are manufactured fixture validation through the existing isolated Lua runner, each with a 60-second process cap. No captured state, original-source execution, search, complete attempt, game process, save or player profile was used. Hashes, timing and unchanged-input checks are in each `report.json`.

| Receipt | Result | Elapsed | Meaning |
| --- | --- | --- | --- |
| `baseline1/` | Expected failure | 0.125 s | Existing runtime rejects the Gold Stake production tactical reroll before candidate comparisons. |
| `candidate1/` | Fixture failure retained | 0.141 s | The fixture incorrectly expected $13 to be insufficient when $5 refresh + $2 purchase + $6 reserve exactly fit. Corrected the manufactured cash to $12; runtime unchanged. |
| `candidate2/` | 131 checks passed | 0.140 s | Corrected fixture and a milder controlled negative cash-sensitive miss; runtime unchanged. |
| `candidate3/` | 133 checks passed | 0.188 s | Final fixture adds ordinary-shop scoring-work parity and no compatibility-branch credit. |

The real production `Strategy.shortfall_reroll` → `Shop.new` → scorer case uses a manufactured full row containing an expired Perishable Popcorn and Square Joker, two legal sale victims, eight public playing cards and a $600 next blind. It now selects one reroll with complete victim comparisons, selling the expired filler only conditionally on an ordinary hit. The sampled no-sticker candidate pool has common-rarity mass `0.7 * 0.2688`; empty rarity fallbacks remain unknown. Both the Gold Stake case and identical flag-free case perform **4,360 score evaluations**. Thus this slice adds no scoring work to an already-admitted family, while enabling a family previously blocked before evaluation. Fixture wall times are not live runtime performance claims.

Other tests cover all eight modifier combinations, malformed flags, forced Eternal, missing/guaranteed edition metadata, exact ordinary candidate costs and absent stickers, paid-discard reserve, unsupported/uncertain scoring, a better visible purchase, incomplete late candidate and miss, negative cash-sensitive miss value, deterministic six-offer cap, protected pins, Negative slot conservation, an unknown legal victim, an incomplete later victim and owned rental liabilities. Input fingerprints are unchanged.

## Residual causes of rare/absent rerolls

Static review found additional existing restrictions; they were not loosened:

- `Strategy.shortfall_reroll` requires supported current readiness and complete common-world evidence. Unknown startup effects, unsupported next bosses, uncertain scoring, whole-inventory constraints, legal-victim gaps or an exhausted shop-score budget can still decline. Cash alone does not qualify an action.
- The older generic fallback in `strategy.lua` around lines 1394–1431 runs only when no visible upgrade wins and the build is weak. Its catalog candidates require a known simple scoring/copy role and a high heuristic value. A full row also requires Egg without Swashbuckler, plain Joker, expired Perishable, low Popcorn or low Ice Cream as a specifically expendable filler. A full mature Legendary/copy/Burnt/Perkeo core usually has no such filler. This explains a separate possible zero-reroll path, but broadening it without a complete retained-build comparison would be unsafe.
- The tactical full-row replacement helper requires every legal victim to have understood sale behavior and a known retained-build value. A single legal unknown victim can keep a catalog candidate at zero credit. This component does not suppress that unknown victim to manufacture a favorable subset.
- The current model treats one refresh as an opportunity for immediate sampled improvement. It does not solve multi-refresh shopping, long-horizon scaling, acquisition frequency or eventual loss recovery. Those require separately justified comparisons rather than larger caps or spending simply because cash is high.

No complete-run result or numerical win-rate claim is established by this component.
