# C01 normal Red Deck Gold Stake development postmortem

This note analyzes the preserved C01 run only. Later attempts and releases have separate records; this is not a current combined win-rate summary. No new source execution, search, checkpoint restore or player-file access was performed for this analysis.

## Audited outcome and limits

Frozen installed policy300 completed the selected synthetic Red Deck Gold Stake run on development seed `M4BVSY11`: final Ante8 Cerulean Bell scored **705600 / 400000**, with no GAME_OVER and no saved-by-Mr-Bones exception. The original source's `set_joker_win` then `set_deck_win` callbacks increased the loaded synthetic Gold counters for **Yorick, Brainstorm, Droll, Scary Face and Flower Pot**, and Red Deck. This is a verified selected original-source development win, not player achievement progress, a Jokerless win or a population win-rate estimate. The overall adapter remains unqualified.

The run took 225 actions and 172.14000000001397 seconds of outer worker time. All 225 recorded actions resolved with original-source legality and continuous public-state fingerprints; all 28 played-hand scores exactly matched the advisor's deterministic predictions. There were no selected-play supported-floor substitutions, random score gaps or score mismatches in this run. These score observations do not qualify every adapter mechanic or the entire random process.

The profile was `all_unlocked_discovered_v1`, fresh in-memory and unqualified for player populations. Retry context was disabled and clean. Missing-Gold objective context was disabled for this fixed-build survival baseline; no actual player missing-sticker list was inferred. Static discovery targeted Yorick/Perkeo in the starting Charm pack and Brainstorm/Burnt by Ante5, but did not promise acquisition or retention.

Exact evidence: `runs/gold299_20260914/C01/audit.json` contains provenance, terminal callbacks, every compact action receipt and observed budget overruns. Trace SHA256 is `982d52f155c6ceac74023c0a4d2960fd6c2db62bd1757cc699007f8a8bef63a1`; policy digest is `db3ea1cd6d6f6f0053da326aba6bce2074c23197d0ff8720dab712c0688d2ca3`; registration SHA256 is `39eebb7a17fb4a74f3ce0d65b4f8ee21289803ded39e4175fd139974785d2a7a`.

## Acquisition and permanent slot commitments

| Step | Information available at the decision | Actual choice and consequence |
|---|---|---|
| 2–3 | Two visible Soul cards in the actual opening pack | Acquired Perkeo then Yorick through original source. |
| 13 | Visible Eternal Brainstorm in the already-opened Buffoon pack; cash $5 | Chose Brainstorm; acquisition cost was the earlier pack opening, not the displayed Joker cost. |
| 14 | Eternal Droll offered for $4; cash $5; two free Joker slots | Bought Droll, leaving $1 and one free slot. |
| 22 | Eternal Scary Face offered for $4; cash $9; one free Joker slot | Bought Scary Face, leaving $5 and a full row. |
| 59 / 61 | Nonperishable Burnt visible for $8 at Ante3; cash $18 then $14; full row | Opened an Arcana pack for $4, then left. Burnt was never acquired. |
| 138–140 | Ante6; $61; three Negative Empress cards; full row; visible Flower Pot | Reordered for Perkeo copying, then sold Perkeo for $10 and bought Flower Pot for $6. |

Burnt was affordable when offered. The obstruction was the full row: Brainstorm, Droll and Scary Face were Eternal, leaving only Perkeo or Yorick as legal sale victims. A proposed counterfactual “sell Droll to buy Burnt at step59” is mechanically invalid. An earlier decision to decline one Eternal filler is legal and could preserve a slot, but it also gives up its immediate scoring and may change early survival. The original run eventually winning with both fillers does not establish that buying them was optimal; conversely, Burnt's attractive long-term effect does not establish that declining them was safe.

The useful general repair is to include permanent slot commitment in a bounded survival-versus-development comparison before a low-cost Eternal purchase, accounting for the current engine, remaining open slots, cash and supported future flexibility. It must not name this seed or automatically reserve a slot for Burnt solely because the search targeted it. Any exact future encounter knowledge must be carried as explicit supported route metadata, not imported from the audited future trace. The separate early-Eternal audit owns the concrete comparison; this note supplies the causal timeline.

## Perkeo: copy eligibility and inconsistent shop ordering

At step25 the advisor selected **Death from an Arcana pack and immediately used it** on the displayed cards. It never became a held consumable. Keeping that particular Death for Perkeo is not a legal alternative under the original pack mechanics. A held Death from a shop, or a supported Fool copying the prior consumable into inventory, would be a different decision with different cash, inventory and availability requirements.

