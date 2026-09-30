# Ten-start diagnostic audit — 2026-09-22

This completed batch is usable for operational outcomes and diagnosis. It is **not
prospective**: the user had already played it when the initial manifest was written.
Hypotheses were recorded before analyst outcome extraction, not before outcomes existed.
No new cohort, policy change, installation or experiment was performed or authorized.
Canonical findings and future updates: [WIN_RATE_RESEARCH](../../WIN_RATE_RESEARCH.md).

## Provenance and denominator

Frozen session `session-20260922T181247Z-1`, 18:12:47–19:06:52 UTC, final sequence19614.
All26 segments were stable when copied; 19,614 records, no gaps or decoding errors.
Raw hashes/record anchors: `capture/manifest.json` and `capture/events.jsonl`.
The preceding observed-game:1 is pre-batch context; the ten starts are observed-game:2–11.

Repository/installed checkpoint2.164:105 frozen runtime/dependency hashes matched
both locations, digest `39cdc64bf7775b5f682b0b045921a54a8fbcfc78da424ae634de25b8e6dac77a`.
The364 receipt records89 deployment files and installation13:05:20.8042556-05:00.
Public logs now attest **loaded2.164** in17,729 version-stamped contexts, superseding
older activation-unknown notes. They do not attest a loaded in-memory policy digest.
Installed2.160 receipt checked separately:11:40:58.3492402-05:00, digest
`81293cad23d26248233391c6066c9e3f2c6a59e63239151e8cbc416cc9b05857`.
That receipt establishes installation, not activation or a2.160 win-rate improvement.

All3,104 public snapshots carry `perkeo_yorick_win_v1`, with collection progress
present and the optional `completionist_goal` absent. `runtime.lua`'s capture wrapper
does this projection; `decision.lua` gates collection acquisition on that absent
goal, and `gold_slot.lua` does likewise. Narrow expired-rental retirement may still
use collection progress; it does not re-enable optional sticker trading.

All ten search requests were identical: Red Deck, stake8, two Souls, Charm Tag,
Yorick/Perkeo soul targets, interchangeable Brainstorm/Blueprint by Ante5,
Burnt target with fallback allowed, reject perishable targets, minimum distinct0.
Product receipts report32 native threads,9000ms native request budget, found status
for all10, route `conditional_no_reroll_stock_and_buffoon`. The outer30s search cap
remains separate. Actual actions skipped the observed Small Charm and selected
two Souls; both intended legendaries appeared in all10. These were observed route
facts, not an assumed universal Small Blind tag. The conditional search does not
guarantee subsequent purchase, affordability, or opening every required Buffoon pack.
Run10 passed visible Buffoon packs at17465/18363; their unopened contents are unknown.

Ten different seeds occurred within this batch. Previously studied openings occur
again (certainly M4BVSY11); these are neither ten independent draws nor a held-out
benchmark. There were no logged manual pause/resume events. Twenty-two
`player_callback` records comprise10 automatic Charm-pack uses and12 Hook discards;
that source label alone is not evidence of22 manual interventions. Absence of a
manual event cannot prove absence of unlogged user input. Exact live settings-file
hashes during play and loaded source hashes were not attested; do not invent them.

## Outcomes: 3 wins / 10 starts

Operational yield is30% for this selected diagnostic batch; the terminal subset
is3 wins and6 losses. One unsupported retirement is separate from game losses.
There are0 logged errors, timeouts, user interruptions or unfinished starts.
The session stopped at the10-start limit, not a ten-win target. This is not a
calibrated population win rate or evidence of improvement over an older cohort.
Runs5/10 contain an incidental true `won` field at GAME_OVER; their insufficient
final scores and verified loss records remain losses. Wins use threshold plus
original win-callback evidence, not that field alone.

