# Post-mortems, outcome measurement and bounded tuning — 282, 2026-09-13

This is a read-only analysis and future-method recommendation following the
user's proposal. No new source, component, replay, seed-search, parameter-screen
or complete-attempt worker is authorized or executed by this document. Existing
2.82 runtime/installation and historical experiment ledgers remain unchanged.

## Assessment

Failure post-mortems are the highest-value immediate proposal. The preserved
traces can reveal whether information reached the decision, an alternative was
considered, a comparison finished, and which term selected the action. Those
questions distinguish integration, support, search coverage and valuation errors.
The observation that a run lost cannot establish that its earlier actions were
wrong. There is no general proof of optimality available for these large states.

The user's hypotheses about integration, nonlinear effects and future consequences
are plausible and have concrete examples below. They are not yet a quantified
explanation of most losses. Late-run selection is useful for discovering scaling
problems, but excludes early deaths and can bias what we choose to fix. Retain
early-loss examples and eventually an unselected evaluation cohort as controls.

## Review procedure

For each pivotal decision, retain a structured decision card:

1. Frozen policy, adapter/profile/source provenance, exact snapshot/result hashes,
   actual selected action and public information available before that action.
2. Cash, hands/discards, held cards, reachable rank/suit populations, inventory
   capacity, developed hands, relevant public boss restrictions and action costs.
3. Alternatives actually enumerated, their evaluation scope, whole-family
   completeness, admission/fallback reasons and exact scores versus sampled values.
4. One or two concrete legal alternatives, motivated without using later draws,
   offers or random events. Record the opportunity cost as well as the benefit.
5. A verdict: established mechanical/integration defect; incomplete comparison;
   plausible but untested valuation defect; reasonable risky choice with bad
   realized outcome; or insufficient evidence.
6. Only then inspect the realized continuation. Keep observed consequences
   separate from claims about what the alternative would have caused.

A future review can hide the trace suffix from its first-pass reviewer and freeze
the alternative/verdict before revealing it. The present audits are retrospective,
not blinded experiments. Auditors know the terminal outcome and explicitly avoid
using its later card identities as decision-time information.

Prioritize the earliest consequential unresolved branch, not merely the final
losing play. Include shops/packs and inventory timing; they can change later legal
options. Keep no-regret local fixes distinct from whole-run superiority. Preserve
fixed historical findings as fixed, rather than count them as current defects.

Counterfactual execution, if later authorized, must use separately frozen policies
and complete legal transitions. An alternative action can alter draws and random
stream consumption. Never splice the original future trace onto a changed action.
Within supported sampling, future action choices depend only on their then-visible
observation, not the sampled hidden state. A favorable realized counterfactual
alone would not prove it was the better ex-ante decision.

## What the preserved cases already show

Detailed case notes and hashes are under `runs/postmortem282_readonly/late_run/`
and `runs/postmortem282_readonly/dependent_runs/`. These are selected development
cases; they are not additional attempts or independent statistical replications.

- **Source05, policy274, final Bell loss:** the late shop/blind path held two
  Saturns with both consumable slots occupied and no Observatory. Advice text
  called for their use, while actions opened a pack and later left the shop.
  That instruction/action mismatch is historical and was repaired by275. The
  same slot state also affected pack-option availability and upgrade timing.
- **Source05 Bell resource planning:** all four discards were spent while a
  complete remaining-hand comparison was unavailable. At step226 a recorded
  legal modeled300-chip play of indices1–5 included the forced Jack of Diamonds.
  Playing those cards as a cycling hand would consume one of five hands while
  retaining the last discard. The chosen discard consumed that discard and
  retained five hands. The alternative has a defensible information/resource
  rationale, but no complete comparison or rescued result is established.
- **Source05 versus source06:** after identical selected actions through step39,
  the later policy used Saturn at step40. The later Club sequence consumed an
  extra hand and paid one dollar less; after two paid packs, the visible $3 Hanged
  Man was affordable on one route and unaffordable on the other. This is an
  observed threshold chain across scoring, payout and acquisition. It does not
  establish that leveling the hand was wrong, or identify the cause of terminal
  divergence between finalBell and Ante3Eye losses.
- **Source10 Eye:** a paid pack preceded the boss while next-blind forecasting
  was unavailable. Three discards were spent with an existing2465-chip Straight
  against4000; the continuation comparison rejected unsampled Lucky effects.
  A held Hanged Man never entered a joint multi-action plan. Preserve the
  hypotheses of earlier play/discard retention and removal timing, without
  assigning them a rescued outcome.281/282 do not retroactively change this loss.

Some current callers still decline ordinary uncertain Lucky scores before using
282's sampled transition, and the large-hand/full-resource horizon gaps remain.
These observations support completing the relevant comparisons before tuning
scores. They do not justify dropping uncertainty or inventory safeguards.

## Outcome metrics

Average stage reached is a useful development diagnostic. Average round before
failure should not be the sole optimization objective:

- A policy could prolong losing runs while reducing completed wins or taking
  more real time. Completing Jokerless remains the objective.
- Averaging only failures changes the population when a late loss becomes a win.
  The remaining failures can become earlier even though the policy improved.
