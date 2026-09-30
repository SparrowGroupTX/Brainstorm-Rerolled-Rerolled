# Authorized next-ten implementation after 2.53

The user authorized implementation of the ranked ten proposals on 2026-09-10.
Baseline: SESSION_RESET_253.md/.json; installed policy is frozen at
runs/development253_installed/policy. All preexisting work remains in place.
No game process/control/executable launch, saves, commits/reset/clean/delete/PR,
training or schedules. Every tested runtime slice is installed with backups;
only the user's normal restart activates it. Tests are not win-rate evidence.

## Scope and progress

1. Shop continuation versus reroll consistency — installed 2.55.
2. Larger-hand exact search cost — installed 2.54, identical-result profiling complete.
3. Explicit evaluation profiles and action-sensitive calibration — tooling complete; profiles remain unqualified for win rates and screens promoted no defaults.
4. Shared supported survival liquidity — installed 2.58.
5. Computation and action costs in build value — installed 2.57; coefficients remain heuristic.
6. Full-row tactical catalog replacements — installed 2.61, including miss funding and scoring corrections.
7. Conditioned concealed observations and invariant decisions — installed 2.56, bounded final-play scope.
8. Broader finishing — three-hand extension installed 2.59; owned-use follow-on and review corrections installed 2.62.
9. Executable start-of-blind copy setup — installed 2.60, source checked and conservatively bounded.
10. Retained filtered engines and total attempt-cost selection — tooling complete; incomplete evidence remains inconclusive, no route promoted.

## Registered bounded evidence

Larger-hand profiling: identical frozen component adapter, baseline 2.53 and a
candidate containing only the tested scoring optimization. Workloads nonclear9,
nonclear10 and nonclear12; three repetitions per cache mode; maximum 20 seconds
per hidden worker, six workers per policy, 240 seconds combined hard caps.
Fresh outputs larger_hand254_before and larger_hand254_after. Record every
timeout/error. Compare exact action, result and evaluation count before making
any timing claim. Synthetic profiling is not a source episode or win evidence.

Installations, exact slices, test results and remaining limits are appended here
as each coherent feature completes. No numeric win forecast is raised by tests.

## Installed 2.54 — exact scoring work reuse

2026-09-10 20:52:09 CDT; backup deployment-backups/advisor-20260910-205208.
Slice: Advisor/scoring.lua and score_cache.lua, version files updated by installer.
41 deployment files verified; settings hash unchanged from253. Reuse only
immutable Joker names/copy routing, and avoid writable copies for cards/Jokers
whose scoring path cannot mutate them. Transition calls keep detached copies.
The main search budget, random draws, finishing and early-stop policy are unchanged.
All72 then-present Lua fixtures pass; 3,130 comparisons against frozen253 cover
scores/floors/transitions and input preservation in mutable/copy rows. Evidence:
runs/scoring254_candidate/regression.log and differential.log.

Both frozen component policies completed all18 decisions each with exactly equal
actions, result fingerprints and evaluation counts. Prepared median9-card time
1.587→1.397s (120,561 scores),10-card1.901→1.804s (141,145 total scores including
specialists). The12-card workload happened to clear in23scores and is a fast-clear
control, not a nonclear result. Three repetitions; inclusive instrumentation and
concurrent host load limit timing claims. No population/general speedup claim.
Comparison: runs/larger_hand254_comparison/report.json.

## Installed 2.55 — complete incumbent continuation comparison

Slice: Advisor/decision.lua, shop_sequences.lua, strategy.lua, paid_reroll.lua.
Every admitted first action retains its best supported complete endpoint, including
the unchanged incumbent; rerolls compare that endpoint and actual net cash spend.
Free Planet uses and sale-first plans participate only with complete matching
evidence. Replan after each user action; no queued execution or extra score budget.
Focused sequence/reroll/runtime checks pass, including unchanged first action,
shifted offers after purchase, free use, sale proceeds and incomplete/mismatch guards.
Agent evidence: runs/shop_continuation254_focus2 (frozen provenance/report/log).
Installed20:52:45CDT; backup deployment-backups/advisor-20260910-205244;
41 files verified and settings hash unchanged. Complete installed freeze:
runs/development255_installed/record.json (all repository files matched then).

## Installed 2.56 — conditioned concealed observations

Slice: Advisor/concealed_belief.lua, decision.lua and runtime.lua; detached source
and profiling adapters wired too. Hidden held/deck identities and deck order are
removed before candidate construction. Mark plus random challenge concealment
uses jointly conditioned weighted subsets. The same observed action is scored
across common worlds; full hidden-assignment permutation invariance is tested.
Supported initial action scope: final hand, zero discards, no held consumables,
at most8 held/120 deck cards, complete16-world comparisons within8,000 scores.
Other hidden horizons are explicitly unavailable instead of latent-identity
advice. UI hides card identities and skips latent strategy/category explanations;
work yields through the ordinary runtime frame budget, Execute remains user-clicked.
300 belief checks plus runtime242checks and related integration fixtures pass.
Original-source probe:240 face/visibility likelihood cases in
runs/concealed254_source_initial; final integration log runs/concealed256_integration.
No measured win gain, and broad concealed finishing remains outside this slice.
Installed20:56:32CDT; backup deployment-backups/advisor-20260910-205631;
42files verified, settings unchanged.

