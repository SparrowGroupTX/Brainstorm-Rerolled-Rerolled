# Current startup scoring costs — installed 2.53

One bounded current-policy run is complete at `runs/startup_profile253_current`.
It profiles the corrected published preparation order, with `Shop.blind_prep`
and `Shop.strategy` injected exactly as in the current runtime. The older 2.49
profiles and 2.52 filtered/source attempts remain historical; no source episode
or filtered cohort was rerun for this audit.

The policy was copied from `runs/development253_installed/policy`, never from
concurrently edited repository files. Policy digest:
`85d07ffe2635d1dd456bf15def404330c4e4eb66da2bcd40059a3d525c4365e9`.
Frozen profiling-adapter digest:
`985f23143db9668a567018089c51649866a88c7baf785f1eab30c5f7c330d52e`.
Manifest digest:
`a5f11b4a09d495766477630b56ec201c8f1372c6828a6ad3bdd864c40eda971f`.

Four registered workloads, two cache modes and five repetitions produced 40
decisions in eight hidden workers, each capped at 20 seconds. Every worker
completed. All four cache-on/off pairs match full input/result/action fingerprints
and scoring counts; none exceeded the existing shared scoring budget.

| Workload | Cache on median/p95 ms | Cache off median/p95 ms | Scores | Profile hits / requests |
|---|---:|---:|---:|---:|
| Weak full shop | 37 / 41 | 36 / 46 | 3,488 | 8 / 12 |
| Dagger full shop | 103 / 139 | 143 / 150 | 7,848 | 11 / 20 |
| Marble full shop | 144 / 176 | 199 / 213 | 11,336 | 13 / 26 |
| Dagger + Marble | 97 / 111 | 105 / 121 | 7,848 | 11 / 20 |

These are instrumented Lua timings. With only five repetitions, p95 is simply
the observed maximum. No cross-version speedup is inferred because 2.53 changes
which preparation actions the forecast may assume. Scoring remains 53–58% of
startup workload time; startup projection itself is roughly 1.6–3.2%. Existing
reuse is retained; this audit introduces no runtime cache or larger budget.

The Dagger workload leaves the shop with sampled-safe opening evidence. Marble
still sells its Egg for Popcorn; Dagger+Marble saves. Both Marble readiness results
remain explicitly unsupported as survival claims because generated population
samples are uncertain. Those labels do not mean their tactical comparisons failed.

The unchanged `blind_start.lua` bytes still match source parity artifact
`runs/blind_start247_source2`: 32 fixed callback cases/641 comparisons cover ordered
destruction, copied Burglar/Marble, sliced actors, growth and resource removal.
That callback parity does not by itself prove the advisor publishes a forecast
layout. The separate current `tests/advisor_shop_start.lua` integration cases now
check the actual published Dagger preparation, mature Canio and Perkeo protection,
one shared victim across all samples, and no invented Blueprint move to obtain
additional Burglar hands. Non-Dagger startup retains the actual observed row.
No new source episode evaluates the corrected 2.53 policy here.

Seven profiling protocol tests pass, including a frozen-loader modification
rejection. Game windows/processes and saves were untouched. Only isolated Lua
workers ran; synthetic profiling results are not wins or win-rate evidence.
