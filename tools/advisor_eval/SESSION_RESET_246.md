# Current checkpoint — 2.46.0-alpha

Subsequent user-requested planning audit: FORECAST_TOP10_246.md gives subjective
per-challenge bands and ten proposed next increments. No code, simulation or
installation occurred for that audit. It leaves the current ordinary aggregate
guess near35%; the ~50% future anchor is conditional speculation, not measured
progress or a forecast that every challenge exceeds50%.

Updated 2026-09-10 after the authorized six follow-on priorities. Read
ADVISOR_START_HERE.md, this file and NEXT_PRIORITIES_246.md, then relevant source/
tests and dated handoff sections. This supersedes 2.42/2.45 status. Original
contracts and historical evidence remain in SESSION_RESET_242.md and the prior
ten/nine ledgers; do not repeat those batches or read the entire old handoff.

## Objective and restrictions

Deterministic advice minimizing expected real time to finish all 20 challenges,
including failed attempts/retries, opening/filter setup, computation and user
actions.50%/75% targets apply to each challenge, neither demonstrated. No neural/
GPU training, schedules or automations. Preserve all tracked/untracked work;
no commit/reset/clean/delete/PR. Branch codex/exact-search-speedups, unchanged
HEAD 1fb4267701fc0545b5a3fd9148587505381e36ba; most development is uncommitted.

Never launch Balatro.exe or control/foreground/restart/stop the running game.
Original source may be read as ZIP and run with isolated lua51.dll in bounded
hidden probes. No live gameplay through tools, no user save reads/writes.
Product Execute remains user-clicked. Install each tested runtime slice using
install_slice.py, backups and hashes; activation waits for normal user restart.

## Installed and frozen state

**2.46.0-alpha**,2026-09-10 18:55:51 CDT. All 35 deployment files match repository,
installation and manifest. Exact hashes: SESSION_RESET_246.json.
Installed root: C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm.
Latest backup beneath that root: deployment-backups/advisor-20260910-185550.
Full release ledger/earlier backups: INTERVENTIONS_6.md (2.43, 2.44, 2.45, 2.46).
Config SHA256:15A399DFBE89A1237C76F6BC06CB9173764EFC4BE976FE9DA0243F549AC9741E.
Native Immolate-v2.16.dll unchanged. Saves not read or written. Running loaded
version unknown; installed files do not establish live activation.

Final product freeze: tools/advisor_eval/runs/development246/policy.
Digest:8dfb1955a4ced9491eaba8bdc0960b3edb66076bd888cb27d758f8946beee102.
Earlier development243 and development245 freezes remain immutable; evidence
must identify which policy and adapter produced it.

## Implemented behavior and limits

1. **Revealed Buffoon:** decision.lua creates the tactical context for actual
   offered Jokers. strategy.lua checks direct free choices and every supported
   legal one-sale/full-row replacement. Records all offers, blocked alternatives
   and tactical evidence. Eternal/pinned/Negative/Typecast/charged-Invisible,
   cash and retained synergies remain respected. Any unsupported or incomplete
   legal pack comparison causes whole-decision fallback; attempted evidence stays.
2. **Readiness:** shop_scoring.lua exposes complete four-sample opening profiles
   under actual next-blind resources, deck/levels and known restrictions. Only
   supported opening clears with 25% margins receive sampled_safe. The generous
   repeated-opening pressure proxy is NOT an upper bound or full finishing plan.
   Actual multi-hand/discard continuations remain unresolved. Unknown/concealed/
   random effects cannot establish safety. Immediate scoring/appropriate Planet
   purchase/use can receive emergency value; Perkeo/Observatory inventory roles
   remain protected. Paid rerolls use actual readiness instead of unmodified
   reset hands. 2.45 fixes post-boss all-Upcoming states and pack metadata using
   the original blind-selection predicate, including Skipped/Hide states.
3. **Conditional payback:** new conditional_value.lua handles supported payout
   triggers/timing, expiry, rental, interest and payback. Delayed Gratification
   has no budgeted payout under a sampled deficit without a credible no-discard
   plan; this never proves discards necessary. Other unsupported opportunities
   are explicit. Egg/Gift resale stays separate from cash. Selected immature
   growth is discounted under pressure; safe growth remains useful. 2.46 removes
   positive income investment ratings for nonpositive rental net income and
   includes all owned rental charges in To the Moon's interest basis, including
   debuffed/expired rentals; immediate scoring editions can still justify a card.
4. **Verified replay:** tooling skips redundant advisor calls only for admitted
   frozen prefixes. Original source fingerprints/RNG, phase/legality, score,
   cash/chips/resource transitions and provenance remain checked. Source-policy
   snapshot capture supplies canonical fingerprints, separately from candidate
   observations. Skipped work is explicit; no fabricated result diagnostics.
   decision_replay.py registers real decision checkpoints and optional bounded
   continuations. Numeric coefficient defaults are unchanged; no calibration
   improvement was established. Legacy fingerprint-less traces fail closed.
