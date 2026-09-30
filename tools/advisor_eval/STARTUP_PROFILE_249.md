# Installed 2.49 startup scoring cost audit

Later status: 2.53 restricts startup forecasts to actual published preparation
orders and protected victims. These frozen 2.49 timings remain historical and do
not establish the corrected policy's current cost or source behavior.

The new Dagger and Marble tactical work completes within the existing 50,000-score
shop budget on this bounded synthetic cohort. It costs more than the 2.46 fallback,
which performed no tactical scoring for these rows. This is new supported work,
not a speedup. No new runtime cache or budget change follows from this audit.

## Frozen evidence

- Installed 2.49 freeze: `runs/startup_profile249_installed/policy`; digest
  `3f419a355ca2394e5dfe1a4b96f2837c19a07ebaf89a483522f33006ef6fec19`.
  The repository was already changing for subsequent slices, so only the installed
  bytes were profiled. Its record identifies backup `advisor-20260910-194938`.
- Reference: frozen 2.46 `runs/development246/policy`; digest
  `8dfb1955a4ced9491eaba8bdc0960b3edb66076bd888cb27d758f8946beee102`.
- Final profiles: `runs/startup_profile249_current2` and
  `runs/startup_profile249_baseline246`. Both use the identical frozen adapter
  digest `2ae3909c145b551f7135acf4f70806297532c35333a8ae57ec93c880f4d7b679`.
- Audited comparison: `runs/startup_profile249_comparison/report.json`, with a
  frozen copy and hash of `compare_component_profiles.py`.
- Each policy has four registered synthetic workloads, two classification-cache
  modes, five repetitions per worker and a 20-second worker limit: 80 final
  decisions in 16 workers. All completed; no final timeouts, unsupported scorer
  identities, or shared-budget truncations occurred. Marble readiness remains
  intentionally unsupported because uncertain generation cannot prove survival.

The initial 40-decision pilot is preserved in `runs/startup_profile249_current`.
Its Dagger fixture used the display spelling `Canio` instead of the source internal
identity `Caino`, so that row correctly fell back with an explicit unsupported
warning. The fixture was corrected before both final policies were measured.
That pilot is not silently counted as supported Dagger evidence.

## Timing and completeness

These are instrumented Lua `os.clock` milliseconds, not game/UI latency. Each
p95 is the maximum of only five repetitions; it is not a population tail estimate.

| Workload | 2.46 cache on median/p95 | 2.49 cache on median/p95 | 2.49 cache off median/p95 | 2.49 scores |
|---|---:|---:|---:|---:|
| Weak full shop | 32 / 41 | 46 / 65 | 45 / 46 | 3,488 |
| Dagger full shop | 6 / 6 | 374 / 382 | 309 / 367 | 29,648 |
| Marble full shop | 8 / 9 | 190 / 200 | 214 / 236 | 18,312 |
| Dagger + Marble full shop | 7 / 9 | 304 / 332 | 333 / 347 | 29,648 |

Within each frozen policy and workload, all cache-on/off repetitions match the
complete action/result/input fingerprints and score counts. Existing cache use
helps some timings and hurts others; these results do not establish a general
speedup. Across versions, full result fingerprints differ because the supported
work and diagnostics changed, so the comparison tool correctly marks all four
cross-version speed claims ineligible. Weak-full-shop actions and score counts
match, but 2.49 also checks the short visible shop sequence graph.

Dagger and Dagger+Marble advice changes from selling the Egg to buy Runner to
saving; Marble still sells the Egg for Popcorn. These are synthetic decisions,
not wins or evidence that a Legendary engine survives a real attempt.

## Components and reuse

| 2.49 workload | Completed profiles | Profile cache hits / requests | Classification hits / calls | Median score time share | Startup projection share |
|---|---:|---:|---:|---:|---:|
| Weak full shop | 4 | 8 / 12 | 2,628 / 3,488 | 70.3% | 0% |
| Dagger | 9 | 11 / 20 | 28,788 / 29,648 | 66.9% | 3.5% |
| Marble | 13 | 13 / 26 | 17,450 / 18,312 | 63.0% | 3.2% |
| Dagger + Marble | 9 | 11 / 20 | 28,786 / 29,648 | 66.2% | 3.3% |

Repeated preparation exists, but startup projection takes only roughly 6–13 ms
per decision here. A new preparation cache would need the full detached state,
next blind, resources, population identities, temporal assumptions, fixed startup
layout, and sample index; it could not share mutable score states or incomplete
comparisons. The small measured ceiling does not justify introducing that
invalidation burden now. High classification hit rates do not prove duplicate
complete scores; no whole-score memoization benefit was demonstrated.

The profiling loader now includes optional installed blind-start, paired-population
and shop-sequence modules. Explicit workload selection is bounded to four distinct
registered workloads; the previous three default workloads remain unchanged.
Seven profiling protocol tests pass, including missing/incomplete comparisons,
deterministic complete-result pairing, frozen provenance and registration bounds.

No runtime files, saves or game process/window were changed by this audit. Original
game source was not needed. Only isolated `lua51.dll` workers ran. Synthetic inputs,
instrumentation overhead and this small cohort do not qualify win-rate, real-time
completion, or filter-promotion claims.
