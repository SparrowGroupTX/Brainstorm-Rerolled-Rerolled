# Completed cohort audit407 — loaded label 2.195

2026-09-26. **Four verified wins, four verified losses, and two nonterminal
unsupported retirements across all ten starts.** Both retirements were Amber
Acorn. This is observed cohort performance, not a population win-rate estimate,
a causal comparison with the preceding cohort, or evidence that changing the
identified decisions would have produced six more wins.

The audit found five high-priority mechanisms, counting the two Acorn failures
separately: lost shop-plan continuity after selling Yorick; missing Acorn Green
Joker state updates; missed Acorn Misprint conservative scoring and subsequent
ability continuity; free Planet upgrades rejected by a purchase-style penalty;
and positive acquisition/copying value for owned Fools the policy cannot use.
Additional valuation, spending, budget, and discard questions remain hypotheses.
**None of these runtime defects was repaired or installed in this audit.**

## Evidence and scope

The user explicitly reported this session complete. Preserved25 segments from
`session-20260926T185618Z-1`,55,053,709 bytes,22,817 continuous verified events.
Frame/event hashes and supplied cross-segment predecessor links pass; explicit
public run instances bind starts, decisions and endings. All ten starts ended
in the journal, followed by `session_stopped(reason=run_limit)` at22816 and
teacher closure22817. That establishes collection completion, not normal game
exit. Balatro PID52460 was still present at the audit's initial passive check.

All1,929 policy requests link to a current recorded advice, the same public
observation/run, an identical selected action, callback and settlement marker.
Markers are linkage evidence; physical later observations and terminal callbacks
are separately checked for the findings. No executor/advice mismatch appeared.
The eleven other request rows are lifecycle requests, not policy decisions.

Every recorded run reports `Brainstorm v2.195.0-alpha`, teacher profile
`perkeo_yorick_win_v1`. Repository and installed files are separately bound to
checkpoint404. A logged version is not exact attestation of loaded process bytes.
No game control, save/profile access, captured-state policy/scorer replay,
original-game execution, native search, experiment, training or automation was
performed. Only public-log analysis, source reading, and invented fixtures ran.

Full denominators and compact per-run chains: [RUN_TIMELINES.md](RUN_TIMELINES.md).
All copy/Invisible, Buffoon and Death offers, and all Joker-pack decisions:
[OPPORTUNITIES.md](OPPORTUNITIES.md). Full linked data remain in `analysis/`,
`deep2/`, `catalog/`, `followup/`, `late/`, and read-only-use `events.sqlite3`.
`capture/verification.json` binds event anchors to original segment/hash evidence.

## Confirmed or source-supported defects

### 1. Yorick was sold for a plan the next decision abandoned — WR-055

Run7's delayed chain is particularly damaging:

| Sequence | Recorded action | Cash and consequence |
|---|---|---|
|14026|Cash out|$4→$9; original Perkeo/Yorick row|
|14036 /14047|Open Buffoon / choose Ride the Bus|$9→$5; conditional growing Mult added|
|14059 /14069|Open Celestial / skip all three Planets|$5→$1; no permanent level acquired|
|14081|Sell Yorick|$1→$11; stated plan: buy Fortune Teller($6), then Ice Cream($1)|
|14091|Redeem Telescope|$11→$1; neither planned Joker bought|
|14102|Leave shop|Only Perkeo and Ride the Bus remain|
|15657 /15660|Final score / loss|Ante5 Big Blind34,861/37,500; no Yorick recovered|

The sale recommendation compared a multi-action endpoint, projecting opening
134→459 in four composition samples. The published physical action contained
only `sell`, without structured `action.followup`. After the sale, fresh advice
preferred the voucher. `shop_sequences.lua:264–276` declines sequence comparison
when the incumbent is a voucher or pack action. Its internal `shop_sequence`
continuation is not a binding execution contract or a complete public receipt.
The later purchase was legal, but abandoned the benefit used to justify the
irreversible engine sale. The run survived Goad, then lost much later; that
does not establish that retaining Yorick would have won.

