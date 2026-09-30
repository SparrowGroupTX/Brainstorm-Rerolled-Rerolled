# Six follow-on interventions after 2.42

Updated 2026-09-10. This is a new work ledger, not a repeat of the completed ten-
or nine-intervention batches. Latest checkpoint: SESSION_RESET_246.md/.json.

## Installed runtime

| Version | Tested slice | Installed local time | Backup suffix |
|---|---|---|---|
| 2.43.0-alpha | Revealed Buffoon comparisons, readiness/Planet purchases, conditional payback | 2026-09-10 18:46:31 CDT | advisor-20260910-184630 |
| 2.44.0-alpha | Paid rerolls use actual-blind readiness/resource restrictions | 2026-09-10 18:47:56 CDT | advisor-20260910-184755 |
| 2.45.0-alpha | Correct post-boss next-blind metadata and pack forecast capture | 2026-09-10 18:49:57 CDT | advisor-20260910-184957 |
| 2.46.0-alpha | Nonpositive rental payback guard and whole-row rental interest basis | 2026-09-10 18:55:51 CDT | advisor-20260910-185550 |

All backups are under C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/
deployment-backups. Each slice used install_slice.py, preserved the configuration
hash and verified all 35 deployment files. No game process/window or saves were
accessed. Running loaded version is unknown; activation awaits normal user restart.

## 1. Revealed Buffoon scoring — implemented

decision.lua opens the same bounded shop_scoring context for actual Joker packs.
strategy.lua compares every actual offered Joker and every supported legal one-
sale replacement. Selection is free; cash, negative slots, Eternal/pinned cards,
charged Invisible, retained synergies and Typecast restrictions still apply.
All offers, blocked replacements and completed/unsupported tactical comparisons
are recorded. A missing or truncated legal comparison discards tactical scoring
for the entire pack decision, retaining attempted evidence separately.

New fixture: advisor_pack_scoring.lua, 33 checks. Real reviewed pack at step 6 of
ADVISORCOVERAGE332 offers Baseball Card and Devious; both 2.42 and 2.43 choose
Devious. This closes the missing-offers evidence gap, not a demonstrated win gain.

## 2. Next-blind readiness — implemented bounded scope

The shared scorer exposes four actual-blind composition opening samples, hand/
discard resources, selected hand types/sizes and opening scores. A comfortable
sampled opening clear can preserve investment. A generous repeated-opening
pressure proxy can identify sampled deficits; it is explicitly NOT a global
score bound, finishing sequence, or survival probability. Multi-hand/discard
plans remain unresolved. Concealed openings and unknown/random effects cannot
establish readiness. Complete cached comparisons reuse the baseline work.

Affordable immediate scoring gets urgency when the sampled build is deficient;
known income/growth that leaves that deficit gets a spending discount. Planet
purchase/use previews use the existing exact consumable transition and preserve
whole-inventory Perkeo/Observatory holding roles. Paid rerolls now respect actual
boss hand restrictions instead of multiplying by unmodified reset hands.

Replay exposed incorrect preexisting next-blind capture after reset_blinds had
made all labels Upcoming in a post-boss shop. 2.45 follows the source selection
predicate (Defeated/Skipped/Hide), captures pack metadata and projected ante.
The old 2.43 step 22 diagnosis used Big1200 where actual Small800 followed; retain
that evidence but use corrected 2.45 comparisons for interpretation.

New advisor_readiness.lua: 24 checks. Paid reroll fixture 49, snapshot90 checks.

## 3. Conditional payback — implemented bounded scope

conditional_value.lua separates trigger opportunities, cash timing, rental,
expiration, interest and purchase payback. Supported Golden/Rocket/Cloud9/
Satellite/To the Moon and Delayed Gratification payouts use source mechanics.
Delayed Gratification receives no budgeted payout when sampled scoring pressure
provides no credible no-discard route; this does not prove discards necessary.
Unknown conditional income exposes missing opportunities instead of inventing
cash. Egg/Gift resale is distinct from liquid income; existing engine synergies
remain. Selected immature growth is discounted under immediate pressure;
safe growth, Perkeo, Kings, Yorick/Burnt and finishing plans remain intact.

New advisor_conditional_value.lua: 97 checks; advisor_income_pack_regression.lua:
9 checks.2.46 rejects pure income investment with nonpositive net rental cash,
counts all owned rent before Moon interest, and still allows scoring editions to
repair a deficit. Final frozen original-source probe:
runs/conditional_value246_source/report.json, 26 cases/80 callback comparisons
passed. Earlier2.43 evidence is preserved. No user saves are involved.

## 4. Verified replay/calibration — tooling implemented, defaults unchanged

Replay bypass and action-sensitive checkpoint tooling implemented; bounded2.45
comparisons complete. Prefixes retain source fingerprints, frozen policy/
adapter provenance, phase/legality, score prediction and post-action invariants.
Skipped advisor work is explicit and diagnostics are not fabricated. Canonical
fingerprints use the verified source policy snapshot implementation so candidate
snapshot corrections do not masquerade as source game-state divergence.

VERIFIED_REPLAY_245.md records source/admission/corruption evidence and commands.
Actual pack Baseball/Devious stays Devious. At corrected Small800 shop22 the
candidate saves$4/one purchase. Both bounded continuations still lose608 short.
Final ordinary2.46 from-start ADVISORCOVERAGE332:34.410s, 30 actions, same Ante2
loss608 short/$-2; first 21 actions match2.42, first divergence is the removed
purchase. Artifact runs/development246_selected_episode/report.json. Fresh
REPLAY245HOLDOUT1 also loses identically before reaching a shop. These outcomes
do not establish calibrated coefficients, win gain or general performance.

## 5. Repeated computation — profiler implemented; no speculative cache expansion

Readiness reuses complete shop profiles and exposes deterministic request/hit/
comparison counters. runs/component_profile243/report.json contains six workers/
18 synthetic decisions across safe shop, weak full shop and nonclear. All paired
input/action/result fingerprints and score counts match. Plain→cached medians:
.040→.035s,.035→.036s,.254→.231s. Scoring dominates; benefit varies by workload.
No broad performance claim or new runtime memoization is justified. Six profiler
protocol tests pass; exact-score reuse still needs complete invalidation proofs.

## 6. Retained filtered engines — bounded comparison implemented

filtered_engine_compare.py and 13 focused tests cover registered Any/target filters,
misses, search/setup cost, actual later retained engines and native continuation
chains. No runtime/native filter changed. Jokerless remains excluded.

runs/filtered_engines245_fresh and filtered_engines245_continuation preserve eight
bounded cells: seven misses and one fresh Any Canio/Yorick setup. Canio is consumed
on Big entry, Yorick on Boss entry. Dagger retains+20/+40/+44/+48/+52 Mult in
observed rounds 1–5. Five cashouts,40-action censor; no terminal win. Final aggregate
chain_summary_final.json freezes aggregation_workflow.py, checks native next-seed
links and includes all 8.862s of attempt costs. One found Any and no found Perkeo
cannot establish a preferred filter or population acquisition/retention rates.

## Validation and claims

Final validation logs/manifests: runs/development246/validation/report.json.
60 Lua fixtures and 99 Python tests pass; exact logs are saved there. The conditional
source probe passes 26 cases/80 comparisons. All35 final runtime hashes match.
All scoped agents finished; no runtime/tooling test or simulation remains pending.
No measured win-rate gain, per-challenge rate or50%/75% target is established.
Do not mechanically revise the subjective2.42 planning estimates from test counts.