- Round numbers can be affected by skips and route choices. Use predefined ante/
  boss milestones, record skipped blinds separately, and verify terminal wins.
- Timeouts and unsupported attempts are unresolved outcomes, not ordinary losses.
  They may correlate with difficult states, so routine noninformative-censoring
  assumptions are not automatically justified. Never drop or impute them.

For a newly registered stable cohort, report verified completion frequency,
survival/progression at fixed milestones, actual attempt compute/action costs,
and all error/unsupported/timeout/censor categories. When no completed wins are
observed, report that expected real time to completion is not established; do
not turn a proxy or a few selected attempts into a finite calibrated estimate.
Report verified wins and unresolved attempts against the full registered cohort;
do not present wins divided by resolved attempts as its overall completion rate.
If W of N attempts are verified wins and U have unresolved outcomes, W/N through
(W+U)/N describes the possible cohort completion fraction without imputing those
outcomes. These missing-outcome bounds are separate from sampling confidence
intervals and do not establish player-population rates.
Current source timings do not include a measured user's animation/click/restore
workflow, so those costs need separate observations before real-time claims.

Compare policies on the same prospectively chosen initial seeds/profile and
let each policy produce its own legal continuation. With adequately sampled
independent seeds, uncertainty should concern the paired policy difference.
Resample whole seeds and all their paired variants together, not individual
decisions or later dependent continuations. Use interval methods appropriate to
the sample size and metric; ordinary bootstrap intervals are not reliable for
every tiny/degenerate sample. Repeated inspection/stopping and selection require
prespecified handling. No method can turn the old adaptive12 mixed-policy
attempts into a representative current-policy cohort.

The need to quantify finite-run uncertainty is also documented in
[Agarwal et al., 2021](https://proceedings.neurips.cc/paper/2021/hash/f514cec81cb148559cf475e7426eed5e-Abstract.html).
That paper is statistical-method context, not evidence about this advisor.

## Interactions and parameter optimization

There are fixed base consumable ratings in `Brainstorm/Advisor/strategy.lua:533`
(for example Moon38, Chariot58, Death68). These are heuristic points, not chips,
cash or probabilities. Context, whole-inventory preservation and complete tactical
comparisons may adjust or override them. `policy_weights.lua` separately exposes
six bounded coefficients: growth action cost, growth utility scale, discard
action penalty, shop scoring gain weight, reroll target gain and computation cost.
`calibrate_policy.py` and `checkpoint_calibration.py` already support frozen,
bounded screening; neither was executed in this analysis. Exact inventory of
the inspected files and default values is in
`runs/postmortem282_readonly/parameter_inventory.json`.

Evolutionary search is a plausible later optimizer for a small set of these
parameters. First verify that changing them changes decisions on relevant
states. If an action is never generated or a required transition is unsupported,
tuning a rating cannot make that action or transition available. Tuning can learn
an empirical proxy for an omitted downstream effect, but that compensation may
generalize poorly when the context changes. Keep hard correctness/safety/cap
rules outside optimization.

For a few proposed interacting repairs, first compare baseline, A, B and A+B
on paired seeds. On an additive response scale, the interaction contrast is
`metric(A+B) - metric(A) - metric(B) + metric(baseline)`. Its uncertainty must
preserve the within-seed pairing. This tests whether a joint gain differs from
the sum of isolated gains; conclusions depend on the chosen metric/scale.
It is the rationale for a small factorial design rather than discarding either
repair solely because it has little standalone effect. See
[NIST's factorial model guidance](https://www.itl.nist.gov/div898/handbook/pri/section4/pri43.htm).

With six current tunables, a bounded designed/random screen is a useful baseline
before adopting an evolutionary optimizer. Retain the default as a control,
limit adaptation, and never tune on the final unseen cohort. Evolution can
optimize noise or simulator omissions as effectively as real improvements.
[Cawley and Talbot, 2010](https://www.jmlr.org/beta/papers/v11/cawley10a.html)
documents how optimizing a noisy model-selection criterion can overfit the
evaluation itself. Keep development, candidate selection and final confirmation
separate; changing optimizers does not remove this requirement.

No neural training is required for bounded coefficient search. No parameter
optimization of any kind ran here. Fresh experiment authorization must specify
policy variants, initial-state distribution, source/profile support, primary and
secondary endpoints, per-worker/cumulative caps, one-use limits, stopping rules
and final holdout handling before any source or replay worker is launched.

## Recommended order

1. Finish retrospective decision cards and identify missing complete comparisons.
2. Implement the smallest supported joint comparison and meaningful fixtures.
3. Under fresh explicit bounded authority, verify source compatibility and run
   paired full outcomes with all failures and costs preserved.
4. Use milestone changes to diagnose mechanisms; judge progress toward wins and
   real completion time. Investigate unchanged/worse results rather than hide them.
5. Test likely interactions; tune only live decision coefficients after coverage
   and source fidelity are adequate; independently confirm selected candidates.

This development order prioritizes information gained per unit of work. There
is still no verified complete Jokerless win or current numerical player win odds.