There is also an admission asymmetry: `shop_sequences.lua:85` consults shared
Joker admission only for Madness, while its sale transition permits Yorick and
its endpoint stage uses a different guard. A manufactured injected veto proves
this plumbing gap. It does NOT prove the existing perishable-only404 guard
would reject Ice Cream, which is depleting but not a Perishable sticker here.
A proper repair must compare a complete, funded, retained-row plan with a
common horizon and revalidate its continuation before committing the sale.
Blindly following an old plan or universally banning engine sales is unsafe.

### 2. Acorn invalidates Green Joker after a completed play — WR-054

Run2: boss entry5724 → valid120-world public belief5731 → play5736 → rendered
`+11 Mult`5743 /`X5 Mult`5745 → completed public play5747 → observation5751,
91,840/400,000 chips,3 hands and3 discards left. The belief still contains10
consistent worlds but explicitly invalidates its values: “This Joker has
unqualified changes during public actions.” Advice5752 stops before any scoring;
retirement5755 is explicitly nonterminal.

`scoring.lua:290` knows Green's before-play increment, but `acorn_belief.lua`
does not admit/update this ability through `advance_public`. An invented
two-Joker test admits the first comparison and rejects the next after a
completed play. The actual popup arrives before the completion update: adding
a stale Mult10 signature for a rendered+11 would introduce a second bug.
Growth belongs to the physical Joker once, including when Blueprint copies it.

### 3. Acorn misses Misprint's existing conservative floor — WR-054

Run5: visible row11005 → Acorn entry11011 → valid120-world inventory11020,
0/400,000 chips,4 hands and3 discards → rejection after exactly one scoring
evaluation11021 → nonterminal retirement11024. The remembered row contains
Misprint, Blackboard, Brainstorm, Perkeo and Yorick; the visible hand has no Lucky
card. `acorn_ordering.lua:51` activates `scoring.lower_bound` only for Lucky.
Ordinary Misprint scoring is uncertain, whereas the existing lower bound
supports canonical Misprint's minimum. The invented positive/negative controls
reproduce the Lucky-dependent admission. The journal does not retain the first
internal warning: Misprint is a source-supported sufficient cause, not a
captured warning string.

Merely enabling this floor is insufficient: both Misprint and Blackboard also
lack post-action ability admission, and would invalidate later. Tests reproduce
those continuity gaps too. Keep custom/unknown effects, incomplete worlds,
stale epochs and incomplete public actions rejected. Neither retired position
is a verified loss or proven recoverable win. Controller receipts5753/11022
still have `pending_action`; public physical effects independently substantiate
the observed completion, rather than assuming that field was cleared.

### 4. Already-paid Planet upgrades can be rejected as if they were purchases — WR-056

Ten recorded Celestial decisions skipped every offered Planet with complete
comparison receipts and negative utilities:3800,4242,4339,14069,16000,16256,
16598,16621,19279,20058. This is a replicated signature, not ten independently
proved avoidable losses. At14069, Uranus improves the recorded opening mean
134.25→193.5, yet receives-11. Jupiter also receives-11 and Venus-9.418. The
already-paid pack is discarded immediately before the Yorick sale above.

Source chain: off-plan Perkeo filler value3 → immediate pack use inherits that
value (`strategy.lua:1038`) → `best_pack_choice` adds generic shop adjustment →
`shop_scoring.lua:1046` subtracts14 even when complete finish progress is equal
and capped → every candidate falls below skip. Permanent development and an
immediate free choice have been conflated with buying weak copy stock.

The invented production-module fixture projects Uranus level1→2 with unchanged
cash/empty inventory. The real scorer's opening mean rises76→174; both complete
bounded policies already clear a target40, yielding adjustment-14 and `skip_pack`.
Eight diagnostic checks pass. A first attempt without the finishing dependency
chose the Planet; it is preserved as a useful discriminating negative control.
Repair the cost/objective at the correct layer. Preserve real costs, capacity,
Fool history, Observatory, hand-specific effects and other contextual tradeoffs;
do not implement “take every consumable.” No full-run rescue is claimed.

### 5. Perkeo accumulates Fools the owned-use planner cannot use — WR-057

