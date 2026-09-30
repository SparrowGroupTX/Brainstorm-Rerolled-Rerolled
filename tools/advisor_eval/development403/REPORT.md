# Completed ten-run public audit 403

2026-09-26. Implements the prospective `../ANALYSIS_PLAN_403.md` after the
user's completion message. This is a passive analysis and manufactured diagnosis,
not a runtime repair, installation, captured-state replay or new game experiment.

## Outcome and evidence

The session contains **ten starts: five verified wins, four losses and one
nonterminal unsupported stop**. Public observations identify
`Brainstorm v2.194.0-alpha` and `perkeo_yorick_win_v1`. This establishes actual
loaded-label outcomes; it does not attest the process's exact loaded bytes or
establish a stable 50% win rate. Do not exclude the unsupported start from the
denominator or attribute differences from earlier selected cohorts to the patch.

The most actionable findings are a Blueprint sale-to-choice reversal, a Hook
uncertainty rule that hides an invariant clearing Pair, and an Acorn admission
rule that rejects ordinary numeric edition metadata before scoring. A separate
long-horizon weakness is the valuation of temporary copy power against the loss
of permanent engine growth. Death transformations were executed correctly and
include strong sources; adequate source-fishing is still unverified.

`capture/manifest.json` preserves all 28 segments of
`session-20260926T164021Z-1`: 55,462,745 bytes, source/copy hashes and stable reads.
`capture/verification.json` records 24,223 continuous events, no decode failures,
ten starts matched to endings by public run identity, and no unended starts.
Sequence 24222 stops at the ten-run limit; 24223 closes the teacher session.
Balatro was absent at the initial passive process check. That does not establish
normal exit, and the user's earlier confirmation concerned the previous release.

All 2,177 requested policy actions have explicit observation, advice, callback
and settlement-marker links. Another 19 requests are lifecycle inputs without
policy actions. A marker alone is insufficient to prove an effect: every acquired
copy Joker, opened Buffoon pack and Death transformation below was checked in
later public observations. The read-only `events.sqlite3` index retains exact
segment, ordinal, raw event hash and original public JSON for each sequence.

The authoritative derived data are in **`analysis2/`**. The preserved preliminary
`analysis/` accidentally included post-ending menu/loading observations in run
terminal summaries; `ANALYSIS_REVISION.md` documents the correction. No original
capture was modified. `RUN_TIMELINES.md` records resources, purchases, sales,
transformations, blind entries and shop exits for all ten runs.

| Run | Result | Last blind | Final chips / target | Cash | Final observation / ending |
| --- | --- | --- | ---: | ---: | --- |
| 1 | Win | Ante 8 Violet Vessel | 1,207,584 / 1,200,000 | 41 | 3223 / 3225 |
| 2 | Win | Ante 8 Verdant Leaf | 1,063,935 / 400,000 | 49 | 6157 / 6159 |
| 3 | Win | Ante 8 Cerulean Bell | 404,898 / 400,000 | 269 | 9086 / 9088 |
| 4 | Loss | Ante 1 Big | 440 / 450 | 4 | 9232 / 9235 |
| 5 | Loss | Ante 6 Goad | 61,173 / 120,000 | 36 | 11390 / 11393 |
| 6 | Loss | Ante 5 Hook | 42,630 / 50,000 | 29 | 13192 / 13195 |
| 7 | Unsupported | Ante 8 Amber Acorn | 0 / 400,000 | 43 | 16314 / 16320 |
| 8 | Win | Ante 8 Violet Vessel | 1,203,949 / 1,200,000 | 242 | 18976 / 18978 |
| 9 | Loss | Ante 8 Small | 158,503 / 200,000 | 42 | 21320 / 21323 |
| 10 | Win | Ante 8 Crimson Heart | 799,482 / 400,000 | 224 | 24219 / 24221 |

Winning snapshots have advanced to Ante 9 while retaining the completed boss's
chips. Run 7 still has four hands and three discards; it is not a played loss.

## Exhaustive Blueprint and pack audit — WR-050

`OPPORTUNITIES.md` inventories every distinct physical offer. Seven Blueprint
offers produced five acquisitions; four Brainstorm offers produced four
acquisitions. All nine are confirmed in the owned Joker row. The two passed
Blueprints are examined below, including their affordability and admission
limits. **30 of 44 displayed Buffoon packs were opened**, with actual public
reveals confirmed in `analysis2/pack_reveal_checks.json`. Unopened contents are
unknown; they cannot be counted as missed Blueprints.

