# Final teacher356 public-log and Tarot review

This extends `POSTMORTEM.md` using the completed frozen `development357/logs2` prefix: 11,891 records and 1,872 full public observations. No game, save, policy, scorer, replay, simulation, seed search, or original-source component was executed for this review. Earlier findings and the earlier prefix remain preserved.

## Final results

Six matches finished: two verified wins, four losses, zero new Gold stickers. The seventh match, X8XU8Y31, started at11873 and the user pressed HUD Stop at11887. Its opening pack was still pending; it has no terminal result and is not a fifth loss. Three of the ten planned matches never started. These selected searched-opening matches are a small development sample, not calibrated player-population odds.

The additional completed match, I8VUSV31, wins Crimson Heart at11852 with1,503,126 chips against400,000 and $207. Original win and Gold counter callbacks verify it. It retains Yorick, Perkeo, Brainstorm, Devious Joker, and Swashbuckler, all already Gold. Its final result does not establish that the accumulated consumables or earlier decisions were optimal.

| Seed | Outcome | Result record | Chips / target | Cash at result |
| --- | --- | ---: | ---: | ---: |
| M4BVSY11 | Ante6 Serpent loss | 1945 | 112,910 / 120,000 | $109 |
| YVYN2Z11 | Ante8 Verdant Leaf win | 4278 | 674,187 / 400,000 | $138 |
| S7PXV521 | Ante2 House loss | 4850 | 648 / 2,000 | $5 |
| RH45AD21 | Ante7 Big loss | 6968 | 130,932 / 165,000 | $242 |
| YAEARC31 | Ante8 Amber Acorn loss | 9185 | 147,894 / 400,000 | $5 |
| I8VUSV31 | Ante8 Crimson Heart win | 11852 | 1,503,126 / 400,000 | $207 |

Post-result queued rental deductions later change RH45AD21 cash to239 and YAEARC31 cash to2. The incidental `won=true` field in YAEARC31 still does not override GAME_OVER and its unmet target.

## The Tarot complaint is supported, but it is selective underuse

The advisor does use many copies. It also leaves some clear opportunities unevaluated or rejected by an overly strict development path. Merely counting the final inventory misses both facts.

| Run / consumable | Distinct observed cards | Negative cards first observed | Maximum held | Advisor inventory uses | Held at end |
| --- | ---: | ---: | ---: | ---: | ---: |
| M4BVSY11 / Empress | 25 | 24 | 5 | 21 | 4 |
| YVYN2Z11 / Temperance | 26 | 25 | 25 | 1 | 25 |
| S7PXV521 / Judgement | 4 | 3 | 4 | 0 | 4 |
| RH45AD21 / Venus | 11 | 10 | 8 | 11 | 0 |
| RH45AD21 / Death | 3 | 2 | 3 | 3 | 0 |
| RH45AD21 / Hermit | 13 | 12 | 3 | 10 | 3 |
| YAEARC31 / Magician | 3 | 2 | 2 | 1 | 2 |
| I8VUSV31 / Magician | 31 | 30 | 18 | 17 | 14 |

These are physical card identities observed in held inventory, not inferred random draws. In I8VUSV31, all30 Negative Magicians first appear at shop exits, consistent with the declared Perkeo/Brainstorm copies. No consumable sale was requested in any of the six completed matches.

### Magician: verified surplus while the deck remains mostly plain

I8VUSV31 acquires its initial Magician at9560 and repeatedly copies it. Only two inventory Magician uses occur before Ante6. The pool grows to7 at10159, 11 at10402, and15 at10601. Yet the public deck at10601 still contains40 plain cards out of50, with6 Lucky,2 Mult, and2 Bonus cards. It is not running out of unenhanced targets.

Two particularly clean review states:

- At10215, it plays a Straight estimated22,532 against18,000 remaining with7 Magicians held. All8 visible hand cards are plain. The current deck has40/50 plain cards.
- At10427, it plays a Straight estimated56,730 against37,500 remaining with11 Magicians held and7 plain cards in the hand.

