# Passive diagnosis415 — loaded2.199, session still active

This is an interim diagnosis, not a repaired or validated runtime. The user
authorized passive monitoring of session `session-20260926T235238Z-1` and then
reported another round with three discards left. Runtime remains exact installed
revision414. Read `SCOPE.md`, `LATEST.json`, and immutable capture summaries for
the monitoring boundary and newest state. Never infer normal exit from absence.

Capture004 contains10,119 verified complete events, four recorded losses, one
verified win, and run6 in progress at Ante5. All journal frame links and copied
source prefixes verified; no decoding errors. Public version is2.199.0-alpha.
This small unfinished session establishes neither a population win rate nor a
causal improvement. Process49852 was present. No game control, runtime edits,
captured policy/scorer replay, or original-game execution occurred.

## 1. Confirmed unused-discards behavior; broad modeling exceptions

The newest matching public event is request9157 (observation9152/advice9154),
run6 Wheel, September26 at19:09:20CDT. It plays KH from concealed observations.
Observation9163 records4,536/2,000 chips, three hands and **three discards left**,
followed by cash-out advice. This is a physical clear, not just a prediction.
Without the user's exact observation time, it is a matching example rather than
a definitive identification of the event they watched.

`decision.lua:663` unconditionally returns a public-model exception for either
`public_joker_belief` or `concealed_belief`, before attempting a retained-clear
discard proof. Hidden-card planning can recommend a play and that play can clear;
the user's strong discard preference is not applied in this branch. This receipt
does not establish that a discard was strategically harmful.

Two further independently reviewed run5 examples:

* Request6940, observation6936/advice6937, settled6945 at19:05:13CDT:
  48,363/37,500, all three discards unused. Mult AS and Steel AH were played.
  `growth.lua:223` calls `additive_order_safe`; the whitelist at17/176 excludes
  the owned Smiley Face and Duo. This is a qualification failure, not evidence
  that permuting that particular pair changes its arithmetic. Held Steel4S must
  still be preserved in any proposed discard proof.
* Request8099, observation8095/advice8096, settled8104 at19:07:22CDT:
  276,950/220,000 on Mark, all three discards unused. `growth.lua:207` rejects
  this boss before inspecting the retained visible non-face A-5-4-3-2 Straight.
  Newly drawn concealed faces need not invalidate a visible anchor, but the
  next recommendation must still recognize and select the same physical cards.

The winning run3 also contains repeated unused-discard clears. A win does not
excuse lost growth. Conversely, these examples do not prove all spare cards can
be discarded safely. Prefer a validated structural order-independent floor and
visible retained-card proof over either blind force-discard or a promised later
reorder. Include genuinely order-sensitive and held-Steel negative controls.

## 2. Acorn postpones discard comparison until the final hand

Run5 lost at285,461/400,000, ending8618. Requests8516/8535/8554 played while all
three discards remained, scoring120,560,16,544 and13,365. Only with one hand left
did8572/8587 discard; final8603 played for134,992 with one discard still unused.
Five public Joker orders remained. Its advice explicitly claimed a clearing
floor in only two of those five orders, not a win probability.

`decision.lua:128` admits `acorn_discard` only at `hands_left==1`, repeated in
`acorn_discard.lua:104`. Earlier public-belief decisions maximize an immediate
conservative score without that discard comparison. This explains the missing
early comparison. It does not establish that an earlier discard wins this deal.
An invented multi-hand fixture should compare first-discard and first-play
continuations over the same public worlds within the existing ordinary budget.

## 3. Mouth planning cannot represent a legal blocked-hand continuation

Run4 ended708/2,000 at5396. Three four-card discards5307/5322/5335 reduced Green
from+2 to0 and Yorick's countdown14→10→6→2 without increasing its×2 multiplier.
All three recommendations reported an unavailable remaining-blind comparison.
Request5348 locked Two Pair for276;5376 later added432. Requests5362/5388 were
correct legal zero-score cycles: their visible hands lacked a second pair.
No held consumable was available.

The independent source review found `search.lua:1595` rejects a rollout with no
scoring play, and1636 abandons the whole comparison, while `decision.lua:8`
already supports a legal zero-score Mouth cycle during actual execution. That
coverage mismatch is consistent with the warnings; the failing sampled branch
is not logged. Also, `search.lua:1035` returns at zero discards, so the eventual
first lock does not receive that cumulative category comparison. Immediate
Two Pair276 versus Pair168 does not establish greater repeatability.