|Run|Seed|Outcome|Last blind / recorded score|Copy acquired|Start → outcome sequence|
|---|---|---|---|---|---|
|1|M4BVSY11|Unsupported|Ante7 Mouth143,374/220,000;2 hands remain|Brainstorm Ante1|19→2407|
|2|YVYN2Z11|Win|Verdant Leaf477,000/400,000|Brainstorm Ante3|2421→4894|
|3|S7PXV521|Loss|Ante2 House460/2,000|No|4915→5446|
|4|RH45AD21|Loss|Ante6 Small8,334/60,000|No|5463→7013|
|5|YAEARC31|Loss|Amber Acorn342,706/400,000|No|7032→9133|
|6|I8VUSV31|Win|Crimson Heart552,492/400,000|Brainstorm Ante4|9157→11750|
|7|X8XU8Y31|Loss|Ante7 Needle69,732/110,000|No|11771→13534|
|8|BWHHPZ41|Loss|Ante4 Small6,680/9,000|No|13551→14561|
|9|8TCSQ651|Win|Violet Vessel1,230,592/1,200,000|Brainstorm Ante5|14580→17033|
|10|NVXU7E51|Loss|Violet Vessel578,940/1,200,000|No|17054→19612|

## Leading cluster1: acquisition, liquidity and surviving expiration

All3 wins acquired Brainstorm. None of6 losses acquired either copy Joker.
The fourth copy-owning run was retired unsupported, so copy ownership was not
sufficient for success. Survival long enough to see offers is a confounder.

There were9 distinct publicly visible copy offers across9 runs:4 acquired,
3 unaffordable from cash alone at departure,2 affordable but passed. Sale-funded
alternatives for the three cash-short offers were not established by this audit.
All9 targets were nonperishable. See `copy_opportunities.json` for exact anchors.

* Run4: leave6505, Blueprint$10, cash$47, five occupied slots, sellable Sly/Greedy/
  Trio alongside Yorick x5 and Perkeo. Shop evidence reports39,990 evaluations,
  `shop_truncated=false`, and only partial sampled next-blind readiness. Later,
  leave6918 retained an expired/debuffed rental Trio; Certificate also remained.
  The subsequent loss had Three of a Kind level13 but no surviving Trio multiplier
  and failed to draw that hand. This traces the failure beyond the last play.
  Existing357 retirement is deliberately narrower: its supported independent-row
  list excludes Certificate. This is not evidence that the357 code was absent.
* Run7: Wasteful bought12817 for$10 from$12 while a rental Blueprint$1 was visible;
  leave12828 at$2. Wily was sellable; other important Jokers were Eternal and a
  Negative Misprint affected capacity. The remaining rental liability and uncertain
  scoring mean affordability alone does not prove buying was best. Shop evaluations
 23,241 and `truncated=false` do not support blaming ordinary140,000-score exhaustion.
* Contrasts: run2 bought a$10 copy with$16; runs6/9 bought rental copies for$1 with
 $76/$49. Run8's early$10 offer met only$3 cash; later Lusty expired before its loss.

Static mechanism worth repairing: `strategy.lua:replacement_sale_plan` calls
`best_shop_purchase` once for each hypothetical sale. Only that generic winner
proceeds if it is a Joker with score>=26; final whole-row merit is evaluated later.
A voucher winner, or another Joker with lower final replacement merit, can hide
a superior sell/buy endpoint in this ordinary path. A broader
`shop_sequences.suggest` graph already exists downstream in `decision.lua:194`.
It rejects inventories above4, unsupported readiness and voucher incumbents.
Run4 held6 Venus plus1 Hermit at6505, exceeding that graph's admission bound even
though a Joker replacement need not spend any consumable. Run7's voucher incumbent
at12817 is also outside the supported graph; after the voucher, logged random
readiness remains a competing explanation. This narrows the proposed repair to
a held-inventory replacement family when the broader graph cannot run; it is not
a request to implement an already-existing sequence planner. Existing exact
endpoint scoring and copy ordering must be reused. The current logs
do not record which rejected endpoint blocked either observed Blueprint. Thus the
selection bottleneck is supported by source; its responsibility for these losses
and any rescued-run claim remain unproved.

## Leading cluster2: development needs useful hands and a useful copying pool

Across174 shop exits,149 had consumables;58 exits were in Antes6–8,49 of those
held at least two cards. There were **zero consumable sales**. Observatory was
absent from every recorded snapshot. Generic use/hold/sell pool planning is absent;
`strategy.lua:inventory_value` models uniform copying, including Negative copies,
but its direct per-copy utility is additive and does not saturate at remaining
usable targets. `preservation_cost` already allows consuming a low-value last type
when removing it improves future pool utility; do not replace it with protect-all.

