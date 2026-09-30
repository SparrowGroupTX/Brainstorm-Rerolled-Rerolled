# 386 shop-resource architecture delta

The three-file 2.184 slice is now installed and exact-installed-validated;
read `SESSION_RESET_386.md` and `runs/resources386_final/final_verification.json`.
The source map below is unchanged. The final sentence in its validation row
describes the historical candidate stage.

Read `ARCHITECTURE_MAP_385.md` and its referenced subsystem maps for
unchanged areas. This candidate changes only win-first shop resources:

| Question | Source and evidence |
| --- | --- |
| Why can Strength stock grow without bound? | `Advisor/strategy.lua:build_profile/copy_utility/stock_capacity/inventory_value` values public full-deck rank plans and the physical Perkeo pool; 386 adds a finite useful-stock capacity only for qualified win-first public populations. `manage_teacher_stock` now reviews surplus Strength sale, including Negative capacity. |
| Where are permanent common Joker slots admitted? | `Advisor/strategy.lua:joker_admission/sampled_rescue` is shared by `best_shop_purchase` and `best_pack_choice`. Early ordinary-slot Eternal commons require a complete supported paired four-world rescue; Business's preexisting guard and Negative/late paths remain distinct. |
| Why could a visible Blueprint be lost to a pack? | `Advisor/strategy.lua:best_shop_purchase` ranks individually affordable items. The 386 final-choice tie break detects an admitted durable copy offer that an unknown booster would make unaffordable under the actual debt floor. |
| Does discard search use held consumables? | `Advisor/decision.lua:run` calls `Advisor/search.lua:trial/rollout` for ordinary post-discard play, then `Advisor/consumables.lua:suggest` separately for current-hand use. Passive held effects remain; planned post-draw use is not in the ordinary discard comparison. No discard code changed in 386. |
| What was validated? | `development386/REPORT.md`, exact public `capture/manifest.json` and `selected_advice.json`, `tests/advisor_win_first_resources386.lua`, and `runs/resources386_candidate/{freeze.json,validation/}`. The product is still installed 2.183 while user play runs. |
