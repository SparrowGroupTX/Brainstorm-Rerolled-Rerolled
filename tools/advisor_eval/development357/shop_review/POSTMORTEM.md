# Teacher356 live shop and consumable postmortem

Read-only analysis of the frozen `development357/logs1` public journal prefix. No policy, scorer, simulation, game, or save execution was performed. Sequence numbers below refer to `events.json`; each event retains its original BRJ segment, ordinal, and SHA-256 anchor. `observations.json` resolves its observation ID.

Five completed selected searched-opening teacher attempts are present: four losses and one verified Ante8 win. The sixth attempt is still in progress at this prefix boundary. This is not a population win-rate estimate. The win-first teacher profile intentionally does not optimize new Gold stickers.

| Seed | Terminal event | Result | Terminal threshold | Cash at recorded result |
| --- | ---: | --- | ---: | ---: |
| M4BVSY11 | 1945 | Ante6 Serpent loss | 112,910 / 120,000 | $109 |
| YVYN2Z11 | 4278 | Ante8 Verdant Leaf win | 674,187 / 400,000 | $138 |
| S7PXV521 | 4850 | Ante2 House loss | 648 / 2,000 | $5 |
| RH45AD21 | 6968 | Ante7 Big loss | 130,932 / 165,000 | $242 |
| YAEARC31 | 9185 | Ante8 Amber Acorn loss | 147,894 / 400,000 | $5 |

Rental charges can settle after these result observations: later public snapshots show $239 in RH45AD21 and $2 in YAEARC31. YAEARC31's incidental `source_won_field=true` is not a win: verified GAME_OVER, zero hands, and unmet threshold establish the loss.

## 1. Confirmed duplicate purchase dispatch and stale available cash

S7PXV521 buys Judgement at sequence4552 with $7. The card moves to inventory before its $3 charge settles. Sequence4561 dispatches a $4 Droll purchase while the visible cash is still $7. The delayed Judgement cash change to $4 is then treated as completion of that Droll purchase: sequence4568 logs `action_observed` based on a changed fingerprint. Sequence4570 dispatches another purchase of the same physical Droll, `card:683`, only 0.284 seconds after the first. Sequence4575 finally contains Droll in inventory but still shows $4, so sequence4579 opens a $4 Arcana pack. Sequence4584 then shows -$8.

The cash change is exactly consistent with $7 minus Judgement $3, Droll $4 twice, and Arcana $4. No Credit Card is in the observed Joker inventory. Both Droll callback records returned successfully; these records themselves explicitly warn that queued effects can remain pending. Among the 932 action-request records in this prefix, this is the only repeated physical-card buy/use/sell/open/choose found by joining action target IDs.

This is an execution sequencing defect, not simply poor strategic spending. A state fingerprint changing due to an earlier action cannot acknowledge the current action. The execution fence should track the pending action's own physical card/area transition and settle queued monetary mutations before generating another affordability decision. The affected transition and downstream attempt should be flagged as contaminated for straightforward imitation labels. Repairing it does not prove this run would win.

## 2. Expired rental persists through five shops

RH45AD21 owns a rental, perishable Trio. Its `perish_tally=0` and `debuff=true` are already public by the Ante6 entry, sequence6272. It remains held through shop exits6327 ($76), 6467 ($111), 6606 ($154), 6702 ($203), and6863 ($242), and is still present at the Ante7 Big loss6968. It continues charging $3 after rounds. The other held Jokers are Yorick, Perkeo, Blueprint, and Greedy Joker; the held consumables at these shop exits are Hermit only. There is no observed Swashbuckler, Temperance, or other resale-value beneficiary that would explain retaining this particular expired rental.

Sequence6702 explicitly warns that the next blind remains at risk, but still leaves the shop and saves cash. Sequence6863 leaves with $242, an expired occupied slot, and an unopened $6 Jumbo Buffoon pack. The sampled shop scoring frequently reaches its budget and falls back to strategic ratings. Zero reroll actions occur in any of these five completed runs.