Run1 used23 Empress cards, so Empress was not categorically useless. Yet it finished
the prefix holding8 Empress and1 Venus, with low hand levels and no affordable
hand-type transition after Mouth locked Two Pair. That pool would select an Empress
on8/9 of uniform first-copy draws at a shop exit, if unchanged. This is arithmetic,
not a claim about hidden RNG or an actually reached next shop.

Run4 used12 Venus and one Death (6247–6852, Death6772), reaching level13 Three of a
Kind without a reliable three-card-rank draw in the losing round. Run5 used14 Mercury
and reached level15 Pair, but still lacked a copy and lost under Acorn's limited
planner. Run7 held8 World at its Needle loss; only one World use was recorded.
Run10 used13 Sun and216 discarded cards, reached Yorick x10, but low hand levels
and no copy left the Violet Vessel far out of reach. These are different development
paths; forcing Kings/Four of a Kind would not address all of them.

Contrasts matter: winner2 finished with21 Temperance, winner9 with18 Moon; winner6
used20 Magician and won while holding6 Justice. Large inventory is a symptom of
possible wasted potential, not proof of a losing choice. The count of *profitable*
use/sale opportunities is unknown, not149. No alternative-action scoring was run.

Your pool concern is mechanically sound: Negative copies remain in the random
selection pool, and weak held cards can dilute a useful planet/Death/economy target.
But selling every nonpreferred card or always preserving one of each would both be
too rigid. Compare whole-inventory use/hold/supported-sale value against remaining
targets, shops, cash and action costs. With Observatory, matching planets multiply
scoring; without it, permanent levels can matter immediately. Even with Observatory,
a low-level hand can sometimes benefit more from a level than the lost x1.5, so the
decision should compare those effects rather than impose an unconditional rule.

## Leading cluster3: boss restrictions and incomplete future comparisons

Run3 House played four hands at5406/5416/5427/5438 and died with3 discards.
Every recommendation explicitly used immediate concealed fallback because hidden
discard history involving Faceless Joker was unmodeled. The scope omitted spending
consumables and future discard planning. Its4 Judgements were held in a full row.
Earlier cash shortage prevented the visible Brainstorm purchase. This is a combined
development and coverage failure, not proof that ordinary Yorick growth was too timid.

Run5 Acorn used four immediate public-order plays9065/9083/9101/9119, retaining3
discards and2 Mercury. First comparison covered120 public identity orders, later
ones2. Immediate conservative scoring is implemented; joint discard/consumable
planning over those beliefs is not. Do not reveal concealed identities or assume
a hypothetical discard would have won.

Run1 Mouth spent its last discard2374, locked Two Pair2385, then played Two Pair2396.
Recorded increments76,342 and67,032 match displayed estimates. At2401 only one pair
was visibly available;2404 reported no scoring play, and2407 retired unsupported
with2 hands remaining. `scoring.lua` rejects a mismatched Mouth category. Legal
zero-scoring cycle plays, and earlier repeatability of the lock, need a separate
qualified comparison; this was not a terminal loss or confirmed inevitable defeat.

Ordinary advice showed247 executed recommendations with order-budget warnings,
108 consumable-budget warnings,170 unavailable remaining-blind comparisons.
Of835 action-linked hand timings available,23 reached140,000. Missing timings and
candidate reasons are unknown. There were9 executed concealed fallback recommendations
and4 Acorn immediate recommendations. A warning does not prove an omitted winning
action; do not raise existing caps or weaken scope guards to manufacture coverage.

## What changed about discard and scoring hypotheses

Of76 Ante1–3 cash-out clears,32 retained discards, totalling75. These are potential
inspection points, not75 safe useful growth actions. Winner6 retained17 across its
eight early clears; loser10 grew furthest. Safe-growth rejection reasons/floors were
not serialized, preventing a count of justified missed growth opportunities.
The359 priority repair remains present and is not being repeated.