The first held copy target was Empress, bought for $3 at step50 from $16. The advisor reordered Perkeo and Brainstorm at step51, then left at step52; original source produced two Negative Empress copies. Later actions used copies while retaining a target. This establishes actual copy generation and use, not that Empress was the globally best available development plan.

Steps138 and139 expose a narrower defect: the shop initially intended to leave and the phase specialist reordered Perkeo to obtain two copy events instead of one. After that legal row-only permutation, the shop switched to selling Perkeo for Flower Pot. Cash, inventory, offers and the physical Joker set were otherwise unchanged. Reordering to prepare a phase should not arbitrarily change which physical candidates enter a bounded shop comparison. This is a reproducible integration/order-sensitivity defect independent of whether Perkeo or Flower Pot ultimately wins the strategic comparison.

The appropriate repair is stable physical candidate selection and complete comparable candidate evaluation under the existing budget, with original physical action indices mapped back correctly. The shop-order repair and its captured-state comparison are tracked separately. It should not force retention of Perkeo: the baseline did win after selling it, and a missing-Gold objective can legitimately favor a supported late replacement. Perkeo was absent from the final held row and received no terminal Gold increment in C01.

## Yorick and nonlinear discard value

The advisor discarded 145 cards in 41 discard actions; ten discarded five cards. It used three discards in each of the first five rounds, but discarded only 9, 13, 13, 9 and 15 cards respectively. This is evidence of partial awareness and an opportunity to assess discarded-card counts, not proof that every smaller discard was wrong. Gold Stake resource changes and the loaded number of remaining discards must govern; the Red Deck label alone is insufficient.

In round2, the last discard at step19 selected four cards. A fifth discarded card could cross a Yorick upgrade boundary in a nearby state, making the combined growth/scoring consequence nonlinear. A valid repair must compare complete public-world alternatives using the actual counter, possible redraws, remaining hands/discards, held consumables and forced-card/boss restrictions. It cannot assume the future draw observed in the original trace also occurs after discarding an additional card. Blindly maximizing five-card discards can destroy a necessary clearing hand; blindly valuing a discarded card by a fixed small bonus can miss the exact upgrade boundary.

Burnt was never acquired in this run, so C01 contains no live Burnt first-discard evidence. Its absence cannot be used to claim the existing first-discard planner succeeded or failed. A source attempt that actually acquires it, or an independently registered captured-state comparison, is needed for that specific behavior.

## Computation and real-time objective

The advisor consumed 139.63615010003562 seconds, source effects 26.86408820014914 seconds, and snapshots 0.14469229948008433 seconds. Total scoring calls were 8395860. Thirteen ordinary decisions exceeded the nominal 140000 aggregate budget because individually bounded specialists could stack after the main search. The maximum was 169367 at step120; step205 made 150172. This is an actual budget defect even though the terminal outcome was valid.

The implemented narrow repair in `Brainstorm/Advisor/decision.lua` gives each later specialist only the remaining ordinary aggregate allowance. Main search keeps its original allowance; no reservation, compute increase, sampling change or partial-candidate shortcut was introduced. Whole complete comparisons remain required. The six-score consumable development path is also explicitly clamped. Seventeen focused budget checks plus existing integration fixtures passed.

The separately registered M09 captured comparison failed **before any policy decision** because the old CRLF string serializer exceeded Lua51 syntax depth. Its 0.20300000003771856-second error and spent lease remain at `runs/gold299_20260914/M09/audit.json`; it provides no captured-policy comparison evidence and is not a policy regression failure. A new independently tested byte-literal serializer was prepared for other future registrations. No M09 retry or silent lease renewal occurred.

The run had one blind skip, 23 selected blinds, 20 opened packs, 28 plays and 16 Joker reorder actions. These are useful costs to optimize only after preserving survival and collection progress. The single eventual win does not retrospectively prove any skipped shop or blind was safe at an earlier decision. A calibrated speed policy needs prospective terminal evidence, not a guessed “already highly likely to win” threshold.

## What this run supports next

Prioritize the definite aggregate-budget and order-sensitivity defects, then test permanent slot commitment and exact Yorick threshold comparisons with legal, complete alternatives. Keep all uncertain, unsupported and timed-out records. For future policy comparisons, separately freeze the policy and adapter, register unseen seed selection where claimed, and report terminal outcomes alongside runtime/actions and censored-progress summaries. Average failure round alone must not turn timeouts into losses or reward slow computation. One selected successful run supplies no defensible success percentage or confidence interval for ordinary players or Completionist++ completion time.