The 14 skips include seven offers observed while Blueprint was already owned,
one shop where the visible Blueprint was bought directly with all $10, four
early offers with limited liquidity, and two late run-10 offers with a full row
whose non-core Jokers were Eternal. The latter had plenty of cash but lacked
the qualified non-core replacement route. This demonstrates a capacity/engine
tradeoff, not a cash shortage. No blanket instruction to open every pack or
hoard a larger fixed reserve follows from these observations.

### A403-1: Sell for Blueprint, then choose Ramen

Run 9 observation **19906** shows a Jumbo Buffoon pack, one remaining choice,
$57 and five Jokers: Holographic Ice Cream, Supernova, Yorick, Perkeo and Egg.
The pack publicly offers an Eternal Rental Blueprint, Mime, Baseball Card and
Ramen. Action **19912** explicitly sells Egg for $8 **to choose Blueprint**.
Observation **19916** confirms $65, four Jokers and the same pack. Action
**19922** instead chooses Ramen. Blueprint is then gone.

This is a supported planning inconsistency across an irreversible sale and its
fresh continuation. The public facts do not show a new affordability, capacity
or safety restriction explaining the reversal. The sale advice's modeled
endpoint rises from about 10,990 to 65,943; direct Ramen advice rises to about
21,981. These are uncertain estimates, not guaranteed survival comparisons.
The final choice used 11,336 evaluations and was not truncated.

The source contains different objectives: `Brainstorm/Advisor/strategy.lua`
around 3008-3063 ranks full-row replacements by final build value; around
2891-2975 ranks vacant-slot pack choices by card value plus adjustments.
`supported_copy_priority` around 1326-1354 requires complete, non-uncertain
common-world readiness before its overriding preference applies. The focused
copy pass in `decision.lua` around 222 is shop-only. Missing pack-candidate
receipts prevent assigning an exact live post-sale score or rejection reason
to Blueprint. No budget failure or execution failure explains this example.

Repair the shared endpoint comparison and fresh continuation semantics, not
by blindly executing an old follow-up. Public identity, affordability, current
capacity and changed facts must still be revalidated. A manufactured
full-row/vacant-row equivalence test is specified in `REPAIR_SPEC.md`.

### A403-2: Permanent growth sold for copy power that expires before Ante 8

The same run later offers a **five-round Perishable Rental Blueprint** at
**20590**, with $163. After other spending, action **20665** sells Perkeo,
then **20675** buys Blueprint; **20680** confirms ownership. The ordinary
replacement comparison prefers the immediate modeled score after selling
Perkeo (about 297,344) to a non-core alternative (about 252,411). Both are
uncertain; this is not proof the alternative was safe or that Perkeo was useless.

The delayed cost is directly visible: Blueprint's remaining tally falls from
four at **20905**, to three after the Ante 6 boss (**20917**), two after Ante 7
Small, one after Ante 7 Big, and **zero/debuffed at 21134** after the Ante 7 boss.
Run 9 enters Ante 8 Small at **21222** with expired Blueprint and no Perkeo,
then loses at 158,503/200,000. Retaining an expired rental is another cost, but
the intervening sale of an expired Swashbuckler was an equal-gain alternative,
not evidence of an index error.

`strategy.lua` around 1990-2054 protects Perkeo against this trade only when
a same-offer non-core alternative meets immediate readiness/score conditions.
That does not price the whole bridge to known expiry or the lost future copy
production. The known five-round lifetime was available when buying; the exact
future draws and final score were not. Passing the permanent Blueprint earlier,
selling Perkeo later, expiry and final deficit form a real resource chain.
They do **not** prove that buying the earlier Blueprint would preserve the same
future RNG, save this run, or independently add multiple wins.

Run 2 is an essential counterexample: selling Perkeo at **6140** immediately
before a supported final Verdant Leaf clear was appropriate to its horizon.
A blanket ban on selling Perkeo would be a regression.

### A403-3: Run 5's unaffordable shop offer and incomplete fallback

At **10029**, Blueprint costs $10 against $8 cash and a full row. Selling
Reserved Parking for $3 could fund it, leaving $1 with $6 of current rental
obligations. The two $1 rental sales do not individually fund it. This is a
liquidity and survival comparison, not an ordinary affordable purchase.