All1,852 requests have callbacks; accepted callbacks have linked settled observations.
This establishes traceability, not complete settlement or correct scoring. A simple
arithmetic audit found295 ordinary play titles with parseable estimates and same-round
settled scores:234 increments match within one chip;61 differ. The largest relative
shortfalls inspected involve Misprint, Lucky effects or Hook, with uncertainty notes.
This does not falsify their means or validate all floors. Typed mean/floor/exact fields
are needed. See `score_arithmetic.json`; no captured state was sent to a scorer.

Public structural copy-target counts also show phase-sensitive ordering:57 shop exits
targeted Perkeo and2 Yorick;61 plays targeted Yorick,9 Perkeo,5 Swashbuckler;97 discards
split66 Perkeo/31 Yorick. These are visible row targets, not all certified compatible
effects. Copying Yorick on discard does not multiply its physical growth counters.

## Highest-leverage proposed delivery

See [REPAIR_SPEC](REPAIR_SPEC.md): compare **complete visible sell/buy endpoints**
before generic shop arbitration, with auditable admission/rejection receipts.
This is the first proposed repair, not an instruction to force every copy purchase.
Perkeo saturation/pool sales and public-belief boss planning remain separate work.

## Collection preflight: NOT READY for the requested fresh, no-purge study

The completed batch is valid for the above bounded conclusions. No replacement batch
is requested. Current teacher UI is `Clear logs + 10 win-first runs`; it calls
`prepare_collection(clear_existing=true)`. `Start collection marathon` preserves logs
but chooses the collection objective. Neither is a no-purge win-first start. Existing
batch's user-click clear receipt records11,173,199 prior bytes removed before this
audit; no logs were deleted by this audit and no further purge is authorized.

Frozen archive input46,369,034 bytes leaves1,027,372,790 bytes below the1GiB cap at
capture. Decoded342,925,330 bytes is a different measure. Recorder covers opening,
advice/action links, settlement, terminal and unsupported retirement; error reporting
exists but no error occurred here. `player_journal.lua`'s advice projection drops
most structured growth/consumable/candidate/floor diagnostics. These two gaps and
missing loaded-hash attestation prevent the intended stronger prospective comparison.

Smallest prerequisite proposal: separate existing log clearing from teacher start,
preserve existing limits/objective projection, and journal bounded public decision
receipts plus policy/adapter/runtime/settings-recipe provenance without private
profile/save data. Do not make those runtime changes in this audit.

Conditional future user steps, **only after that repair and separate authorization**:
1. Restart Balatro normally yourself; tools must not restart/control it.
2. Select the existing Red/Gold Yorick+Perkeo win-first preset through its repaired
   preserving start control. Do not use today's clear-and-start button under a
   no-purge requirement, and do not substitute normal collection marathon.
3. Verify loaded version/profile receipt and fixed recipe, then start at most10
   starts yourself. Keep500 actions/1800s per run,30s outer search,9000ms native
   request if unchanged,21600s session,guarded30s inactivity,1GiB observation cap;
   retain any stricter bounds. No hidden replacement starts, retries or rollover.
4. Keep settings/policy/recipe fixed; record any intervention as a separate stratum.
   Preserve failures and duplicates. Return once it ends; no Codex polling while playing.

## External research and validation

[SOURCES](SOURCES.md) records Reddit, community wiki access limits, original written
Gold-Stake strategy, local mechanics verification and predictions. Eight targeted
searches exhausted the search allowance; research stopped. No video was reviewed.
Installed base source reports1.0.1o-FULL; preserved `card.lua` exactly matches the
installed archive. Perkeo random-pool and Observatory x1.5 rules were checked by
read-only source inspection, never source execution. Mod-loaded overrides beyond
the frozen advisor dependencies are not exhaustively attested by these logs.

Analysis used the existing compact journal reader/converter and small passive scripts.
No full unchanged regression was rerun, no gameplay policy was changed/installed,
no game/save/profile was accessed through execution, and no experiment was launched.
Analysis command errors are retained in `analysis_errors.md`; none change outcomes.
Final extraction integrity checks and research accounting are in `audit_checks.json`.
