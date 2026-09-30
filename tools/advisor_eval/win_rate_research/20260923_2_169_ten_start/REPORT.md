# Loaded 2.169 win-first ten-start cohort — 2026-09-23

The user-started `session-20260923T155327Z-1` is frozen through
**2026-09-23T16:36:58Z / sequence 17189**. Its 25 unchanged public journal
segments, SHA256 manifest, action-linked event index and compact extracts are
under [`capture`](capture), `actions.json`, `runs.json`, `rounds.json`,
`deep_dive.json`, `copy_opportunities.json`, `deep_summary.json`, and
`arithmetic.json`. `checkpoint.json` verifies the 105 installed 2.169
runtime/dependency hashes and the distinct, still-uninstalled 106-file 2.170
repository candidate at audit time. Original journals were left untouched. No
captured state was sent to the policy or scorer, and no game or hidden search
was run by tools.

All 15,563 public version stamps say `Brainstorm v2.169.0-alpha`; all 2,696
public state snapshots select `perkeo_yorick_win_v1`, with
`collection_progress` present and `completionist_goal` absent. These fields
support a *loaded 2.169 win-first profile*, not exact loaded-byte identity.
The installed 2.169 receipt and hashes are separate evidence. Search recorded
ten distinct seeds, none shared with the prior audited 2.168 cohort. Each
found the normal conditional Charm route and produced the searched Yorick +
Perkeo opening on Red Deck Gold Stake; there was no assumed first-Small Charm
Tag. Ten starts and ten terminal outcomes are contiguous in the journal.
The converter reports 1,625 requests and callbacks, 1,603 first settled
observations, zero missing callbacks or accepted callbacks without a settled
observation. The 1,603 `auto_run` actions carry gameplay payloads. Another 22
`player_callback` records have empty `{}` payloads; they do not establish a
strategic manual override. Callback/first settled observation alone cannot
prove completion of every queued effect.

## Operational outcomes

| Start | Seed | Outcome | Last blind, chips / target | Yorick | Copy Joker |
|---:|---|---|---|---:|---|
| 1 | 9DFG94RV | loss | A3 Mouth, 4,464 / 6,400 | x4 | none |
| 2 | IPA357RV | loss | A4 Eye, 15,042 / 18,000 | x3 | none |
| 3 | AQVK4CRV | loss | A8 Crimson Heart, 149,606 / 400,000 | x6 | Blueprint A4 |
| 4 | 7G1L9DRV | loss | A4 Wheel, 12,570 / 18,000 | x3 | none; Perkeo sold A2 |
| 5 | SRXCSJRV | loss | A4 Big, 11,625 / 13,500 | x5 | Blueprint offered A2, not bought |
| 6 | 9ASFTORV | loss | A3 Hook, 4,058 / 6,400 | x1 | none; Burglar bought A1 |
| 7 | PH925QRV | win | A8 Cerulean Bell, 1,117,800 / 400,000 | x6 | Blueprint A1 |
| 8 | C7CCDZRV | loss | A8 Violet Vessel, 826,112 / 1,200,000 | x8 | Brainstorm A3 |
| 9 | ZP18Y3SV | loss | A6 Eye, 72,450 / 120,000 | x5 | none |
| 10 | 2BEQS9SV | win | A8 Violet Vessel, 1,315,392 / 1,200,000 | x8 | Brainstorm A2 |

Operational yield: **2 wins / 10 starts; eight verified losses; zero
error, unsupported, timeout, stall, abandoned or user-interrupted starts**.
The win-first profile still logged collection progress: run 7 earned one
confirmed new Gold sticker (`j_shortcut`), run 10 earned zero. This is a small
selected diagnostic cohort, not a population win-rate estimate, independent
seed sample, or controlled before/after test. The prior loaded-2.168 selected
cohort had five wins/ten starts on different seeds; that difference cannot
identify a 2.169 regression or benefit.

## Ranked causal clusters and contrasts

