# Preserved public cohort audit — 2026-09-25

This is a diagnosis of **eight auditable starts**, not a ten-start census. The
user reported the `session-20260925T190519Z-1` sprint completed, but its last
five journal segments (`000021`–`000025`) disappeared when a new user-started
session cleared the active auto-run log. The user confirmed there is no saved
copy. Do not reconstruct their outcomes or combine the new session with this
one. Original segments 1–7 and 8–20, byte hashes and capture cutoffs remain in
`development387/logs1`, `development388/logs1` and their `capture/manifest.json`
files. `audit_preserved.py` verified 20 segment hashes, 18,531 consecutive
public events, and all 1,667 linked auto-run requests against public
observations/advice/callback records. There are eight distinct observed start
seeds and a ninth completed search without a ninth start before the cutoff.

All 2,740 preserved teacher observations identify win-first
`perkeo_yorick_win_v1`; public product stamps identify loaded label
`Brainstorm v2.184.0-alpha`. They do not attest exact process bytes. Installed
receipt `SESSION_RESET_386.json` verifies 2.184 on disk. The repository now
contains an **uninstalled** frozen 2.189 candidate; neither it nor intermediate
2.185–2.188 participated in these games. The newer user-started batch remains
untouched and its version/outcomes have not been inspected here.

| Start | Recorded outcome | Last public position | Material earlier trajectory |
| --- | --- | --- | --- |
| 1 | Win | Ante 8 Crimson Heart, 473,184 / 400,000 | Yorick x6, Rental Brainstorm, Death stock; cash $90. |
| 2 | Loss | Ante 6 The Mark, 93,546 / 120,000; four discards left | Yorick x8, Trio/Sly/Shoot the Moon; face-down future cards excluded the ordinary prospective-discard branch. |
| 3 | Unsupported stop | Ante 8 Amber Acorn, 339,619 / 400,000; three hands and three discards left | Complete initial six-Joker public belief; after one play, advice became unavailable. |
| 4 | Loss | Ante 2 Small, 894 / 1,000 | Saturn acquired as a supposedly primary Straight source; next shop spent $10 on Grabber over visible scoring Jokers, then had $1. |
| 5 | Win | Ante 8 Verdant Leaf, 477,000 / 400,000 | Yorick x8 with Blueprint; Death development, cash $98. |
| 6 | Win | Ante 8 Verdant Leaf, 503,010 / 400,000 | Yorick x9 with Eternal Blueprint/Duo; cash $187. |
| 7 | Loss | Ante 5 The Flint, 25,715 / 50,000 | Early Rental Ramen and weak economy, expired perishable Bull replaced by Popcorn, then Hanged Man was used twice toward an incidental Straight plan. |
| 8 | Unsupported stop | Ante 8 Amber Acorn, 253,687 / 400,000; three hands and three discards left | Complete initial five-Joker public belief; after one play, advice became unavailable. |

Operational yield among preserved starts is **3 wins / 8 starts**. The three
verified losses and two unsupported stops are separate outcomes; 3/6 among
terminal win/loss records is not a cohort win rate. Missing starts 9–10 are
unknown. Selected searched starts are not an independent population sample.
No alternative action was replayed through a captured policy or game state.

## Evidence-ranked clusters

1. **Two identical Amber Acorn hard stops (starts 3 and 8).** First hidden-row
   observations at sequence 8210 and 18494 followed complete 720/120-world
   initial belief comparisons. After requested plays at 8218 and 18501, the
   completed public events ended at 8231 and 18516. Subsequent advice at
   8235 and 18520 had zero evaluations and said public Joker-order advice was
   unavailable; unsupported retirement followed at 8236–8238 and 18521–18523.
   `analysis/acorn_abilities.jsonl` retains only the last public *pre-shuffle*
   ability fields: Mystic Summit/Popcorn in start 3 and Blue/Golden Joker in
   start 8. Installed `acorn_belief.lua:advance_public` invalidated otherwise
   complete worlds because those exact stable public effects were neither
   own-signature nor qualified opaque abilities. `tests/advisor_acorn_belief.lua`
   now covers exact payloads, public play/discard continuation, 720/120 complete
   worlds, bounded advice, and mutation invalidation. This is a reproduced
   source-level hard-stop correction, not proof either run would win.