Run3 buys an ordinary Fool at6735 for$3 with a known last-used Mercury and free
capacity. The copying pool then contains3 Fools at6889,5 at7004,7 at7124,9 at7254,
and **11 Fools plus a Devil at7406**, before the Flint loss98,890/120,000.
There is no owned Fool use in this run. Hand advice repeatedly discloses it as
unsupported. The final Pair/High Card/Three of a Kind levels remain only2.

`pack_scoring.lua:156` requires zero Jokers for its narrowly admitted owned-Fool
projection, as well as one ordinary Fool, free capacity, an appropriate played
Planet and complete metadata. Adding Perkeo removes admission even in the
simple positive-control case, while acquisition utility remains positive.
Negative duplicates and later larger inventories add further boundaries. The
short-shop graph also rejects more than four held consumables. A separate,
narrow hand-phase Fool/Jupiter route already exists in `consumables.lua:403/454`;
this finding concerns the observed non-Jupiter stock and generic shop helper,
not universal absence of Fool support. This is a capability/value mismatch,
not proof that all eleven Fools were legally usable
at every observation or that using them would win. Purchase/copy value should
reflect supported executable use, with a bounded extension if justified.

## Suspect decisions requiring additional evidence

* **Invisible Joker, especially run6:** three offers, none acquired. Run1's
  price$8 exceeded cash$5. Run2's Rental Invisible cost$1 with cash$100, but a
  full engine row: Green replacements lost sampled finishing support; other
  replacements were protected/unsupported or negative merit. Run6 could afford
  an$8 Invisible after buying Telescope and Celestial, with$20 left and a full
  row; replacing Bootstraps retained four opening clears but received strongly
  negative utility. Source starts Invisible at a flat30 and models the present
  dead slot, not a complete delayed duplicate-and-resale plan. This deserves
  time-to-maturity/target-pool/rental/slot valuation, not automatic purchase.
  Passing it in a winning run neither proves correctness nor an avoidable loss.
* **Joker-pack utility can disagree with survival proxies:** run4 chooses Zany
  at7699 (utility60.75, opening57.5) over Perishable plain Joker (45.88,173.25),
  then loses Head478/600. Trip/full-house history and permanence favor Zany;
  immediate reliability favors+4. Complete per-world rejected finishing values
  are not retained, so this is not proved domination. Similar rank disagreements
  occur at11189,11584 and16112. Current screening only checks the same merit
  function that made the choice; it cannot expose a bad merit function.
* **Spending when the predicted blind is unsafe:** run3 leaves before Flint
  with$21 although both complete bounded policies fall short in every sample;
  reroll is rejected by safe-baseline admission/cash floors. Run9 leaves before
  Plant with$61, a face-dependent Triboulet row and unresolved finishing.
  Reroll's catalog opportunity mass0.00048 is below its0.005 threshold.36 actual
  rerolls elsewhere refute “never rerolls.” Neither a future useful offer nor a
  winning draw is known. This is a survival-versus-reserve arbitration question,
  not evidence to spend all cash. Run7's$2 final shop has a different constraint.
* **Affordable Buffoon passes:**26 of54 opened, all26 reveals confirmed. Of28
  unopened,20 were directly affordable at last exposure, ten of those without
  Blueprint (some already owned Brainstorm). Inadequate surviving reserve and
  row/engine costs matter. These are opportunity flags, not ten known hidden
  Blueprints. Opening every pack would also conflict with funding future copies.
* **Budget/support gaps:**172 decision receipts explicitly report truncated
  shop work, not merely the five decisions that exactly reach a phase cap.
 93 recorded advices disclose incomplete pack comparisons and strategic fallback.
  Incomplete families are not evidence that rejected alternatives were worse.
  One Joker choice(11739) has no complete comparable receipt. Retain early
  completed evidence and record failed families/remaining leases before tuning
  any values; existing caps remain binding.

## Discards, Death, Glass and scoring