Green's discard damage is modeled; its presence disables the small Yorick
progress bonus. These discards were not proven to be forced by the new
clear-exhaustion rule. Fixtures should cover blocked cycles, first-lock category
scarcity at zero discards, and persistent Green loss versus attainable Yorick
growth. No alternate winning line is demonstrated.

## 4. Perkeo categorically blocks a last-hand generator rescue

Run1 Manacle ended536/600, loss279. Last request271 played Pair40 with104 needed,
one hand and zero discards. It still held two Judgements, including a Negative
copy, and only Yorick/Perkeo occupied its five Joker slots. Earlier three
one-card discards195/208/222 advanced Yorick10→7, leaving it×1.

`consumables.lua:673` rejects **every** generator rescue with active Perkeo,
before the all-legal-play ceiling proof and candidate capacity checks. The stated
reason is protecting the future copying pool. The policy has a rescue route;
the categorical protection disables it in precisely this teacher archetype.
This is a confirmed source gate and missed reveal opportunity, not proof that
an unknown generated Joker would win. An invented fixture should establish a
complete losing immediate ceiling, legal free slot, and a retained Perkeo source
before allowing a reveal followed by fresh advice. Preserve negative-slot and
unknown-generation restrictions elsewhere.

The early three single-card discards and skipped affordable Buffoon are separate
valuation/admission hypotheses requiring manufactured comparisons; do not count
them as already demonstrated mistakes.

## 5. Shop fallback drops the relevant survival comparison

Run2 Water ended5,540/6,400 at1235, with$26 unspent. Pack requests1142/1152 chose
Smiley over an **expired** Scholar, improving the recorded opening estimate.
Their advice nevertheless stated that all three bounded whole-blind policies
failed in all four composition worlds. That is limited policy evidence, not a
proof of inevitable loss.

At leave-shop1165, the49,300-call comparison was truncated. The advisor fell
back to strategic ratings and rejected a$5 reroll because$21 afterward was below
its$37 surplus requirement. Mercury$3 and Jumbo Arcana$6 were still visible.
`decision.lua:352` rebuilds advice without scoring; the fallback clears reroll
receipts and rechecks only surplus spending. `strategy.shortfall_reroll` rejects
a truncated context. Known sampled danger does not survive as an emergency
cash-allocation comparison in this path. Reserving future purchasing cash can
therefore coexist with entering a visibly weak imminent boss.

This extends the older413 fallback concern. A repair must reserve bounded work
for a complete incumbent readiness comparison and treat unresolved candidate
coverage fairly; it must not reuse partial candidate rankings or promise a
beneficial random reroll. No particular alternative purchase is proven to win.

## Other checks and limits

The first complete screen (capture001) produced79 hypotheses:65 short discards,
13 unused-discard clears, one pack merit/opening-score conflict. Its flags are
not an exhaustive error count. Pack request1822 chose Wily with opening mean564
over Gluttonous730.5, but both have complete finishing comparisons and differ in
longer-term value; that one metric alone does not prove the choice inferior.
Preserve it as an unresolved valuation review, not a confirmed defect.

In capture002 all three distinct observed Blueprint/Brainstorm offers were
acquired. The installed Perkeo repair also has a positive physical control:
request2267 moved Blueprint before Perkeo,2278 exited, and observation2282 shows
two new Negative Empress copies. Across that capture27 shop setup reorders were
selected. This does not prove every future opportunity is handled correctly.

## Next coherent repair order

1. Fix supported unused-discard exceptions: structural ordering floors, visible
   anchors through concealed redraws, and final-action preference enforcement.
2. Add early Acorn discard and legal Mouth continuation/category comparisons.
3. Add rigorously admitted last-hand generator rescue with Perkeo.
4. Keep complete survival evidence useful through shop budget fallback.

Use independent invented fixtures, real mocked observation→advice→execution→fresh
observation chains, and existing fixed score budgets. Runtime work requires a
new combined freeze and full candidate/installed release gates. Monitoring does
not authorize modifying this active game. One substantive read-only review and
one focused recheck completed for415; no further review delegation in this slice.
Heartbeat `monitor-current-balatro-session` follows only this session and stops
when it ends or its process exits. See `REVIEW.md` and `evidence.json`.
