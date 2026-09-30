# Nine further interventions - authorized after v2.31

User approved all nine proposed improvements on 2026-09-10. Preserve the dirty
tree, settings and saves. Install each tested runtime slice immediately with
backups/hash verification. No live game, process/window control, schedules or GPU.

| # | Scope | Status |
|---|---|---|
| 1 | Bounded reward-aware reliable clears | Installed 2.34, extended for actual DNA Gold/Blue copies in 2.40/2.41; 58 fixture checks +22 source cases/169 checks |
| 2 | Exact prepared scoring/cache and adaptive nonclear allocation | Cache 2.35, ordinary draw visibility 2.37, strict finite-tail final-hand sampling stop 2.39; 3498 cache differential/integration checks +6 adaptive checks. Cache wall-time benefit is workload-dependent/unproven; adaptive fixture195→107 score calls with same planned-set action |
| 3 | Episode/action/terminal coverage and actionable failure analysis | Tooling complete: 15 original-source assertions in 4 fixtures, 19 Lua contract checks, 12 report +21 paired tests; frozen2.32 four full attempts retained under runs/development_episodecoverage332 (one loss, two timeouts, one repaired floor assertion error) |
| 4 | Bounded multiple-discard rescue sequences | Installed2.41; 217 checks plus7 runtime publication/execution checks. At most3 first actions,4 outer draws,3 conditional second actions,4 inner draws,24 play proposals,12000 scores. Last playable hand only; publish first discard and refresh |
| 5 | Trading Card/DNA population transitions; Purple generation support | Trading2.32 (28checks+8sourcecases/644); DNA2.33 (33checks+6sourcecases/93); explicit Purple Tarot outcomes/full inventory paths2.36. Unknown free-slot generation still rejects continuation; no invented Tarot pool |
| 6 | Executable blind routing with income/growth/attrition/time costs | Installed2.38; 55 checks +16 source cases/144 comparisons. Four composition samples and>=2x margin for all checked remaining blinds; cash/growth/shop/time tradeoff remains heuristic |
| 7 | Shared sampled Glass/Hook/Heart outcome transitions | APIs2.36/search2.37; nonlinear unbiased-priority sampler and Hook final-score correction2.41; hidden-future rejection and separate effect stream2.42. 42 transition+435 search+823 sampler checks,9Heart/135+7Hook/Purple/100+80draw/161 source comparisons |
| 8 | Versioned strategic weights and bounded paired CPU calibration | Registry installed2.39. Frozen two-candidate screen executed: four3-action prefixes, all censored, identical paired actions/score counts, no qualified gain; defaults retained. See runs/coefficient_screen239/calibration_report.json |
| 9 | Filtered-opening policy/setup/pair/time comparison | Tooling complete: actual frozen native search, exact two frozen Lovely hooks, original skip/sale/Soul callbacks; Omelette/Knife selected-fixture setup and ADVISOR1 no-find under runs/development_filtered339, 10 workflow tests +9 source retention assertions. Knife cannot retain both engines through pinned Dagger; Perkeo survives and first play clears. Core unchanged because pack Souls cannot legally be stored; no win/prevalence/time-to-win claim |

Historical forecasts made before this batch was implemented: ordinary average
~35% (25–45), useful filtered supported subset ~45% (35–55), with prospective
post-batch ~50% (40–60) and ~60% (50–70). These are superseded by the later
read-only audit in NEXT_PRIORITIES_242.md: current ordinary ~35% (20–50) and
projected after six further proposals ~45% (30–60); useful filtered subset
~45% (30–60) → ~55% (40–70). All remain unmeasured subjective judgments, not
test results or confidence intervals. SESSION_RESET_242.md is the current checkpoint.
Neither 50% nor75% per challenge is demonstrated. The implementation must not
claim calibration success without valid matched evidence, or count censored runs
as terminal failures/successes.

## Final installed state and validation

**2.42.0-alpha**, 2026-09-10 17:44:14 CDT; 34 runtime files verified.
Last backup: deployment-backups/advisor-20260910-174414. Each successful runtime
slice was installed during implementation (2.32 through2.42). Config SHA256
15A399DFBE89A1237C76F6BC06CB9173764EFC4BE976FE9DA0243F549AC9741E unchanged;
saves and native DLL unchanged. No game process/window or live action touched.
Activation awaits the user's normal restart.

Full56 Lua fixtures and69 Python tests pass; affected final search/runtime tests
rerun after2.42 corrections. Thirteen source probes pass247 scenarios/4410
comparisons, plus15 phase/terminal assertions and9 filtered-retention assertions
against frozen installed2.42. Source synthetic terminal wins are mechanics tests,
not episode wins. Final frozen digest:
f151758fda0aa885691416abd11a991af49627231dde4144808b7c8f37a2ff70.

Development2.40 ordinary rerun on ADVISORCOVERAGE332: Omelette timed out45s at
Ante2/step54; Golden Needle lost atAnte1 Big,150chips short in15.36s. That interim
selected-seed regression is retained as evidence. Final2.42 with independent
effect sampling reproduces all31 actions and the same Ante2 Small loss608 short
as2.32, taking31.38s versus41.01s (~23% shorter). This is one descriptive losing
trace per version, with differing adapter revisions; no general speedup, win-rate
or time-to-win improvement is established. Final evidence is under
runs/development_final242. Do not pool these versions or filtered starts.