The unchanged406 screen flagged **200 discards of fewer than five cards** and
**82 round clears with unused discards**, covering348 discard actions and174
confirmed clears. Those counts are all retained, not an arbitrary top-ten sample.
[SCREEN_ADJUDICATION.md](SCREEN_ADJUDICATION.md) separates observable situations.
For short discards,65 receipts compared five-card alternatives with none qualified,
123 lacked growth-comparison receipts, and12 had no watched growth Joker. For
unused clears,27 have explicit conservative guards,40 lack complete rejection
utilities,3 have no growth receipt,8 no watched growth Joker, and4 are final-boss
clears with no later normal-run growth. This is not proof that200 or82 mistakes
occurred. Tactical hand preservation, Green penalties, held effects, final-boss
completion, rewards and safe future growth must be compared together.

All **five Blueprint and four Brainstorm offers were acquired** in this cohort.
This is encouraging observed acquisition coverage, not proof of optimal funding
or that all possible future copies were reached. Of six visible Death offers,
two were in the mandatory Soul opening; the other passes chose Temperance and
Hermit. Both actual Death uses have confirmed physical transformations:
Glass8 Spades copied over a plain5 Hearts(5692), and a plain Ace Spades over a
Queen Diamonds(14946). The latter run had Ride the Bus; face avoidance explains
why an Ace can beat the user's ordinary Queen preference. All visible alternatives
are preserved. Neither hand offered a stronger enhanced/sealed card. Neither
Death was held in hand phase:862 fishing receipts say `no_held_death`. Consequently
this cohort does not test discard-before-owned-Death fishing adequacy. Revealed
pack Death cannot be fished by an ordinary hand discard.

Twelve plays exposed16 non-debuffed Glass cards. No selected Glass ID disappeared
at the checked later physical observations, and no displayed non-Glass alternative
crossed the conservative105% remaining-target screen. This checks reported
alternatives only; it does not establish optimal Glass conservation.

Sixteen displayed play estimates differ from later stable chip deltas beyond
the audit tolerance; all16 disclose randomness/uncertainty. Fourteen are in
Misprint run5; two are Lucky-exposed run9. No newly certified exact-score mismatch
was established. Run9's eleven Chariot uses also do not substantiate knowingly
putting Steel on faces after Plant was public: its four Ante4 targets were
4H,AH,7S,5H. Three earlier Steel faces were made before Plant was revealed.

## Make future issue detection less self-referential

The existing screen correctly exposes the requested discard events but returned
no flags for the severe shop-plan failure or the free Planet skips. Add separate
review rules for: a strategic engine sold without a physically realized funded
continuation; free permanent upgrades skipped under negative purchase adjustment;
positive copy value for unsupported owned-use paths; predicted blind shortfall
with spendable resources; Invisible maturity/target quality; and conflicting
survival, lifetime and heuristic rankings. Log component utilities and complete
rejected outcomes, not only the final weighted score. Label support gaps separately
from bad choices. A classifier agreeing with the policy's own objective cannot
validate that objective.

Use causal chains as in run7: earliest actionable fork → committed resource
loss → later policy deviation → lost scaling/options → terminal constraint.
An outcome is an attribution anchor, not a reason to call every preceding action
wrong. Manufactured discriminating fixtures and fresh user-started loaded play
must test repairs. [REPAIR_SPEC.md](REPAIR_SPEC.md) gives bounded acceptance and
release requirements; existing closed-experiment and preservation limits remain.

## Verification and delivery

Two invented production-module diagnostic fixtures pass29 checks in total. They reproduce current
limitations, rather than asserting repaired behavior. The pack fixture consumes
1,760 real pure-score calls; no captured states are scored. These use selected
production dependencies, not full `D.run`/controller integration. The one substantive
read-only review and one focused recheck are recorded in `REVIEW.md`.
Analysis correction: initial `deep/` checked post-pack Death only in `hand`;
authoritative `deep2/` checks the surviving owned playing-card population and
confirms both uses. Both attempts and the diagnostic setup failure are preserved.

`FINAL_VERIFICATION.json` binds unchanged109 runtime dependencies, installed
deployment, native DLLs, prior tests/helpers, raw capture and this delivery's
artifacts/commands. Checkpoint404's269 Lua/406 Python runtime gates and406's452
Python tooling gate remain historical evidence for unchanged bytes; they were
not unnecessarily rerun. Runtime/install remain2.195. No new runtime freeze or
release is pending, and latest-session normal exit is unconfirmed.
