# Current checkpoint — 2.62.0-alpha, 2026-09-10

The authorized next-ten implementation after 2.53 is complete within the bounded
scopes below. This supersedes the in-progress 2.59 checkpoint and historical
unchecked proposals. Start with ADVISOR_START_HERE.md, this file, then
NEXT_PRIORITIES_262.md. Read only relevant source/tests and dated handoff sections.
INTERVENTIONS_TOP10_254.md is the release/evidence ledger. No measured win-rate
gain, successful coefficient calibration or filtered-route promotion is claimed.

## Installed product and preservation

- Installed 2.62.0-alpha at 2026-09-10T21:23:47.7578589-05:00.
- Installation: C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm.
- Latest backup: deployment-backups/advisor-20260910-212347 under that installation.
  Its deployment.json records all 44 deployed files and verification results.
- Full installed policy: tools/advisor_eval/runs/development262_installed/policy.
  record.json and SESSION_RESET_262.json preserve exact hashes and branch/status.
  All 58 frozen product/dependency files match repository and installation;
  this broader frozen manifest is distinct from the 44-file deployment slice.
- Policy digest: 60ededca68ab3e5ff10c655b4a0351b0df82b4bec498bd67ed4f7f09b159f98b.
- Settings SHA256: 15a399dfbe89a1237c76f6bc06cb9173764efc4be976fe9da0243f549ac9741e,
  unchanged throughout these installations. Native DLL also unchanged:
  34598478571391d272c1e1a837832061bd767a09ab552bb61ef3458e24e9d751.
- Branch codex/exact-search-speedups. Development remains mostly uncommitted.
  Preserve ALL existing tracked modifications and untracked work. No commit,
  reset, clean, deletion of existing work or PR was performed or is authorized.
- No game process/window/control or executable launch. No saves read or written.
  Running loaded version is unknown. Activation waits for the user's normal
  restart; Product Execute remains one action per user click.

## Completed ten, source and acceptance boundaries

1. **Complete shop incumbent versus reroll (2.55).** decision.lua and
   shop_sequences.lua retain the best complete endpoint for every admitted first
   action, even when that first action is unchanged. strategy.lua/paid_reroll.lua
   compare actual endpoint scoring and net cash. Replan after the actual action;
   no queue or free speculative continuation. advisor_shop_reroll_continuation.lua
   covers unchanged first action, use/sale-first plans and incomplete mismatches.
2. **Exact scoring work reuse (2.54).** scoring.lua/score_cache.lua reuse immutable
   Joker/copy routing and avoid unnecessary writable copies. Transition copies
   and inputs remain protected; budgets/samples unchanged. advisor_scoring_reuse.lua
   makes 3,130 differential comparisons against frozen 2.53. Identical-result
   profiling completed all 18 decisions per policy: prepared 9-card median
   1.587→1.397s; 10-card 1.901→1.804s. Three repetitions, synthetic workloads and
   host-load caveats; the 12-card case was a 23-score clear, not a nonclear test.
3. **Declared profiles and meaningful checkpoint calibration (tooling).**
   engine_probe.py/.lua, qualify_source_profiles.py and checkpoint_calibration.py
   record named fresh in-memory profiles before episodes, frozen provenance,
   actual coefficient opportunities and bounded verified replay. Original flags
   have 105/150 Jokers unlocked; the declared full profile has 150/150. Neither
   matches user saves or qualifies the episode adapter for population win rates.
   Two frozen 2.58 screens kept the same actions. The first exposed weak admission
   and is retained as unsuitable; the second had 11 paired shop comparisons but
   gain 1 versus 1.5 still bought Crafty. No defaults fitted/promoted.
4. **Shared survival liquidity (2.58).** liquidity.lua is used by purchases,
   complete shop endpoints, conditional income and rerolls. Actual debt, rentals
   and conservatively all available paid discards enter the reserve. Supported
   Water/Burglar resources are honored. Safe opening samples alone never release
   cash. Complete matched resource-plan support exists, but no current producer
   supplies it. Incremental gaps are penalized rather than universally blocking
   emergency spending. Delayed Moon income cannot finance its own purchase.
5. **Computation/action cost in build value (2.57/2.60).** work_cost.lua estimates
   bounded subset/discard/future work; Shop.compare adds a bounded secondary
   adjustment only with supported readiness. Counts use existing search limits;
   seconds-per-score, representative decisions and click costs are explicit
   heuristic assumptions, not measured playtime forecasts. policy_weights.lua
   schema2 adds shop gain, reroll target gain and computation scale hooks; original
   growth/discard defaults unchanged. Nonzero opportunities are recorded for
   calibration; zero-effect/unsupported checkpoints fail admission.
6. **Full-row tactical catalog replacements (2.61).** strategy.lua/paid_reroll.lua
   admit complete legal victim sets with <=6 shortlist entries and <=12 victim
   comparisons inside the shared 50k shop allowance. Refresh funding precedes
   contingent sales; debt, Negative capacity, preservation, liquidity and unknown
   sale effects are checked. One complete retained-row miss comparison includes
   negative cash-sensitive scoring; no optimistic positive miss growth. Candidate,
   victim and miss diagnostics survive rejection. Independent offers, shortlist
   omissions and four target-clipped openings remain heuristic. Source transitions
   pass 20 cases/296 comparisons; a real Bull/Duo fixture now declines the rare-hit,
   likely-loss reroll. SHOP_COMPARISON_FOLLOWUP_259.md preserves details/corrections.