## Installed 2.57 — bounded computation cost and meaningful coefficient hooks

Slice: Advisor/work_cost.lua, shop_scoring.lua, policy_weights.lua, runtime.lua.
Shop/pack/sequence paired evidence now carries a bounded secondary cost for
estimated extra computation, using complete subset counts, existing search caps
and actual next-blind resources. Four opening samples estimate nonclear frequency;
uncertain means receive no optimistic savings. Explicit assumptions:12microseconds
per score from the254profiles, one representative decision per next three blinds,
1.5seconds per user action,2existing utility units per action. Frequency/conversion
remain uncalibrated; preference is bounded±8before its scale coefficient. It does
not alter current search limits or override known strong scoring upgrades.
Schema2 adds bounded shop gain, computation and reroll threshold coefficients.
No fitted default was promoted; existing growth/discard coefficients unchanged.
13cost checks,13coefficient checks and shared shop/runtime/syntax checks pass in
runs/work_cost257_focus. Unsupported readiness receives no fabricated time value.
Installed20:59:47CDT; backup deployment-backups/advisor-20260910-205946;
43files verified, settings unchanged.

## Installed 2.58 — common survival liquidity

Installed21:01:24CDT; backup deployment-backups/advisor-20260910-210123;
44files verified, settings unchanged. Slice: Advisor/liquidity.lua, runtime.lua,
strategy.lua, shop_sequences.lua, conditional_value.lua, paid_reroll.lua.
Buying, completed sequence endpoints, income timing and both reroll paths share
actual debt-relative rental/discard reserves. Unless complete matched finishing
evidence establishes fewer paid discards, every available discard is reserved
conservatively; sampled safe openings alone do not release that reserve. New
liquidity gaps receive a bounded incremental penalty, not a spending prohibition.
Exact Credit Card/Moon purchase resource changes are shared rather than duplicated.
Moon interest uses post-payment cash after conservative reserved costs; delayed
income cannot pay for its own purchase. Safe worthwhile investment remains tested.
Reroll minimum target gain now consumes the schema2 numeric coefficient.
25new liquidity checks plus existing conditional/shop/reroll/runtime tests pass;
source purchase/debt/interest parity13cases156comparisons passes. Agent frozen
evidence runs/liquidity256_focus2 and liquidity256_source1; initial failed fixture
attempt liquidity256_focus1 retained. Installed freeze runs/development258_installed.

## Installed 2.59 — bounded three-hand final-discard extension

Slice: Advisor/two_hand_finish.lua, decision.lua, runtime.lua. The same12,000-score
specialist allowance now admits three remaining hands only when hand size<=6 and
the ordinary comparison completed the full three-hand baseline without a sampled
certain finish. A middle play is selected from its observed hand, then exact
scoring/population/resource transitions feed the conditional final redraw. Unknown
middle effects invalidate the entire comparison. Existing two-hand8-card behavior
and70-score fast-clear path are preserved; no general joint-consumable optimizer
or additional score budget. A controlled acceptance case demonstrates the missing
save-discard-across-middle-hand decision; it is not a source episode win.
264finishing checks pass, including actual3-hand scoring in796evaluations/eight
middle transitions and the unchanged two-hand9600-score case. Runtime/routing and
fast-clear fixtures pass. Retained log: runs/three_hand259_focus1/validation.log.
Installed21:04:22CDT; backup deployment-backups/advisor-20260910-210421;
44files verified, settings unchanged. Independent review subsequently found missing
middle-play indices in held-card rewards; correction is installed in2.62 with the
owned-consumable follow-on slice. Loaded game remains untouched/unknown.

## Installed 2.60 — executable startup copies

Installed21:13:48CDT; backup deployment-backups/advisor-20260910-211348;
44files verified, settings unchanged. Slice: Advisor/blind_prep.lua, runtime.lua,
shop_scoring.lua. Bounded complete one-insertion families (<=57orders) can improve
supported Burglar copying and narrowly supported Marble/Hologram investment.
Pins, protected/exact Dagger victims, native scoring order and existing scoring
copy targets before/after sacrifice are preserved. Actual preblind suggestions
and shop projections follow the same fixed executable chain; no free later
restoration or per-draw setup is assumed. UI shows actual proposed Joker order.