Selling the expired rental is an immediately useful candidate independent of the sticker objective; replacement and reroll choices still require complete comparisons and all inventory/slot interaction guards. Retaining a dead rental and building cash is observed. A particular replacement, reroll result, or rescued terminal outcome is not established.

## 3. Perkeo copies work, but the policy destroys its useful copying templates

RH45AD21 correctly reorders Blueprint to copy Perkeo before leaving shops. This mechanism is not missing. The problem is the choice of what remains to copy.

- At sequence6024, Ante5 Small, the advisor consumes the last Venus as safe deck development while it already has a clearing play. The pool becomes Hermit only.
- At sequence6241, Ante5 Water, the second Death creates Three of a Kind with an estimated 691,050 score against a 50,000 target. At sequence6251, the advisor consumes the last Death for development despite the advertised best score staying 691,050. It leaves Hermit as the only remaining copying template while holding $82.
- Subsequent exits copy Hermit and build cash to $242. Three of a Kind reaches level15, but the run misses the necessary rank draws and loses Ante7 Big.

The local use preserves the current clear, but its comparison does not establish that one extra rank conversion now is more valuable than preserving repeated Death copies, or that additional capped Hermit income remains the best pool at this cash level. This is a concrete integration gap between safe immediate development and the future Perkeo engine. The appropriate counterfactual is a whole-inventory comparison of spending versus retaining the last useful template, respecting random selection from all ordinary and Negative consumables. It is not a blanket prohibition on spending the last card during danger, nor evidence that keeping Death would have won this seed.

YAEARC31 also spends its last Mercury at sequence8826, but there it is an immediate proposed clear while behind on score. That is not the same unnecessary-development example and should not be automatically rejected.

## 4. Successful Perkeo sale was appropriate

YVYN2Z11 does not discard Perkeo prematurely. At sequence4256 the advisor proposes selling it to disable Verdant Leaf, comparing a subsequent High Card at 674,187 against 400,000. Sequence4259 sells Perkeo and4278 records a threshold-met original win callback with matching Gold award hooks. It earns zero new stickers because all retained Jokers already had Gold. This outcome is consistent with the selected win-first teacher purpose. It is a useful terminal rescue example, not a reason to make starters unsellable.

## Other review candidates, not proven errors

S7PXV521 chooses Certificate over a visible Card Sharp at4421, then buys Faceless at4433 while its own bounded next-blind comparison remains weak. By4552 it buys Judgement; subsequent shops exit with all five Joker slots occupied and Judgement accumulates unused to four copies. This is a plausible long-term resource over immediate scoring failure, but no alternative policy was executed and Certificate's full combined Perkeo transition is explicitly unsupported by the logged shop evaluator. The duplicate purchase defect also contaminates later cash choices.

M4BVSY11 retains and uses Empress copies correctly (21 logged inventory uses), but loses Serpent with $109 and four Empress copies left. Its Flush is level4; the run's broader growth/discard choices warrant separate review. Having consumables or cash left at defeat alone does not prove that spending them could have cleared the blind.

YAEARC31 reaches Amber Acorn with concealed Joker identities, loses after four plays, and leaves three discards unused. Actions9115, 9133, 9151, and9169 all choose Pair from the public Joker belief. The consistent order family narrows from120 to4 worlds after the first observed play. Every recommendation explicitly limits itself to conservative immediate scoring and says future draws, discards, and consumable uses are not forecast. Thus the unused discards are an actual supported-policy coverage gap, not evidence that Acorn stalled or the system silently forgot to execute its selected action. Its last known deck has Perkeo, Yorick, Fortune Teller, rental Swashbuckler, and eternal Scary Face. Hidden-position identities remain redacted. The public source does not license reconstructing their concealed current slots from stable object IDs or declaring an exact winning reorder without a supported observation-based comparison.

## Training use

These logs are useful real-game evidence and fallible teacher demonstrations, not an expert corpus. Keep all outcomes, tag the duplicate-dispatch contamination, retain the precise advice/action/observation joins, and review the last-template decisions. The win is not proof every prior action was good; the losses do not make every earlier action bad. No numerical improvement or policy win probability is inferred here.
