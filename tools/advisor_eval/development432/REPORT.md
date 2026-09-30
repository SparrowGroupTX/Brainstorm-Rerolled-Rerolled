# Latest ten-run audit432 — loaded2.209, update2.212 installed

The completed session is safely preserved in
`tools/advisor_eval/development430/captures/002`:30,608 verified public events,
ten starts and ten recorded endings: **6 wins,2 losses,2 unsupported retirements**.
The two unsupported runs stopped on Amber Acorn; they were not terminal losses.
This cohort does not establish a population win rate.

**2.212 is now installed**, including428 enhanced-anchor discard proofs,
430 Amber Acorn Smiley/Supernova continuity and431 conditional-held score floors.
Candidate and exact-installed gates both passed302 Lua fixtures and458 Python
tests. Settings, seven DLLs, original journals and earlier work were preserved.
See `SESSION_RESET_431.md/.json` and `development431/INSTALLED_VERIFICATION.json`.
These analyzed runs used2.209; they do not measure2.212 performance.

## 1. Discard coverage remains the first priority

All533 discard requests have matching before/settled resource-counter changes.
They discarded2,101 cards, averaging3.942 cards per discard:

| Cards discarded | Actions |
|---|---:|
|1|49|
|2|39|
|3|88|
|4|75|
|5|282|

**38 cleared rounds left98 discards unused.**35 of those rounds had future blinds,
accounting for89 unused discards; three were final bosses. Unused discards were
far more frequent than the user's desired near-never behavior. A short discard or an
unused resource alone still does not prove that a safe full batch existed.

Recorded final-clear rejection causes:

| Reason class | Rounds |
|---|---:|
|Scoring-card order guard|20|
|Scoring-trigger order guard|4|
|Raised Fist replacement/held-score guard|4|
|Concealed-hand Joker floor qualification|3|
|Visible retained proof unavailable within allowance|3|
|No shortlisted retained discard survived|1|
|Supported random floor below target|1|
|Boss changes finishing conditions|2|

The installed update addresses bounded subsets of the order and conditional-held
classes, not all these events. Remaining rows include Stuntman, Certificate,
Abstract, Bull and Faceless outside current narrow proofs; mixed larger anchors
also remain. Examples:13323 (Certificate/Pair),18938 (Abstract/Pair),25167 (Bull/
Idol/Pair),25757 (Bull/Supernova/larger hand). Each requires qualification of its
actual effects, copies, draw changes and complete order family, not a blanket
whitelist or increased computation cap.

**A separate anchor-selection weakness:** run4 request9942 played a13,536 High
Card against13,500 and left two discards. Six retained candidates failed; Blue
Joker loses chips when replacement draws shrink the deck. The same recorded
advice displayed a32,204 Pair alternative. `growth.select_clear` preferentially
keeps the fewest-card anchor before testing post-draw viability. Once that thin
anchor fails, it does not try a small portfolio of stronger anchors. The displayed
Pair is a lead, not proof of a valid substitute. A manufactured Blue-Joker state
should establish whether a bounded second anchor enables a full discard while
preserving held rewards, score floors and the existing12-call allowance.

**Short-discard diagnostics need more detail:**150 of251 short-discard decisions
recorded comparing at least one five-card candidate; none of those receipts
recorded a qualified five-card candidate.151 recorded24/24 sampled clears for the
reported candidate, but the compact receipt does not establish that this was the
five-card candidate. Search's Yorick preference also returns zero for many enhanced
discarded cards. Record per-size rejection reasons and the relevant resource/floor
comparison, rather than inferring safety from a best-candidate sample count.

## 2. The observed Tarot sequence is real; its earlier cause is admission

There were24 consumable uses followed by14 round clears with no intervening
discard and discards still available. Five uses were Hierophant, eight Empress;
other cases involved Death, Magician, Devil, Justice, Mercury and Hanged Man.

Example: run5 used Hierophant at13296 and13309, then played Pair at13323 with
three discards. Before the second Tarot, the discard proof already reported
automatic-scoring-order rejection, zero qualified risky candidates and a24/24
best sample count. The final play retained that same rejection. Run10's Empress
uses30242/30255 followed by30267 have the corresponding trigger-order rejection.

