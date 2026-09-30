# Prospective analysis plan for the user's current ten-run session

Written 2026-09-26 while the user reports run 10/10 is still underway. This is
an analysis plan, not a completed-session audit or a runtime change. Begin
capture/analysis after the user's completion message. The latest exact installed
baseline is checkpoint400, 2.194; the current session's public loaded label,
completeness and outcomes have not yet been audited. Existing preservation,
execution and closed-experiment boundaries remain mandatory.

## Objective and evidence discipline

Find repeatable, repairable causes of lost winning chances across the full
decision horizon. Analyze successful and unsuccessful runs, and positive and
negative opportunities. A win does not validate every choice; a loss does not
invalidate every choice. A local reliable clear, heuristic utility or sampled
score improvement is not a full-run win probability.

Each reviewed decision has two explicitly separate views:

- **At-decision evidence:** only public observations and receipts available by
  that sequence. Known legal options, affordability, observed modeled support,
  constraints and missing information determine the assessment.
- **Subsequent consequences:** later public settlement and resource changes,
  with exact event anchors. These can confirm what happened, but must not be
  supplied to an earlier valuation or treated as predictable hidden outcomes.

For each hypothesis record a concrete falsifier before deciding on a fix.
Do not label unopened contents, unseen rerolls or untried draws as missed known
cards. Neither selected seeds nor ten correlated trajectories identify the
causal effect of a policy change. Cross-run contrasts are diagnostic evidence,
not randomized treatment/control comparisons.

## 1. Preserve and establish the cohort

After completion is reported, passively inspect the process and public-journal
inventory. Identify this session from public lifecycle records, timestamps and
profile/version stamps; never reuse development400's hard-coded session name or
segment count. Copy all available relevant segments to an unused capture path,
hash source/copy bytes, verify stable reads and recheck sources. Preserve a
manifest of all segments, including rejected, partial or corrupt evidence.

A finished auto-run is not proof of normal process exit. A process can remain
open while completed segments are captured. If a tail remains mutable, preserve
and label a stable prefix and report the boundary; do not manufacture completion
or control the game to make a capture convenient. Do not clear any journals.

Verify record integrity, sequence continuity, session/run identity, starts,
terminal observations and controller stops. Join by explicit identifiers;
do not pair starts/endings by array position if anything is missing. Classify
wins, losses, unsupported/error/abandoned cases, interruptions and unknown tails
separately. Keep all ten starts in the cohort accounting if ten are evidenced;
otherwise report the actual evidenced count and discrepancy. Record source
search failures/start attempts separately from successfully started runs.

Record public loaded labels separately from installed byte hashes. Report the
observed cohort wins/starts with every other category, not a population win-rate
claim. Do not remove unsupported runs to make the percentage look better.

## 2. Build an auditable decision and resource timeline

Use copied public BRJ2 records only. Link observation -> advice -> requested
action -> callback -> post-action observation/settlement using their explicit
IDs and sequences. Callback success alone does not establish acquisition, card
transformation or completion. Preserve ambiguous/orphaned links as unknown.

Build one row per actual decision and compact checkpoints at blind entry,
blind exit, shop exit, and important purchases/sales/transformations. Record
public state and changes for:

- Ante/round/boss and known upcoming restrictions, remaining target, hands,
  discards and public scoring estimates/reliable floors when actually logged.
- Cash, prices, credit, interest, rentals, paid discards, committed reserves,
  optional spending and legal liquidations; distinguish cash from resale value.
- Joker row, capacity, compatibility/order, core engine and scaling counters;
  Perkeo's eligible consumable inventory and observed copied output.
- Hand levels and public deck composition, density of useful sources, seals,
  enhancements/editions, Glass exposure/destruction, removal and duplication.
- Search work, completeness, admission/unsupported reasons, decisions stopped
  by caps, and timing when present. Missing timing is not zero time.

Where dollar or card changes have several possible causes, mark an unexplained
delta rather than attributing all of it to the nearest action. Estimates are
context-specific: scores from different blinds/builds are not directly
comparable growth measurements. No synthetic full-state replay is performed.

## 3. Audit opportunities throughout every run

Count distinct opportunities, decisions and runs separately; repeated
observations of one offer must not inflate its denominator. Preserve successful
and rejected contrasts, with unknown reasons explicitly counted.

### Blueprint/Brainstorm and exploration

Inventory every actual visible copy offer. Trace public observation, candidate
generation, valuation, admission, budget allocation, arbitration, requested
action and settled ownership. Distinguish direct purchase, legal one-sale
funding, protected/unsupported endpoints, expired offers and missing receipts.
Do not treat a source-level eligible branch as proof it was executed live.

Separately inventory displayed Buffoon packs: price, cash after opening, current
reserve, slot/replacement route, competing visible rescue and actual open/skip.
Unopened contents remain unknown. Test for both insufficient exploration and
excessive reservation that prevents needed growth. Track discretionary spending
before a later observed funding shortfall; identify what cash was actually
spent, without assuming an alternative history would preserve the same RNG.

Separate native recipe satisfaction (Blueprint OR Brainstorm, conditional route)
from live acquisition. Identify public departures from its prescribed route
where possible; do not relabel the resulting unknown forecast as a missed
visible Blueprint. See audit402 A402-2.

### Death and persistent deck development

Inventory Death uses, relevant hold/fishing opportunities and inventory episodes,
including pack and tactical uses. Reconstruct physical source/recipient and
settled transformation, including reorder then fresh observation. Record the
user's ability/seal/rank/suit preferences in actual Joker/boss/hand context.