The hand/deck observations are preserved in `final_public_deck_samples.json`. The existing `consumables.develop` requires both the original and changed clearing play to have `uncertain=false`. Changing a scoring card to Lucky introduces random upside, which can reject that development even when its nonrandom score floor would preserve the clear. The tactical consumable path also excludes targeted enhancements when a clearing play already exists. This is a plausible source-level explanation for the observed pattern; no counterfactual scoring was run here.

A useful repair would compare the unchanged clearing action's supported score floor before and after an exact legal enhancement, while keeping all population, inventory, boss, Glass, and retention guards. It should not count Lucky averages as guaranteed clears, overwrite stronger enhancements indiscriminately, or spend the last useful Perkeo template without a complete comparison.

The stock peaks at18 Magicians at10994; the deck then has33 plain cards. Most later uses occur when the run is under score pressure:17 inventory uses overall, ending with14 Magicians and2 Hermits. By11749, the deck has34 Lucky and12 plain cards out of50. The final win proves completion of this run, not that delaying those upgrades was harmless in other draws.

### Empress: substantial use, plus specific unspent scoring targets

M4BVSY11 uses21 Empress cards. Before Serpent,37 of51 deck cards are already Mult. Therefore some accumulated Empress copies really have declining marginal value.

Nevertheless, at1883 it plays a Club Flush estimated20,424 with5 Empress held,91,326 remaining, and3 hands left. Two selected scoring cards,5C and4C, are still plain. At1937 it plays a Pair estimated12,937 against20,027 remaining with4 Empress and an unenhanced scoring King. The recorded choices warrant a complete targeted-use comparison. They do not by themselves prove that an admitted alternative would clear the entire blind or rescue the run.

### Copying is functioning; retained-pool strategy is weaker

The logs repeatedly show the correct pre-shop-exit reorder to copy Perkeo with Blueprint/Brainstorm. The issue is what the policy leaves in that pool and when it spends copies:

- RH45AD21 consumes its last Venus at6024 despite an existing clear. At6241, a Death already produces a Three of a Kind estimated691,050 against50,000; at6251 it consumes the last Death for further development without increasing that best score. Hermit becomes the only template while cash is already82. Later it dies with242 and an expired rental Trio.
- YVYN2Z11 accumulates25 retained Temperances and uses only one. High cash alone is not evidence that each Temperance should have been immediately used, but repeatedly creating more payout cards while that money is not converted into strength is not a sufficient strategic objective.
- S7PXV521 accumulates four Judgements with all five Joker slots occupied and never uses them. Its later decisions are also contaminated by the duplicate Droll purchase documented in the earlier report.
- I8VUSV31's many Magicians dominate the random copying pool. The product cannot choose which consumable Perkeo copies; retaining, using, acquiring, or selling a type changes that distribution. Any pool repair must model all held Negative and ordinary cards, rather than assume an ordinary Tarot slot is the sole source.

Source inspection supports the template failure hypothesis: preservation only protects a last-of-type card when removing it decreases the heuristic future inventory value. Hermit's held-copy utility remains high once cash reaches its payout cap; the current utility does not by itself establish whether more cash can be converted into a better survival plan. This can favor deleting a last Death/Venus template while retaining cash copies. Keeping every last type would also be wrong; useless types can dilute better ones. The missing comparison is future usefulness given cash, deck needs, remaining shops, and the complete pool.

## Other conclusions unchanged

The duplicate physical Droll purchase4561/4570 and expired rental Trio held across five shops remain concrete defects. The appropriate Verdant Leaf sale4259 remains a positive terminal rescue. Amber Acorn's four Pair plays9115/9133/9151/9169 leave three discards unused because its public-belief path explicitly admits only immediate scoring, excluding future discards and consumable uses. No additional loss appears after the earlier prefix; the sixth completed match is the second win.

These records can train observation/action plumbing, but should remain marked as fallible demonstrations. Preserve every outcome and contamination flag. Do not label all winning actions optimal or punish all actions from losing runs. No numerical improvement, counterfactual win, or representative win rate was measured by this review.