7. **Honest concealed observations (2.56).** concealed_belief.lua conditions
   jointly on visibility, including Mark plus independent random flips, removes
   latent held/deck identities and order, and scores the same fixed action across
   16 worlds. Decision dispatch precedes ordinary latent search/strategy. Supported
   scope is final hand, no discards or consumables, <=8 held/120 deck and <=8k
   scores. Other concealed horizons explicitly return unsupported/no action.
   Public labels hide identities. 300 belief checks plus source visibility/weight
   parity and runtime/routing tests; this is a bounded estimate, not a guarantee.
8. **Broader conditional finishing (2.59/2.62).** two_hand_finish.lua extends the
   existing two-hand/final-redraw specialist to three hands <=6 cards, requiring a
   completed ordinary baseline and retaining the same 12k score cap. Middle plays
   follow observed hands. For <=6 current/configured hand size, <=2 actual zero-target
   Planets/Black Hole may be compared before playing, against the best no-use plan.
   Exact use, full inventory/Negative/Observatory cost and protected last Perkeo
   source are mandatory. All offered items are recorded; incomplete/unsupported
   admitted comparisons fail closed. One use is advised, no queued future play.
   2.62 fixes missing middle-play indices in Gold/Blue rewards and records exhausted
   post-middle populations as losses. Current clear and existing tactical/growth
   priorities remain protected. Not a general shared resource/consumable optimizer.
9. **Executable startup copying (2.60).** blind_prep.lua uses complete bounded
   one-insertion families <=57 orders, preserving pins, exact Dagger victims,
   scoring order/copy targets before and after sacrifice. Actual user-visible
   preparation and shop projection use the same fixed chain. Burglar and narrowly
   guarded terminal Hologram/Marble investment are supported; no free later reorder
   is assumed. Continuous growth ratio is heuristic, not a rounded score floor.
   Unknown/additive/Plasma/cash-cap/incompatible cases decline; generated cards
   remain stochastic in readiness. Source 44 cases/917 comparisons includes six
   actual proposals. advisor_blind_copy_setup.lua and advisor_shop_start.lua test scope.
10. **Retained filter engines and total cost (tooling).** filtered_route_selection.py
    reaudits misses, retained whole rows, attrition, terminal outcomes and total
    setup/search/compute/action costs. Terminal matched cohorts are required for
    even a diagnostic seconds-per-win ranking. One-more-search scenarios include
    misses and fallback cost. The old 252 cohort remains inconclusive; no new
    native filter/policy was promoted and Jokerless remains excluded.

## Validation and evidence

Final runs/development262_validation/report.json: **80/80 Lua fixtures and
129 Python tests pass**. Hidden workers had separate 60s caps; Lua 9.094s,
Python 5.859s including launch. Policy and test hashes remained unchanged.
This validates implementation regressions, not wins. Final owned-use integration:
six fixtures/815 checks; 787 scores for an actual later-Pair Planet improvement,
8,340 for a six-card three-hand/two-upgrade comparison. The existing eight-card
two-hand case remains 9,600. Fast-clear and population/Glass, Perkeo, Kings,
Yorick/Burnt and safe growth regressions pass in the full suite.

INTERVENTIONS_TOP10_254.md records every tested slice, backup, timing caveat and
fresh artifact. CALIBRATION_FILTER_TOOLING_258.md records exact caps and negative
screens; no screen renews an exhausted lease. Initial errors and failed fixture
attempts remain saved. The final root owned-finish integration's first directory
contains a missing-fixture-path runner error before tests; integration2 supersedes
it without deleting it. No full source campaign or measured win evidence for 2.62.

## Objective and limits that persist

Minimize expected real time to complete all 20 challenges, including failed
attempts/retries, opening/filter/setup/compute and user actions. The 50% and 75%
targets apply to each challenge separately; neither is demonstrated. Do not add
projected gains to subjective forecasts. Historical ordinary ~35% planning anchor
and proposed ~50% after successful further work/calibration were unmeasured
judgments, not current per-challenge estimates or results of this implementation.
Calibration did not succeed, so no numeric win forecast is raised here.
The subsequent requested odds update in FORECAST_262.md retains the rough35%
ordinary/45%launched-filtered anchors and old per-challenge planning bands, with
explicit human handling of unsupported states; none is newly measured2.62 evidence.

Unknown mechanics stay explicit. Do not repeat earlier completed batches or
exhausted experiments. Future tests need fresh bounded outputs and frozen policy,
adapter and profile provenance; retain errors/timeouts/unsupported/censors.
Never launch Balatro.exe, even headless; read-only ZIP plus isolated lua51.dll is
allowed. No saves, game control, neural/GPU training, schedules or automations.
Install tested runtime slices immediately with install_slice.py, backups/settings
and hash verification. Tooling/documentation changes need no runtime release.