The focused pass spends 5,263 evaluations and reports no supported priority;
its failed endpoint details are not serialized. Ordinary replacement gives
the Parking replacement mean 50,232, ratio 4 and positive merit 42.16, but its
finishing comparison is **incomplete**, despite supported/all-clear fields.
Ordinary work 41,489 plus focused work gives 46,752 total, with truncation:
an atomic next comparison can fail before the numeric 50,000 cap is reached.
`decision.lua` around 329-351 then recomputes an unscored fallback and action
**10037** leaves. These are confirmed stages; they do not prove that a safe
Blueprint purchase was rejected solely by merit or solely by the budget.

Earlier purchases of Reserved Parking and Rental Popcorn at **9827/9840**
reduce $17 to $10; subsequent $6 rental payments contribute to the thin reserve.
The delayed effect is a reason to investigate rental-horizon planning and
complete bounded funding comparisons. It does not justify waiving debt and
survival guards or claiming unopened packs contained Blueprint.

## A403-4: Hook hides a reliable clear behind global uncertainty — WR-052

Run 6 observation **13176**, advice **13180**, action **13183** (segment 16,
ordinals 1772/1776/1779) show the last hand, no discards and **9,673 remaining**.
The advisor chooses a Lucky King High Card, mean **11,515**, over a Pair,
mean **11,319**. The actual no-trigger play gains **2,303**, ending the run.

This case supports a stronger local conclusion than an ordinary hindsight
comparison. The unselected held cards for the Pair have no effects or seals;
Hook discards only unselected cards. All possible Hook pairs leave the same
scoring state: deck count 16, Yorick x7 with its counter moving 4 to 2,
Blueprint copying that x7, Blue Joker and no applicable Trading Card trigger.
Independent arithmetic is:

* Pair: `(25 + 10 + 10 + 2*16) * 3 * 7 * 7 = 11,319` — clears by 1,646.
* Lucky King with no Mult trigger: `(5 + 10 + 32) * 1 * 7 * 7 = 2,303`.
* Lucky King's mean: `47 * (1 + 20/5) * 49 = 11,515` — not a guaranteed clear.

The Pair therefore clears **this blind**, under every applicable public Hook
discard outcome. It was not executed and this does not establish a full-run win.
No captured state was passed through a scorer to reach this conclusion.

`scoring.lua` around 245 attaches unresolved Hook uncertainty, retained by
`lower_bound` around 576. `search.lua` around 730/779/804 applies a limited
floor check then compares uncertain means; its no-discards return around 1018
precedes sampled continuation. Increasing the floor shortlist alone cannot
remove the blanket Hook uncertainty. The explicit transition around 1057
already distinguishes selected cards; use that semantics conservatively.

An independently manufactured five-card/no-Joker example reproduces the
mechanism: invariant Pair nines scores 56 against target 50, Lucky King has
mean 75/floor 15, and current search chooses the Lucky King. This is a small
diagnostic, not a reconstructed real state or a claim of general Hook coverage.

## A403-5: Acorn rejects normal edition metadata before scoring — WR-053

Run 7 publicly records its row before Acorn, then selects the boss at **16310**.
Observation **16314** has a valid, complete 120-order public Joker belief,
five properly hidden Joker slots, four hands and three discards. A visible
Bonus Seven of Diamonds has edition `{holo=true, mult=10, type="holo"}`.
The initial waiting advice is transient. Fresh advice **16317** says
**Unknown playing-card edition effect**, with **zero evaluations**. Events
**16318-16320** retire the run as unsupported, `actual_terminal=false`.

`acorn_ordering.lua` around 36 admits edition flags/type but rejects numeric
metadata fields. `snapshot.lua` around 44 preserves the full edition table;
`scoring.lua` around 366 supports the ordinary numeric edition fields. Thus
valid source-shaped Holographic metadata fails admission before any play
comparison. This is not missing public order memory, insufficient budget,
failure to wait for readiness, or proof the Acorn scoring logic would win.

Manufactured flag-only versus numeric-metadata Holographic, Foil and Polychrome
cases reproduce the discrepancy. Unknown metadata remains rejected and hidden
identity access is poisoned. Repair requires narrow vanilla equivalence with
malformed/custom effects still guarded, including real snapshot integration.

## Death and persistent development — WR-051