2. **Early shop comparison mixed unlike valuations (start 4).** At public shop
   observation 8482, cash was $11 and visible choices included $10 Grabber,
   $3 Jolly and $4 perishable Abstract. Advice 8485/request 8488 redeemed
   Grabber, leaving $1 and no scoring Joker; the next blind fell 106 chips
   short. Static voucher merit had not undergone the paired next-blind
   comparison applied to known Jokers. The correction projects actual paid
   cash and the exact standard +1-hand voucher endpoint, then gives eligible
   early win-first Grabber/Nacho the same bounded shop comparison. The
   `blind_finishing.lua` horizon extends from four to five hands only; a sixth
   remains unsupported. An independent manufactured shop selects Abstract
   over Grabber under its specified conditions. The captured alternative's
   score and terminal result remain unknown.

3. **One played Straight was mistaken for durable development (starts 4, 7).**
   At advice/request 8367/8370, only one Straight and one Flush had been
   played at level one. The tie-breaking `favored_hand` labeled Straight
   primary, contributing to a Saturn purchase; two Saturns remained at the
   Ante 2 loss. In start 7, advice/requests 15103/15106 and 15114/15117
   used Hanged Man twice with three discards left, explicitly saying it
   developed Straight; the hand had six Straight plays/level three versus
   two Full Houses. This does not prove either removal caused the Ante 5
   loss. The corrected win-first preference discounts early unsupported
   Straight, Straight Flush and Flush histories until at least eight plays or
   level four; actual supporting Jokers can overcome the prior. Mature
   Flush/Jupiter stock remains valid. It changes plan labeling and stock
   valuation, not legal or tactical hand scoring.

4. **Earlier survival planning still has unsupported branches.** Start 2's
   Mark used three Pair plays (requests 5031/5043/5054) before a five-card
   discard at 5065; `search.lua` excludes prospective identity-based redraw
   when the public future hand contains concealed cards. This may leave useful
   growth unused, but the hidden identities and next draws cannot be filled in
   from later events. Start 7's Rental Ramen at 14182 cost $1 but kept a
   $3-per-round charge; the visible competing offer was Eternal Rental
   Wrathful and a Standard Pack, not a demonstrated superior durable Joker.
   The later Bull sale at 14930 was an expired perishable replacement, so it
   is not evidence that the system casually traded a healthy Bull for Popcorn.
   A broader held-consumable/discard continuation is still needed; no unsafe
   growth or unsupported mechanic was forced by this candidate.

5. **Large late cash and incomplete stock use are real observations, with
   attribution limited by version.** There were 59 shop-leave requests with
   at least $50; start 6 won with $187, while start 8 reached $121 but then
   stopped unsupported. Death stock reached six or seven in wins; this shows
   that some unused copies coexist with a win, not that all copies were
   valueless. The uninstalled 2.186 late-surplus and 2.187 Perkeo-filler
   changes have no live evidence in this 2.184 cohort. Compare their separate
   admission receipts after activation, not the old observations against the
   new code's asserted behavior.

6. **Score forecasts were appropriately uncertain, not a deterministic
   scorer failure.** Of 64 consecutive same-blind numeric `Play (~score)`
   recommendations with a next public score, 55 matched exactly. All nine
   overestimates selected one or two Lucky cards, whose advice lines explicitly
   warned that random effects use averages; all 53 comparisons without a
   selected Lucky card matched exactly. Two Lucky-selected comparisons also
   matched. `play_score_arithmetic.py` and `annotate_score_chance.py` retain
   the exact anchors and classification. Individual Lucky rolls are not
   recovered from the score difference.

Across the eight starts there were 303 discard requests, 179 with fewer than
five cards, and 85 plays with discards left. These are *inspection counts*,
not 264 proven mistakes. Among recorded requested hand decisions, median
work was 39,742 evaluations, 95th percentile 136,344, and only two reached
the unchanged 140,000 cap. Shop work reached 50,000 once in 432 recorded
shop decisions. `analysis/budget.json` contains the phase breakdown.

## Code and validation

The durable candidate is `runs/hand391_verified_candidate/`, version
2.189.0-alpha, policy digest
`03266454ae9cf9aeb1d6260dc295fba2adc824f7670be8167562eae8ba96696a`.
It incorporates the older uninstalled 2.185 Yorick, 2.186 surplus cash and
2.187 Perkeo-filler work, plus the Acorn, early voucher and hand-plan changes
above. The corrected frozen candidate passed **258/258 Lua fixtures and
392 Python tests**, unchanged frozen policy/test hashes. Previous 2.188
candidate also passed (257/257 and 392). The first 2.189 gate failed the
historical mature Flush/Jupiter fixture; the narrowed correction passed the
targeted old/new fixtures and full verified gate. Both intermediate gates
remain preserved. No candidate was installed into the active game, no native
binary changed, and no game/search/training experiment was run by tools.