Conversely, **all43 decisions explicitly deferring optional development for an
admitted discard executed that discard**. There is no confirmed recurrence here
of an accepted discard being silently replaced by optional Tarot. Improving
admission and testing alternate anchors is the useful next step; disabling all
Tarot use would not itself prove a safe discard. See `discard/tarot_chains.json`,
`deferred.json` and `unused.json` for complete causal records.

## 3. Full-row Buffoon exploration stops after the first Blueprint

Run2 observation2995 showed$38, a$3 Buffoon pack, and six occupied Joker slots.
The row already had Blueprint but still had replaceable Greedy/Hiker slots.
`seeking_blueprint` returns false whenever Blueprint is owned, and the ordinary
Buffoon branch then assigns zero value to a full row. This excludes further
Blueprint/Brainstorm exploration before reveal.

Advice2998 declined the pack, considered a$6 reroll and recorded
`no_affordable_spend_above_buffer`. Request3001 left; callback3002, blind3005 and
settlement3007 confirm departure. The pack itself could have preserved$35.
This is independent of the shop's separate truncated comparison.

**Next fixture:** an owned Blueprint, full row, replaceable noncore Joker and
affordable Buffoon. Value further copy exploration while keeping the purchase/
rental reserve; sell only after a valuable public reveal. Do not assume pack
contents or sell an engine merely to open a pack.26 of51 distinct Buffoon offers
were opened in this cohort; all26 have verified reveals. The other25 are not all
automatically errors.

## 4. Cash targets currently act as retained floors

**66 of190 shop exits retained cash above the requested stage target.** Every one
recorded `no_affordable_spend_above_buffer`. `late_cash_spend` requires the entire
action cost to fit above `max(stage target, mandatory reserve)`. Thus$42 with an
$8 reroll leaves the shop because$34 would fall below$35; likewise$29 with a$7
reroll cannot cross$25. These are retained-minimum semantics, not a rule to spend
until the balance reaches or crosses the target.

**Next change to test:** distinguish a preferred spend-down target from mandatory
rental/discard/survival cash. A single affordable worthwhile purchase/refresh may
cross the preferred target, then reassess. Preserve the prohibition on sacrificing
a necessary Joker for an inferior one just to spend. The66 exits identify a policy
mismatch/coverage issue, not66 proven strategically harmful choices.

## 5. A full copying pool blocks the World→Fool/Jupiter exchange

Run2 observation2215 had$35, a visible$3 Fool and$3 Jupiter, last-used Jupiter and
seven prior Flush plays. Consumables were full10/10: ordinary World and Hierophant
plus eight Negative Worlds. Advice2219 used6,096 evaluations without truncation,
then leave2222→callback2223→blind2226/settlement2228. Two more Negative Worlds
appeared after leaving.

Direct capacity admission excluded both new cards before valuation. Current stock
exchange planning only covers narrow sole-filler/sole-Empress cases; World remains
useful for a Flush plan, so those routes do not apply. This is an executable
exchange gap, not just a missing bonus for Fool.

**Next fixture:** compare a funded ordinary-slot sale→Jupiter/Fool exchange using
the whole Perkeo pool, then refresh after the actual sale. Selling a Negative
consumable removes capacity too, so it cannot manufacture an empty ordinary slot.
Preserve Fool's actual last-used-card sequencing; never assume consecutive Fool
uses create repeated targets without consuming the recreated target between them.

## 6. Another visible Blueprint falls through incomplete finishing evidence

Run10 observations30194/30202 showed$29, a$10 Blueprint, and YorickX9/Perkeo/
Brainstorm/Misprint/Chad. Focused advice30197/30208 completed13,960 evaluations.
Misprint→Blueprint was admitted with merit34.85 and four clearing after-worlds;
Chad→Blueprint ranked higher at41.85. Neither had complete paired finishing
evidence, so no copy priority applied. Ordinary replacement then exhausted its
allowance (total44,480 evaluations), reordered30200 and left30211. Callback30212
and blind30215 confirm no acquisition.