**1. Durable scoring-engine acquisition has a concrete coverage gap.** Four
runs bought a visible Blueprint/Brainstorm; two won and two reached Ante 8
before losing. Six losses acquired no copy Joker. The public shop record shows
six copy offers: four purchases, an unaffordable A3 Brainstorm in run 4, and
an A2 Blueprint in run 5 at observation/action **5617**. Run 5 had $9, a
$10 ordinary Blueprint, and only four of five Joker slots occupied. Its
non-Eternal Ice Cream had a $2 sale value; sell then buy was legal on visible
cash/slot arithmetic. Advice 5617 instead left the shop, and
`strategy.lua:1359-1362` returns from `replacement_sale_plan` whenever the
row is not full. Direct purchase was unaffordable, so the legal sale-funded
copy endpoint received no comparison. That is a high-confidence *admission
gap*, not proof that Blueprint would have saved run 5: the run later lost A4
Big by 1,875 chips, and we have not evaluated the counterfactual row or
unknown draws. Run 4's A3 Brainstorm at 4928 cost $10 with $6 and a full row;
the visible $2 sale options alone did not close the $4 gap. It is a contrast,
not a second instance of the same legal one-sale opportunity. The run 5
anchor is `...-000011.brj` ordinal 246, raw SHA256
`4b39123ec36dd027ab558e4b94571cb3327a7c8ac267f1c800e098170ee6db40`.

Across **147 shop exits there were zero paid rerolls**, including the no-copy
run 9's late exits with $21–53 cash. `strategy.lua:1603-1665` reaches paid
reroll only after no chosen purchase and current-blind weakness;
`paid_reroll.lua:322-348` vetoes a `sampled_safe` next blind. This establishes
missing proactive engine-procurement coverage, not that paying for unseen
offers would have produced a copy Joker or a win. The next comparison should
price a bounded reroll as an option against cash/interest, available Joker
slots, search horizon and survival, while preserving all existing budget and
known-mechanics gates. Its cheapest falsifier is a manufactured shop where
the current blind is safe but the future engine is demonstrably short,
followed by one where interest or imminent survival makes reroll inferior.

**2. A known Joker trade can sacrifice Yorick's future investment.** In run
6, Buffoon choice **6651** selected Burglar over Mail-in Rebate. The advice
acknowledged discards would be removed and favored extra hands for the next
Head. `strategy.lua:383-391` gives Burglar a fixed high rating;
`blind_start.lua:132-170` correctly applies zero discards. After that
choice, all seven subsequent blinds began with zero discards, so Yorick
remained x1 through A3 Hook. Its final seven hands totaled only 4,058/6,400.
This is an observed short-horizon versus growth trade: the alternative
Mail-in Rebate, earlier uncertain clear chances, and future hand draws are
not certified to win. The code needs an explicit Yorick/Burnt horizon debit
when a candidate permanently erases discard opportunities, with current
blind paired survival still able to override it. The exact action is
`...-000013.brj` ordinal 153, SHA256
`6d9bedfc5c800eba5b65301a1a674717540fb743f2e017fca343ab10f2dcd06d`.

Run 4 shows a different row-horizon trade. At action **4707**, with $0 and
a full row, the advisor sold Perkeo for $10 to buy temporary Ice Cream for
$5. Four uncertain paired opening worlds improved from 746 to 2,286 against
the next Big target 1,500. The trade helped the immediate public comparison
but removed Perkeo's option to copy future stock; the run then lost A4 Wheel.
`strategy.lua:1301-1458` counts held inventory at replacement endpoints,
but when inventory is empty it cannot value a future useful copy pool. The
receipt justifies a real survival concern, so calling the trade simply wrong
would exceed the evidence. The narrower finding is an unpriced future option
in a temporary-Joker trade. Action anchor: `...-000009.brj` ordinal 312,
SHA256 `70ae1cf6a10b8968115fc17cfc50f317c3174267c67de0c1834978d0b39bdd34`.

**3. Late scoring ceiling and consumable fit remain uneven.** Run 3 bought
Blueprint A4 and made A8 Big 365,904/300,000, but Crimson Heart debuffed
Blueprint on the first hand and Yorick on two later hands; its four final
plays scored 61,344, 346, 80,352 and 7,564. It used 27 Deaths over the
run and held none at the end. Run 8 bought Brainstorm A3, grew Yorick x8,
and barely passed A8 Big 318,464/300,000, then faced Violet Vessel's 1.2M
target. Its four final hands scored 164,736, 218,624, 397,824 and 44,928.
It used 22 Deaths over the run, five in Ante 8, three in the final blind;
11 Negative Deaths remained after the loss. This is **not** evidence that
all remaining Death copies were ignored. It exposes a scaling/hand-planning
shortfall even with copy and growth, and a possible excess single-type pool.
No captured-state alternative was replayed; the exact useful next consumable
or hand sequence is unknown.