For use-now versus hold/discard, inspect known clear support, available public
population, safe retained cards and recipient, number of useful sources, paid
discard/interest cost, Yorick/Burnt gains, inventory saturation and Perkeo source
consequences. Examine the value destroyed as well as the source copied. A
weaker-ranked source can be correct if it supplies a needed clear. A safe clear
can also be an opportunity to invest; ending the blind immediately is not
automatically best.

Track later public source use, repeated copying and Glass loss as realized
consequences, without assuming those later draws were knowable. Missing fishing,
tactical or pack source receipts remain unknown under audit401 A401-2.

### Broader strategy and operational causes

Look for repeated short-horizon choices: spending for surplus chips instead of
growth, passing safe scaling, keeping cash while the build stagnates, polluting
Perkeo's eligible inventory, diluting useful cards, losing useful capacity,
overexposing Glass, or entering a publicly known boss without preparation.
Also examine supported reasons for caution: fragile survival, rentals, timing,
forced cards, uncertain mechanics and incomplete comparisons.

Assess candidate coverage and work allocation, not only ratings. Distinguish a
missing option, unsupported comparison, exhausted allowance, poor arbitration,
incorrect model, execution failure and logging gap. Measure actual timing/cap
incidence where receipts permit; do not infer a performance problem from code
complexity alone. Observed score mismatches require allowance for real random
outcomes and unsupported effects before being classified as model defects.

## 4. Trace delayed effects in both directions

For each terminal failure or severe loss of resources, identify the immediate
bottleneck, then walk backward to public decisions that created it. Look for
the earliest **supported and actionable** loss of a useful option, not an
invented precise point at which the run became unwinnable.

Example hypothesis, not a current-session finding:
optional purchase -> lower reserve -> later visible copy cannot be funded ->
weaker engine development -> later blind deficit. The first cash link may be
exact, the later power link merely plausible, and final rescue unproven. Label
each link independently. A purchase that changes the stock route also prevents
assuming that the alternative would encounter the same later offers.

Then trace suspicious early choices forward, even in wins. Follow cash,
scaling, inventory, deck composition and capacity until the effect disappears,
is compensated, or reaches a later bottleneck. Attribute shared effects once;
do not count the same loss as independently rescued by several proposed fixes.

Use mechanism-specific intermediate measures to detect delayed effects:
copy purchase readiness at actual opportunities; funded pack exploration;
Yorick/Burnt growth with safe resources available; useful source density;
Perkeo output composition; remaining hands/discards; observed reliable margin
against the current public target. These are diagnostics, not replacement
objectives to maximize blindly or calibrated predictors of wins.

Compare decision episodes with similar public ante, cash, build, capacity,
support and restrictions. Include disconfirming examples where the seemingly
better action would sacrifice survival or future flexibility. Report lack of
comparable cases instead of fitting a policy to ten outcomes.

## 5. Turn evidence into a small ranked set of repairs

For every finding provide: affected runs and opportunity counts; exact public
anchors; known state/legal alternative; causal mechanism and competing
explanations; pipeline stage; source path; confidence; missing evidence;
falsifier; proposed manufactured validation and regression risks.

Keep these evidence levels separate:

1. **Observed fact:** the actual action/settlement/resource change is established.
2. **Supported local defect:** public evidence plus source logic and a
   discriminating manufactured case establish a specific incorrect behavior.
3. **Strategic hypothesis:** a delayed mechanism is plausible but its better
   alternative or full-run effect remains uncertain.
4. **Full-run benefit:** requires later actually loaded-game evidence; local
   fixtures, scores and these ten observational runs cannot establish it alone.

Prioritize likely impact using opportunity frequency, strategic severity,
mechanism confidence, validation feasibility and collateral risk. Do not assign
fabricated percentages of added win rate. A recurring early engine failure may
matter more than a spectacular final-hand miss; one severe reproducible
execution defect can also outrank a frequent speculative strategy tweak.

Use newly manufactured abstractions and parameter variations, not copied saved
games or captured policy/scorer replay. Test production logic where relevant,
legal/unsupported alternatives, cash/rental/slot boundaries, strong-source
stacks, contextual tactical exceptions, ID/order invariance, complete matched
comparisons and hard budgets. Guard against merely restating the implementation.

Existing all-complete and visibility witnesses from audit402 remain separate
unless this cohort supplies evidence they affected it. No unrelated backlog
implementation is justified by a bad cohort result. Runtime changes, if pursued,
require a coherent new exact freeze, required full candidate/installed gates,
and existing release/normal-exit rules. No new experiment or game authority
comes from implementing this passive analysis plan.

## Deliverables and implementation notes

Deliver a preserved capture/manifest, a complete ten-start accounting (or an
explicit completeness gap), per-run timelines and bottlenecks, exhaustive
copy/pack/Death opportunity tables, a compact evidence-linked causal report,
and a ranked repair specification. Update the existing WIN_RATE_RESEARCH ledger;
do not create a competing backlog or count a claimed rescue as an actual win.

Read-only tools inspected while preparing this plan:

- `development400/capture_logs.py`, `verify_capture.py`, `audit_public.py`:
  useful capture/linkage precedents, but session/count/output paths are historical
  constants. Adapt in a new artifact without editing or overwriting old evidence.
- `tools/advisor_learning/public_context.py`: public redaction/knownness precedent;
  preserve raw public action references for joins. Its feature projection is not
  a substitute for the original receipt stream or authorization to train.
- `analyze_teacher_decision_timing.py`: bounded passive timing analysis with
  input hash and unused output path. Use only if the converted stream satisfies
  its schema; retain unavailable timing as missing.
- `development401/REPORT.md`: known incomplete failed-copy/fishing receipts and
  gate-provenance limits; absence cannot be upgraded into a rejection reason.

No current-session journals, saves or profiles were read to prepare this plan;
no analysis script, tests, native search, policy/scorer replay, game action,
runtime patch, installation or automation ran. This document is prospective.
