# Expired Trio, unused cash and concealed-hand ordering — passive audit 350

This is read-only analysis of bounded, hashed observation-journal prefixes. No advisor was evaluated, no counterfactual scored, and no simulation, seed search, original-source/native worker, save/profile/executable read or game control occurred. Original journals remain unchanged. Appended observations beyond each frozen prefix are outside this report.

## The reported $154 loss used loaded 2.148

Session `session-20260916T063659Z-1` contains 10,339,034 frozen bytes in ten segments, 3,504 decoded events and no errors, through `2026-09-16T06:54:59Z`. All 2,635 versioned events identify **2.148.0-alpha**.

At sequence **3448**, `06:54:49Z` (01:54:49 CDT), seed **RH45AD21**, game:5, has a verified `GAME_OVER` loss at **Ante 6, round 17, Wheel: 114,658 / 120,000 chips**, with **$154**, zero hands and two discards. The shortfall is 5,342 chips. This is not a result from installed 2.149.

The disabled Joker is **The Trio**, `card:1020`, `j_trio`: `debuff=true`, `perishable=true`, **`perish_tally=0`**, `rental=true`, already Gold complete, sell value $1. It has no Eternal/perma-debuff flag and is not pinned. The explicit zero Perishable tally establishes expiration; this is not classification from a temporary boss-debuff flag alone.

The other held Jokers are Eternal Blueprint, Perkeo, missing Greedy Joker and Yorick. All five slots remain occupied through the loss.

## Expiration and the three subsequent shops

Trio was bought for $1 at sequence 2971 after selling Golden Joker. It is observed held at 2975 with tally 5. Later observed tallies are 4 at 3013, 3 at 3040, 2 at 3129, 1 at 3183, then **0/debuffed at 3242**, logged Ante 6 round 14 with $79. It remains expired and Rental throughout three more shops and the terminal loss.

| Shop after round | Cash on first decision → exit | Visible Joker offers | Recorded actions |
|---|---:|---|---|
| 14 | $92 → $76 | **Missing Supernova $5**, ordinary; Gold Onyx Agate $7, Perishable tally 5 | Telescope $10; Jumbo Celestial $6; choose Uranus; arrange Blueprint to copy Perkeo; leave at 3272 |
| 15 | $81 → $111 | Gold Jolly $3, Perishable tally 5; Earth $3 | Two Hermits +$40; Celestial packs $4+$6; Venus twice; arrange Perkeo copy; leave at 3343 |
| 16 | $120 → $154 | Gold Misprint $1, **Eternal+Rental**; missing Reserved Parking $6, Perishable tally 5 | Two Hermits +$40; Jumbo Celestial $6; choose Pluto; arrange Perkeo copy; leave at 3413 |

The first shop offers a concrete replacement candidate: public sale preconditions permit removing the unpinned, non-Eternal expired Trio for $1, freeing an ordinary slot, with enough cash to buy visible missing Supernova for $5. No global `all_eternal` modifier is present. This was not executed or scored by this audit, so no better outcome is claimed. Likewise, Reserved Parking being missing does not establish that its income could solve the imminent scoring deficit, and Misprint's Eternal/Rental/random liabilities must remain explicit.

All three exits report incomplete shared shop comparisons and fall back to strategic ratings. Exit score-call counts are **47,740**, **48,859** and **46,216**, respectively, with `shop_truncated=true`. The final exit says no affordable upgrade clearly beats cash/slot cost and advises comparing a sellable weak Joker despite holding the expired Trio. Gold acquisition declines the pre-winning-Ante scope; retention review sees no sale-first action. Full recorded advice and compact Gold diagnostics are preserved. Numeric per-card heuristic ratings are not exposed in the journal and are not invented here.

There are **zero reroll requests** among **171 action requests** for this loss run, and **zero among 653 action requests across the entire frozen session**. These counts concern recorded requests, not a claim about every session ever played.

## Separate ordering failure on the Wheel

Shop action 3408 rearranges for two Perkeo copy events. Exit 3413 and all final-blind actions retain this physical row:

`Blueprint → Perkeo → Greedy Joker → expired Trio → Yorick`

Four plays (3423, 3429, 3439, 3445) and one discard (3434) use the concealed-observation path. **No Joker reorder occurs in round 17.** Thus Blueprint remains immediately before Perkeo throughout those plays. In the previous two visible rounds, actions 3289 and 3371 explicitly place Blueprint immediately before Yorick before playing; recorded estimates then were about 210,025 and 272,125.

This establishes a missing integration between shop-exit ordering and concealed-hand advice. It does not establish what a reordered Wheel hand would score or that a reorder would rescue the run. The concealed decisions preserve their uncertainty/unsupported-continuation warnings in the evidence.

## Exact final-shop cleanup context

At 3413 the sole held consumable is **one Negative Hermit** (`card:1092`), inventory limit 3, buffer 0. There are **zero Temperance cards**. `last_tarot_planet` is `c_pluto`; the last explicit held-consumable use is Hermit at 3392. Owned Joker sell values total **$28** (5+10+2+1+10). Rental rate is 3. Current Blueprint→Perkeo ordering gives two copy events, also explicitly stated in advice.

Complete modifier object: `enable_eternals_in_shop=true`, `enable_perishables_in_shop=true`, `enable_rentals_in_shop=true`, `no_blind_reward={Small=true}`, `scaling=3`. No additional modifier is imputed.

## Newer 2.149 session is separate

A separately frozen prefix of `session-20260916T065627Z-1` confirms **loaded 2.149.0-alpha**: 2,904,986 bytes, 1,029 events, no decode errors, through `07:01:55Z`. It records a different verified loss at sequence 748 (`07:00:42Z`): **M4BVSY11, Ante 5 Pillar, 36,675/50,000, $16**. Its row includes missing Supernova and Wily; no Joker is debuffed at that terminal snapshot. That observation is not the reported $154/expired-Trio loss and is not evidence that the new Eternal guard caused the loss. YVYN2Z11 has begun afterward but has no terminal outcome within this newer frozen prefix.

## Receipts

- `passive_audit.json`: SHA-256 `2d2a0ef4c501c9c5fe9ea65fd9781ec7f2af5e9f9da46bb3c1aa5c4521be9b5f`.
- `summary.json`: SHA-256 `2011bb96d1d5e89153156db4b5cb7fc4932699153aba1828985946a45a6730cf`.
- Summary binds both sets of exact prefixes, source paths, append-active qualifications, original decoded/stored-frame anchors, expiration timeline, all three shop decision sequences, complete final-blind action advice, selected unchanged original public events and separate session outcomes.

All experiment allowances remain closed. Observed user-started product searches/runs are passive evidence, not agent-run experiments or a representative win-rate cohort. No current or projected numerical win odds are inferred.