Run 5 offers a more specific pool-quality question: after acquiring Venus
and Mars, it sold some surplus copies but carried last Venus/Mars through
later shop exits without Observatory; Straight reached level 3 and later
Saturn was bought/used. It played one Three of a Kind and one Four of a Kind,
so the held cards were not categorically unusable, but they were not spent
before its A4 loss. The current whole-inventory value can retain last types
for a potential Perkeo copy even when the actual developing hand shifts.
This is a supported opportunity to audit, not a certified beneficial sale
or Planet use. All ten runs had **23 consumable sales**. The stock manager was
active, and run 8's Death use disproves a global “never uses copies” account.

Early growth also remains a discriminating signal. Among **78 cleared
Ante≤3 rounds, 24 kept at least one discard, 52 discards total**. Run 2 kept
13, run 4 kept 14, and run 9 kept eight; runs 3 and 8 spent nearly all early
discards yet still lost late. A retained discard is not a proved safe Yorick
investment. The run 6 Burglar sequence is a narrower, source-backed cause.

## Scoring, execution and coverage checks

Of 280 play actions, 255 have a numeric `~score` title. For 215 with a
same-round before/after chip delta, 196 matched exactly. Eighteen differences
are in run 4's row containing Misprint, whose random Mult makes an exact
single-score forecast inappropriate. The nineteenth, run 7 action **8700**,
was a 27,216 conservative forecast versus 117,936 realized; its advice
explicitly excluded random bonus triggers. Forty numeric-title plays cross a
round boundary in the first settled snapshot and cannot be compared by this
simple subtraction; 25 titles lack a numeric score. The comparable checks
show no broad deterministic scoring/execution mismatch, but are not a full
proof of scorer correctness. See `arithmetic.json` and `diagnostics.py`.

The logged full-row replacement receipts include 27 `budget_incomplete`
and nine `unsupported_family` decisions across repeated evaluations. Some
occur at A8 exits, but the visible offers there do not establish a missed
winning purchase. Missing telemetry or incomplete families are unknown,
not safe holds. Two Hex offers in this cohort were not selected; without
their exact guard receipts that is not proof the 2.169 Hex guard alone
prevented destruction. No game-control hard stop or journal gap appeared.

## Highest-leverage next repair and falsifier

First close the **sale-to-fund-visible-copy comparison** in a shop with a
free Joker slot (WR-010). Keep the full-row replacement path and its
common-world, cash, survival, Perkeo/Yorick protection, unsupported-family and
budget guards. Extend the endpoint family to a one-sale-then-buy path when
visible cost exceeds cash and a publicly sellable Joker makes it affordable,
including a free-slot row. Evaluate the actual post-sale row and preserved
inventory, not a special Blueprint bonus. Record compared/admitted/rejected
receipts and do not execute an uncertain or incomplete family. Manufactured
fixtures should cover the run-5-shaped $9/$10/$2 case, no-sale-needed direct
buy, insufficient sale proceeds, Eternal/unknown protected sale, cash-interest
tradeoff, copied-scoring row, unsupported/budget-incomplete veto, and identical
common worlds. Require targeted fixtures, full frozen candidate and exact-
installed gates, plus release verification for a later authorized repair.
The falsifier is a complete endpoint comparison that still rationally rejects
the legal run-5-shaped trade on supported survival/build merit; that would
demote the opportunity from a missed beneficial decision to a coverage-only
finding. Actual full-run benefit requires a later user-started cohort.

Next investigate proactive reroll valuation (WR-012), Burglar's discard
horizon (WR-011), and pool fit (WR-002) in that order unless new evidence
changes the ranking. This audit changed no gameplay policy, settings or
search recipe. After the cohort ended, the separately validated 2.170
action-lifecycle candidate was installed and exact-installed validated; it is
an architecture change, not an explanation for these 2.169 outcomes or a
demonstrated win-rate gain. Its activation awaits the user's normal restart.