5. **Computation:** readiness reuses complete shop profiles; deterministic cache/
   comparison counters are exposed. New frozen component_profile.py/.lua compares
   cache-on/off across several workloads. Mixed measured benefit does not justify
   broader caching or larger search. No exact-score memoization was introduced.
6. **Filtered engines:** filtered_engine_compare.py registers filter/search
   cohorts, preserves misses/costs and validates acquisition separately from
   observed later retained engines. Chain auditing includes prior misses and
   native next-seed links. Jokerless excluded. No runtime/native filter changed
   or winner selected from this small censored sample.

Preserved:70-score fast clears, deterministic draw/effect streams, bounded
development and finishing plans, Glass/population conservation, whole-inventory/
Negative/Observatory Perkeo, Kings Strength/Death and exact Yorick/Burnt effects.
No new runtime budget/horizon expansion. Unknown mechanics stay explicit.

## Validation and evidence

- Final 60 Lua fixtures and 99 Python tests pass against 2.46; exact logs, test
  hashes and command results: runs/development246/validation/report.json.
  INTERVENTIONS_6.md records the release/source and tooling test counts.
- Final 2.46 source cashout probe: runs/conditional_value246_source/report.json,
  26 cases/80 original-source callback comparisons passed. Earlier2.43 source
  run retained at runs/conditional_value243_source_frozen/report.json.
- Verified replay details and commands: VERIFIED_REPLAY_245.md and
  COEFFICIENT_CALIBRATION.md. Corruption probes retain four intentionally rejected
  pre/post hash, score and illegal-index traces. Source adapter uses synthetic
  unlocks and cannot qualify population win-rate claims.
- runs/verified_replay245_pack_candidate/decision_report.json: actual Baseball
  Card/Devious offers; both policies choose Devious. Next Big target 450 is correct.
- runs/verified_replay245_shop_candidate/decision_report.json: at matched step 22,
  2.42 buys Delayed Gratification; 2.45 saves. Actual next Small target 800 is correct.
  Earlier2.43 metadata incorrectly said Big1200; keep it as bug-discovery evidence.
- runs/verified_replay245_shop_continuation/decision_report.json: same sampled
  failure remains608 chips short. Baseline31 actions/$-6; candidate30 actions/$-2.
  Six subsequent discards and final play are identical. Saves one purchase and$4,
  **does not rescue the selected run**.25.37s vs19.72s are selected counterfactual
  CPU timings, not measured retry-time or general speed improvements.
- runs/verified_replay245_holdout/report.json: preregistered unseen ordinary
  REPLAY245HOLDOUT1, both policies lose Ante1 Small by 12 chips after the same eight
  actions. It never reaches shop/pack, so offers no new build-decision evidence.
- runs/component_profile243/report.json: six workers/18 decisions, identical
  paired action/result/input fingerprints and score counts. Median plain→cached
  times: safe shop.040→.035s, weak full shop.035→.036s, nonclear.254→.231s.
  These are instrumented synthetic workloads; cache effects vary by workload.
- runs/filtered_engines245_fresh and filtered_engines245_continuation: fresh
  registered Any/Perkeo searches plus exact continuation seeds; seven misses and
  one found setup across eight bounded cells. Fresh found W9CH243A acquires
  Canio/Yorick; original callbacks remove Canio at Big entry, Yorick at Boss
  entry. Five cashouts observed, then censored at 40 actions. Whole retained-row
  scoring transfer still matters; lost names alone are not zero retained value.
  Dagger retains+20/+40/+44/+48/+52 Mult in observed rounds 1–5.
  chain_summary_final.json and its frozen aggregation_workflow.py include all
  8.862s of attempt costs. No filter preference,
  prevalence, time-to-win or win-rate claim follows.

Final 2.46 ordinary from-start ADVISORCOVERAGE332:34.410s within 45s, 30 actions,
same Ante2 Small loss608 short/$-2. First21 actions match2.42; first divergence
is the removed step 22 purchase. runs/development246_selected_episode/report.json
records the final frozen policy/adapter and all actions. The whole new policy
therefore removes a purchase without rescuing this selected failure.

All implementation agents have completed; no unfinished runtime edits, tests or
simulations remain. Do not rely on their identities or past tool variables.

## Resume guidance

NEXT_PRIORITIES_246.md ranks remaining useful work. Follow the latest dated status
instead of assuming any old unchecked proposal is missing. Use real action-
sensitive checkpoints to justify changes, then install coherent tested slices.
No revised numerical win forecast is justified by this work. The2.42 planning
judgments remain historical, unmeasured and neither confidence intervals nor
per-challenge estimates.50% and 75% per challenge remain unestablished.