**Next fixture:** preserve and complete independently supported focused copy
endpoints within the current budget, including removal of a randomness source.
Do not promote partial means or incomplete shared-world comparisons. This is a
confirmed admission/budget path and a suspicious missed upgrade, not proof of a
safe sale or a saved win. Run10 actually won.

Eight of ten visible Blueprint/Brainstorm offers were acquired. The other miss,
run9 Brainstorm26213, cost$10 against$8; funding required selling sole Perkeo or
YorickX1 and both endpoints failed the engine guard. It was not an affordable
direct-buy omission.

## 7. Early survival and temporary support need longer-horizon checks

Both terminal losses spent all discards in their final round:

| Run | Terminal blind | Settled final score | Final discards/cards |
|---|---|---:|---:|
|1|Ante3 Head|3,600/6,400|4/10|
|9|Ante3 Hook|5,570/6,400|3/5|

These settled scores correct the earlier last-hand snapshots2,712/4,895, which
preceded the final play. Run1 had previously left six discards across four clears,
then entered the terminal blind with YorickX3 and expired Raised Fist. It used
small discards while chasing Flush/Straight scoring, with Lucky uncertainty and
no supported random continuation. Earlier growth is a plausible contributor,
not proof a different sequence wins.

Run9 had no earlier unused-clear flag; it used nearly all full batches early,
but Hit the Road expired and Popcorn ran out before the Hook. Its final three
discards retained the four sixes and discarded1/3/1 cards, followed by Four of a
Kind, Full House and two Pairs. Holding the strong quad has a concrete rationale;
these logs do not prove that discarding five would improve the result.

Hit the Road came from Buffoon26219. Pack26224/advice26225 used a strategic score27
for perishable Hit the Road because its growth requires a real discard path;
Red Card had a completed comparison, merit19.63. Choose26229 settled ownership
at26234. **Test supported discard-dependent pack comparisons and temporary-Joker
replacement horizons**, rather than claiming Red Card would have saved the run.

One diagnostic is demonstrably misleading: at shop exit26854, the advice says the
actual upcoming target is unavailable, while its snapshot contains Boss/Hook6400.
`shop_scoring.next_blind` excludes Hook mechanics, and readiness emits a generic
missing-target message. Preserve that mechanics safeguard but report the actual
reason. Random-score/growth continuation was unavailable in93 advice records;
this is an important modeling boundary, not a silent exact-score failure.

## Negative findings and limits

- Both flagged Perkeo sales15553/30549 were final Verdant Leaf disabling actions;
  settlement15557/30553 confirms the blind disabled and both runs later won.
- Invisible passes had explicit tradeoffs: run3 would sacrifice an engine/copy
  because other slots were Eternal; run7's replaceable Odd Todd endpoint reduced
  sampled opening score to83.4% before Needle.
- The two pack-score conflicts are not established mistakes: Burnt versus Eternal
  rental Four Fingers, and Faceless versus rental Foil Hallucination. More opening
  chips alone do not establish the better purchase.
-21 Death uses all have the intended physical copy effect. Low-rank cases were
  not automatically random: run3's Lucky3/7 sequence built a supported Flush House.
  Run10 copied GlassKingClub. This does not prove every target was optimal.
- Run3 first Burnt discard5373 increased High Card2→4 with Brainstorm present,
  supporting correct copied-Burnt behavior in that observed case. Ten first-Burnt
  discards were observed; do not generalize that one case to all contexts.
-2639 policy actions have matching observation/advice/request/callback/settlement
  scopes. Ten compared display-score divergences disclosed uncertainty. These
  checks do not prove every forecast or asynchronous effect is exact.
-160 action records disclosed incomplete pack comparisons and strategic fallback.
  Three hand, six shop and five pack decisions hit their exact limits; complete
  families can also fail admission below a limit. Improve allocation/coverage,
  not the established computation caps.

All293 heuristic flags are retained with zero omissions. They remain triage
hypotheses. Analysis is passive JSON/SQLite/source inspection only: no captured
policy/scorer replay, simulated attempts, game control, saves/profiles, original
execution or new automation. Historical experiment budgets and audit432 review
are closed. Audit artifacts are under `analysis/`, `suspects/`, `deep2/`,
`discard/` and `economic/`; raw bytes and hashes remain in the preserved capture.