All **23 uses** (18 held, five pack) match the selected source's rank, suit,
enhancement, edition and seal in later public observations. This confirms the
selected transformation and direction, not every underlying ability field or
optimality. Thirteen copy Glass, nine plain cards, one Lucky. Five successive
run-7 copies reproduce **Red-Seal Glass Kings** into weak cards at actions
16024, 16035, 16046, 16165 and 16185. This is actual evidence of strong,
selective copying in the loaded cohort, not merely a passing fixture.

Weak-looking ranks need tactical context: run 1 uses multiple Glass sources
while confronting the 1.2-million Violet Vessel. A lower Glass rank can supply
needed scoring; the user's rank preference cannot replace that comparison.
Run 5 develops a dense six population (13/43 by Ante 6), but has Two Pair level
10 and The Family; its large four-kind burst is followed by weak hands and
defeat at the Goad. Deck density, useful hand levels and repeatable scoring
need to be valued jointly. This is a plausible strategic mismatch, not proof
that any specific six copy was irrational or that a King would have won.

Across 59 hand decisions holding Death, selected actions are 24 consumable
uses (of any type), 13 plays, 12 discards, six Joker reorders and four hand
reorders. There is **no explicit selected stronger-source fishing receipt**.
Audits401/402 establish that rejected/inapplicable fishing and some tactical/
pack comparisons are not fully logged. These counts therefore cannot establish
how often fishing was eligible, considered adequately or missed. Keep that
question open; do not convert a missing receipt into zero value or a proved bug.

## Other trajectories, costs and counterexamples

Run 4 loses the first Big Blind before any shop, by ten chips. Three early
discards retain a Flush and raise modeled immediate value only modestly;
four eventual plays score 296 + 92 + 36 + 16 = 440. This motivates a bounded
multi-hand/discard-reserve hypothesis. No public evidence proves a different
draw or retained hand would clear; this is not a confirmed avoidable loss.

Run 9's Perkeo copies Uranus/Mars; eight Negative copies are sold and no held
Planet is used, while High Card remains level 4. This is an inventory-value
hypothesis, not a demonstrated loss mechanism. Other winning runs build hand
levels and cash successfully, and large cash at the end is not itself evidence
of under-spending. Known future rentals, core expiry, deck density and hand
levels are stronger diagnostic signals than raw cash or best-hand mean alone.

One presentation mismatch at **11056** labels advice "Discard 3 cards" while
its encoded/requested action plays indices 2,3,6,7 and actually scores 65,340.
The executor follows the encoded play. This is an arbitration/presentation
consistency defect, not evidence that it physically discarded a selected play.

There are 2,075 unique completed timing receipts: 910 hand, 578 shop, 200 pack,
202 blind and 185 round. Elapsed p95 is 3.363s hand, 2.646s shop, 2.091s pack;
maximum elapsed shop time is 7.002s. Exactly hitting the numeric cap occurs
once for hand, three times shop, once pack. These counts understate incomplete
atomic comparisons, as run 5 demonstrates. No logged score-cap overrun or
time/action-limit retirement explains the cohort. Increasing global caps is
not an evidence-backed repair for the major failures above.

## Validation, limits and next work

`manufactured_admission_probe.lua` passes **15 diagnostic assertions in one
fixture**, reproducing the current Acorn and Hook gaps. The first attempt
failed because the diagnostic expected the wrong search-result API; its exact
source and log are preserved. The correction changes only that assertion.
`REVIEW.md` records the existing read-only reviewer's substantive Acorn review
and focused Hook recheck. No additional reviewer or recursive work was used.

`prework.json` and `final_verification.json` bind checkpoint400's 109 runtime
dependencies in repository/installation, 305 frozen tests and all seven DLLs
per tree. Runtime remains **2.194**, exact digest
`97711915fc9705a40f7d0c4f2ac04ed5a6de2210c1efdc34f1eadf9226b61980`.
The prior full 265-Lua/392-Python release gates were not redundantly rerun.
No runtime, configuration, installation, save/profile or game control changed.

`REPAIR_SPEC.md` ranks concrete acceptance/falsifier work. Future runtime edits
require a new combined exact freeze and full gates; release still requires
fresh normal-exit confirmation and passive preservation checks. No experiment,
replay, training, automation, loaded rescue or new win-rate claim is authorized
or implied by this completed analysis.