Review rejected a product-of-Hologram-ratios score-floor assumption. Marble now
credits only a terminal native Hologram multiplier with no later additions,
held consumables, Plasma/balance/cash caps/cash-hand-size/Erosion; explicit
incompatible startup copies decline. The continuous_opening_ratio is a bounded
heuristic, not a rounded-score floor/readiness or clear claim. Startup card
generation remains stochastic in actual tactical readiness.
59copy checks,34Dagger/49startup checks,30shop projection checks and runtime
integration pass. Source44cases917comparisons including6actual proposals pass in
runs/blind_copy254_source_release; integrated logs blind_copy260_integration1/2.
Nonzero shop-gain/work coefficient opportunity counters also installed, with
14work-cost checks; future calibration can reject zero-effect checkpoints earlier.

## Completed tooling — explicit profiles, checkpoint screens and filter costs

CALIBRATION_FILTER_TOOLING_258.md records new named source-profile audit/durable
pre-episode inventories, verified meaningful checkpoint coefficient screens and
filtered_route_selection.py. All129Python tests pass at its checkpoint. Full
source flag profiles are distinct declared populations, never the user's profile
or a qualified adapter. Two fresh258screens completed; both retained unchanged
actions and no numeric defaults were promoted. First screen's zero tactical
comparisons exposed weak admission, which was tightened; all artifacts retained.
The second had11paired comparisons but still bought the same actual Crafty Joker.

Filter tooling reaudits all misses, attrition, unresolved runs and total costs,
requires terminal matched cohorts before even a diagnostic seconds/win comparison,
and provides explicit bounded one-more-search cost scenarios. Historical252cohort
remains inconclusive; no new filter campaign/native default promotion, Jokerless
excluded. No measured win forecast follows from this program.

## Installed 2.61 — full-row catalog replacements and missed refreshes

Installed21:21:45CDT; backup deployment-backups/advisor-20260910-212145;
44files verified, settings unchanged. Slice: Advisor/strategy.lua, paid_reroll.lua,
decision.lua. Complete legal victim sets are admitted before scoring, within a
six-entry shortlist, at most twelve victim comparisons and the shared50kshop cap.
Refresh cash is paid before contingent sale/purchase; debt, Negative capacity,
preservation, liquidity and unsupported sale effects are checked. The miss retains
the owned row and its reserve obligations. One lazy complete paired miss comparison
charges cash-sensitive scoring losses; positive speculative growth receives no
credit. Incomplete/unknown comparisons invalidate the tactical forecast.

Candidate, victim and miss diagnostics remain reviewable even for rejected advice.
Ten scoped fixtures641checks pass, including real Bull/Duo miss loss, plus root
five-fixture297check routing/presentation integration. Source sale/purchase parity
20cases296comparisons remains applicable because those transitions are unchanged.
Evidence: runs/catalog_replacements259_miss2, catalog_replacements259_source1,
reroll261_integration. Independent review found no further material issue.
SHOP_COMPARISON_FOLLOWUP_259.md retains initial failed fixtures and corrections.
Bounded shortlist omissions, independent offer approximation and four target-clipped
opening samples remain heuristic; this is not a blind-win probability model.

## Installed 2.62 — owned upgrades within conditional finishing

Installed21:23:47CDT; backup deployment-backups/advisor-20260910-212347;
44files verified, settings unchanged. Slice: Advisor/two_hand_finish.lua, runtime.lua.
At most two actual zero-target Planet/BlackHole alternatives are admitted for
current/configured hands<=6, within the unchanged12kspecialist allowance. Exact
uses compare against the best complete no-use branch on common conditional worlds.
Whole inventory/Negative/Observatory preservation and an explicit use-action cost
are charged; last protected Perkeo sources never enter sampled rescue. All offered
items retain reasons. Unknown admitted use or incomplete scoring invalidates the
entire comparison; >2eligible items declines that use family before cloning.
UI names the actual inventory slot and requests fresh advice after its one use.

Middle-play indices are attached before Gold/Blue held-card rewards, and an empty
post-middle population is recorded as a loss. Existing current-clear, tactical,
investment and finite-population protections remain. This is greedy observed play
plus optional final redraw, not general joint-consumable or guaranteed finishing.
Independent review found no material issue. New93checks; six-fixture815check root
integration passes. Actual later-Pair upgrade requires787scores; six-card3hand/two
upgrades8340; old8card2hand9600 unchanged. Evidence: owned_finish_followon_frozen,
owned_finish262_integration2. Initial root integration retained a missing fixture
path error before tests in owned_finish262_integration; no artifact deleted.

## Final complete installed validation

runs/development262_installed/record.json freezes the complete installed2.62 policy:
all58product/dependency files match repository/installation, including the44-file
deployment. Digest60ededca68ab3e5ff10c655b4a0351b0df82b4bec498bd67ed4f7f09b159f98b.
runs/development262_validation/report.json records80/80Lua fixtures and129Python
tests passing under separate60s hidden-worker caps (9.094s/5.859s). Runtime and test
hashes unchanged. No game/saves touched, native/settings unchanged; normal restart
activation only. SESSION_RESET_262.md/.json and NEXT_PRIORITIES_262.md are current.
Allten bounded areas complete; no successful numeric tuning, filtered promotion
or measured episode win-rate increase. Preserve all prior errors/censors/evidence.
