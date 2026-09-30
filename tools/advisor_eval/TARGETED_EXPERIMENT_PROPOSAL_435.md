# Proposed435: targeted paired decision experiments

Status: prepared for user authorization; NOT STARTED. No new experimental
allowance exists yet.429/355 and every historical allowance remain CLOSED.
Installed434/2.214 and all captures, settings and runtime files remain unchanged.
This proposal does not reopen434's completed runtime review.

## Questions and fixed cases

1. **Trio versus Sly before Goad.** Public pack observation10067/request10072 in
   development434/captures/001 offers both free Jokers, with Yorick/Perkeo owned,
   no held consumables,52 known playing cards and upcoming Goad600. Compare each
   acquisition, explicitly closing the current shop with no additional spending,
   then continuing the next blind with frozen2.214. Is the future-value preference
   for Trio accompanied by a worse immediate survival result in this model?
2. **Short versus five-card discards.** Use exactly four preselected public hand
   observations10102,13255,18317,27883 (requests10107,13261,18322,27889; runs4,5,7,10).
   They precede recorded4/3/4/4-card discards. Compare the current frozen advisor's
   default first action with its highest-ranked five-card discard from a complete
   common-world candidate comparison, then resume the same unmodified advisor.
   If it already selects that five-card action, record a tie. If no complete legal
   five-card candidate is available within the existing score cap, report that
   admission gap and do not invent a ranking or replace the case.

These cases deliberately target observed concerns. They are not a random sample
of all play, independent full runs or estimates of overall win rate. Four worlds
from the same decision are correlated; report each case separately.

## Design and metrics

-Pack case:8 preregistered hypothetical future worlds ×2 acquisition branches.
-Discard cases:4 cases ×4 preregistered future worlds ×2 first-action branches.
-48 continuation branches total, grouped into24 matched pairs. Both branches
  share the same initial public state and hypothetical future population/draw
  order. Random event streams are paired where semantic event identity matches;
  branch-specific actions still have their own actual modeled consequences.
-Only the first choice changes. Subsequent decisions use exact2.214 policy bytes
  with teacher mode and ordinary product caps intact. No outcome-based action,
  world, case or policy selection. No hidden future information enters advice.
-Primary results: paired next-blind clears/failures and coverage. Also report
  discards used, cards discarded, full-five discards, remaining hands, physical
  Yorick/Burnt/hand-level growth and supported cash/consumable/population changes.
-Timeout, unsupported transition, no advice, loop, action cap and unstarted jobs
  remain separate categories. Never convert them to losses or silently omit them.
  Report metrics with their exact denominators and paired resource tradeoffs.
-A supported clearing floor may establish the round's survival without proving
  all after-play resources. Resource endpoints require the actual qualified
  transition; unavailable resources are labeled unavailable, not assumed intact.

## Qualification required before captured evaluation

Current code inspection establishes that shop_scoring supplies exactly four
composition worlds and blind_finishing follows fixed play/one-discard policies.
That forecast can explain the production ranking but is NOT full teacher-policy
continuation. Its internal states must not be relabeled as faithful teacher input.
The old429 driver supports hand continuations, not pack choice/blind startup or
forced-first-action comparisons. It also needs canonical public deck ordering
before the FIRST decision, not only after refills.429 code/ledgers stay immutable.

Prepare a new detached adapter and validate it on manufactured inputs before any
captured policy/scorer execution. Required checks: free pack acquisition without
double charging; explicit common shop closure; correct Goad debuff, hand/discard
resets and blind startup; full teacher-profile/public-history preservation;
private draw-order separation from canonical public composition; actual physical
discards/growth/card conservation; deterministic consumable and reorder actions;
matching a live-format manufactured decision before forcing the alternative;
and fail-closed unsupported/random effects. No Balatro process, original game
component, saved game or profile is executed/read. Use the detached project model.

Five initial diagnostic jobs are registered: one complete paired shop comparison
exporting its full finishing distributions, and four ordinary decisions for
alternative admission. They are captured evaluations and consume the new budget.
Each hand decision may expose only a fully completed existing discard family;
do not raise140000 ordinary/50000 shop/25000 consumable/70 fast-clear/12 growth caps.

If qualification fails, stop with the precise gap; no captured rollout begins.
Do not silently substitute the355 simulator: its heuristic/learned policy is
different from this advisor, and its unresolved mechanics remain censored.

## Proposed one-use execution budget

One serial local CPU worker, below-normal priority, no GPU/training/cloud compute.
5 initial jobs +48 continuation branches =53 jobs maximum,15seconds per job.
Maximum child evaluation wall time795seconds; overall runner wall limit900seconds
(15minutes), including setup/serialization/ledger overhead during execution.
At most16 actions per continuation; no retries, replacement cases, automatic
extension or resumption. A matched pair begins only if both job caps fit. Pair
order is preregistered and alternates branch labels to avoid preferential timeout.

Adapter preparation and manufactured qualification are separate from the795-second
captured-evaluation allowance and may take additional development time. They grant
no captured evaluation before the frozen manifest is complete. No paid compute is
requested; local CPU time and normal Codex work are the resource costs. No dollar
estimate for account usage is claimed.

Freeze before execution: installed2.214 policy inventory/digest
`0d0dbdc6086e3bd1b96394e0932af75347fabb1494ed120301f131812daf642e`, current runtime
wiring, adapter/tests, public input/capture hashes, case/branch IDs, synthetic
world IDs and generation rule, sort rule, Lua/Python provenance and job order.
Freeze any alternative-admission rule before its initial diagnostic job; the
diagnostic may fill action IDs but cannot select cases or futures by results.
Record immutable execution/worker claims and close unused capacity permanently.

## Interpretation and next step

This can establish a reproducible local ranking or discard-policy defect, or show
that an apparent mistake is a survival/resource tradeoff. It cannot settle the
entire delayed value of Trio, Burnt, Perkeo, Invisible or retained money. Later
questions need a separately qualified multi-round adapter covering rewards,
rentals/perishables, Perkeo copies, shop inventory/prices, boss restrictions and
future decision logic; score proxies alone must not certify those effects.

Any supported repair needs manufactured regression fixtures and the usual new
combined candidate/installed freeze and full gates. Simulated gains then require
checking against user-started loaded-game evidence. No50% or other population
win-rate claim follows from this selected pilot.

Authorization prerequisite comes from ADVISOR_RESUME_PROMPT.md: a new experiment
needs concrete hypothesis/caps/cost and fresh user authorization. This document
makes that request reviewable; no captured evaluation was run while preparing it.
