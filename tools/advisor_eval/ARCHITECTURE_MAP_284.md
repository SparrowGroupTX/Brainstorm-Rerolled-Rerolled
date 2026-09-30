# Current architecture update284

This leading update supersedes current-state or pending wording in the preserved navigation below. Current checkpoint: `SESSION_RESET_284.md`; priorities: `NEXT_PRIORITIES_284.md`.

Installed checkpoint: **2.84.0-alpha**, 2026-09-13T15:37:33.3163680-05:00.
All 52 deployment and 67 frozen product/dependency files match repository and installation.
Candidate and exact-installed full regression: **116 Lua fixtures / 275 Python tests pass**, unchanged frozen policy and tests; 60s cap per suite.
Policy digest: `a15ddcf39ba25b37fd1f8ef095b0f60bd2eb4b8daf0cbb98800230185423acb4`.
Backup: `C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260913-153732`.
Current settings and both native DLLs were preserved. Running-game loaded version is unknown; activation waits for the user's normal restart.

284 adds complete bounded observed hand/discard policies for formerly unsupported no-Joker scopes, including five hands and ten cards, legal same-cards plays, later redraws and supported Lucky. Every policy receives four common worlds; unknown mechanics or incomplete work still decline the comparison. Declared policy exhaustion is explicit and is not a source terminal loss. The274 crossed-world guard, actual resources, Glass/population and Blue inventory rewards remain. Synthetic coverage only: no preserved decision or complete run was re-executed. See POSTMORTEM_ACTIONS_284.md, POSTMORTEM_METHOD_282.md and COHORT_PROGRESS.md. User now also requests Jokerless search acceleration against the fast normal reroll path; code inspection finds Lua-only search does unnecessary work after failed required conditions. That acceleration is under development, with no new search authority or benchmark executed.

Current changed-source/test/component map: `RESOURCE_FINISH_284.md`. The earlier component map remains useful for unchanged areas; its version and evidence claims are historical. No new experiment authority follows from this map.

---

# Current architecture update283

This leading update supersedes current-state or pending wording in the preserved navigation below. Current checkpoint: `SESSION_RESET_283.md`; priorities: `NEXT_PRIORITIES_283.md`.

Installed checkpoint: **2.83.0-alpha**, 2026-09-13T15:18:42.7530357-05:00.
All 51 deployment and 66 frozen product/dependency files match repository and installation.
Candidate and exact-installed full regression: **115 Lua fixtures / 275 Python tests pass**, unchanged frozen policy and tests; 60s cap per suite.
Policy digest: `acd130de0025894bae601f976e2c8ab9d7981eb12572f592083dbf85efcf1426`.
Backup: `C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260913-151842`.
Current settings and both native DLLs were preserved. Running-game loaded version is unknown; activation waits for the user's normal restart.

283 connects supported no-Joker Lucky score and cash outcomes to complete shop and blind forecasts. Every uncertain opening candidate is checked; future actions are chosen before private outcomes, and the final play uses an actual sampled transition. Unsupported mechanics and stochastic startup remain excluded. Routine synthetic evidence establishes comparison coverage, not a rescued run. Read-only cohort reporting is also implemented in cohort_progress.py with COHORT_PROGRESS.md: full unresolved denominators, paired outcomes, explicit milestone/skip coverage and conditional conservative intervals; no simulations or coefficient tuning were run.

Current changed-source/test/component map: `BLIND_LUCKY_283.md`. The earlier component map remains useful for unchanged areas; its version and evidence claims are historical. No new experiment authority follows from this map.

---

# Advisor architecture â€” current282 map

Read SESSION_RESET_282.md and NEXT_PRIORITIES_282.md for current release/evidence
and closed budgets. This map includes the existing source/test/component table
from281 plus the282 Lucky slice; earlier historical records remain intact.
Latest installed receipt: runs/lucky282_installed/record.json. Final exact-installed
regression:114 Lua/253 Python, all51 deployment/66 frozen files match.

## Objective and product boundary

The objective is a deterministic advisor minimizing expected real time to
finish **all 20 challenges**, including failed attempts, retries, opening/filter
work, computation and user actions. The 50% and 75% targets apply to each
challenge individually; neither has been demonstrated. Recent work emphasizes
Jokerless, with earlier Knife's Edge failures motivating generic Dagger,
generator and resource repairs. It does not replace the all-20 objective or
prove the broader top-ten improvement roadmap complete.

The product reads public observations, computes advice and exposes a separate
user-clicked Execute action. It replans after actual state changes. It is not a
live gameplay bot, a whole-run solver or a hidden-RNG oracle. Unknown mechanics
remain unsupported/review-only where no complete admissible comparison exists.

## Runtime flow

1. `Brainstorm/Advisor/snapshot.lua` captures public cards, remaining composition,
   inventory, resources, boss/history metadata and observation identity.
   `runtime.lua` schedules bounded work and rejects stale observations/callbacks;
   `execution.lua` validates and performs only an accepted user-clicked action.
2. `decision.lua` is the shared detached entry point. Non-hand decisions consult
   a matching opening recipe, exact blind preparation, then strategic/tactical
   shop or pack planning and blind routing. Unsupported/partial tactical families
   fall back as a whole; partially explored endpoints are not promoted.
3. Hand decisions use the concealed-belief path when applicable, otherwise
   `search.lua` plus the common scorer. A reliable fast clear takes bounded
   conservation/development/growth checks and bypasses expensive specialists.
   Nonclear decisions may use bounded consumable, order, rescue, discard and
   finishing specialists, each with its own admission and completeness rules.
4. The manual retry policy can reuse an already complete eligible comparison
   after a reported losing line. It adds no scoring calls or samples. UI and
   Execute remain bound to the observation, generation, epoch and run identity.

## Implemented component/source/test map

Runtime modules in this table are under `Brainstorm/Advisor/` unless a full
path is given. Lua fixtures are under `tests/`. These are representative focused
tests; the final checkpoint's frozen full-suite manifest is authoritative.

| Area | Implemented behavior / source | Focused tests and notes |
| --- | --- | --- |
| Observation, UI and execution | `snapshot.lua`, `runtime.lua`, `execution.lua`, `decision.lua`; `Brainstorm/UI/advisor.lua`. Ordinary discard backs remain known through actual area membership and the source concealment marker; genuinely concealed identities stay guarded. | `advisor_snapshot.lua`, `advisor_runtime.lua`, `advisor_decision_integration.lua`, `advisor_discard_visibility.lua`, `advisor_ui.lua`; `DISCARD_VISIBILITY_266.md`. |
| Private Lucky continuation outcomes | `scoring.lua`, `sampled_outcomes.lua`; `search.lua` diagnostic label. No owned Jokers; complete physical-ID/repetition-keyed Mult/cash outcomes enter only detached after_play. Ordinary means/bounds and future action choice remain unsampled. Hook/cash/hand-size/Glass supported; incomplete/unknown events fail closed. | `advisor_lucky_continuations.lua` (632 checks, synthetic183-call complete comparison), `advisor_sampled_search.lua`, `advisor_sampled_transitions.lua`; `LUCKY_CONTINUATIONS_282.md`. |
| Exact scoring and reuse | `scoring.lua`, `score_cache.lua`, `ordering.lua`, `hand_ordering.lua`, `synergies.lua`. Supported scores, uncertainty/bounds, Joker/card order and narrow proven order equivalence; immutable result reuse. Unsupported effects are not silently exact. | `advisor_score_cache.lua`, `advisor_ordering.lua`, `advisor_hand_ordering.lua`, `advisor_final_order_priority.lua`; `FINAL_ORDER_269.md`, `GENERATOR_RESCUE_269.md`. |
| Immediate hand and resource search | `search.lua`, `draws.lua`, `sampled_outcomes.lua`, `multi_discard.lua`. Deterministic candidate/draw comparisons, finite known population, ordinary deck-back normalization and larger-hand bounded fallback. No-Joker/no-Observatory crossed-world guards prevent an incomplete future-discard model from vetoing a discard solely on aggregate play-now utility. | `advisor_resource_decisions.lua`, `advisor_resource_guard.lua`, `advisor_rank_draw_targets.lua`; `RANK_DRAW_TARGETS_276.md`. |
| Rank/Flush development coverage | Search represents upgraded Straight/Flush and Four/Five of a Kind draw targets using finite remaining rank/suit counts. At most two existing discard-list slots are reused, preserving size representatives and the incumbent. Exact without-replacement draw-completion probabilities are not blind/run odds. | `advisor_rank_draw_targets.lua`; `VISIBLE_DEVELOPMENT_271.md`, `RANK_DRAW_TARGETS_276.md`. |
| Reliable-clear conservation | `search.lua`, `finish_rewards.lua`. Existing removal/Glass proposals precede up to eight single-card exchanges within the same conservation allowance. Rank/Flush-compatible replacements get priority, then other actual scored legal exchanges. Psychic still requires five played cards. Population, Glass, Arm and whole-inventory finishing rewards retain precedence. | `advisor_fast_clear.lua`, `advisor_fast_clear_retention.lua`, `advisor_finish_rewards.lua`, `advisor_population_conservation.lua`, `advisor_glass_population.lua`; `CLEAR_RETENTION_279.md`. |
| Growth and finishing | `growth.lua`, `deck_development.lua`, `spectral_development.lua`, `consumables.lua`, `two_hand_finish.lua`, `boss_rescue.lua`, `mixed_rescue.lua`. Supported owned-card transitions, exact Yorick/Burnt effects, Kings Strength/Death development, safe investment and bounded two/three-hand or combined rescues. | `advisor_growth.lua`, `advisor_consumables.lua`, `advisor_owned_finish.lua`, `advisor_two_hand_finish.lua`; specialist admission code owns precise limits. |
| Concealed play/history | `concealed_belief.lua` jointly assigns hidden held and unknown nondrawable cards, conditions future public observations and retains held-consumable scoring. Immediate fixed-slot comparisons can extend through bounded public discards/continuations. | `advisor_concealed_belief.lua`, `advisor_concealed_continuation.lua`; `CONCEALED_CONTINUATION_263.md`. |
| Revealed pack/shop decisions | `strategy.lua`, `pack_scoring.lua`, `shop_scoring.lua`, `paired_deck.lua`, `shop_sequences.lua`, `catalog_joker.lua`. Supported full-row replacements, actual paid endpoints, visible consumable/sale/buy sequences and complete revealed-Planet dominance. Equal-history Planet credit is narrowly bounded and requires complete paid comparisons. | `advisor_pack_scoring.lua`, `advisor_nonjoker_pack_scoring.lua`, `advisor_shop_sequences.lua`, `advisor_shop_planet_commitment.lua`, `advisor_shop_planet_ties.lua`; `PLANET_COMMITMENT_269.md`, `PLANET_HISTORY_TIES_273.md`. |
| Pack Fool and generators | `pack_scoring.lua` projects a source-supported Fool as one fresh editionless held Tarot/Planet; it never invents an immediate use of the copy. Catalog, forced-key bans, capacity, pricing/usage and whole-family fallback are guarded. `consumables.lua` can reveal an owned Emperor/Priestess/Judgement in narrowly admitted final-hand rescue situations without inventing its generated identity. | `advisor_pack_fool.lua`, `advisor_generator_rescue.lua`, `advisor_judgement_rescue.lua`; `FOOL_PACK_278.md`, `GENERATOR_RESCUE_268.md`, `GENERATOR_RESCUE_269.md`. |
| Economy, survival and cost | `conditional_value.lua`, `liquidity.lua`, `paid_reroll.lua`, `blind_finishing.lua`, `work_cost.lua`, `policy_weights.lua`; shared cash/rental/discard constraints, conditional payback and complete endpoint survival comparisons. Time/value coefficients remain heuristic. | `advisor_conditional_value.lua`, `advisor_liquidity.lua`, `advisor_paid_reroll.lua`, `advisor_shop_survival.lua`, `advisor_readiness.lua`; `WHOLE_BLIND_FORECAST_263.md`. |
| Blind entry and preparation | `blind_prep.lua`, `blind_start.lua`, `blind_routing.lua`. Ordered Dagger protection and supported startup copies/Chicot remain. Exact ordinary main-hand Planet use is allowed before shop/blind actions; 281 additionally considers already-played secondary hands only at blind selection, after main-hand priority. No Jokers/Observatory; Negative/Fool/preservation/resource guards remain. | `advisor_blind_prep.lua`, `advisor_blind_copy_setup.lua`, `advisor_chicot_start.lua`, `advisor_planet_preparation.lua`; `PLANET_PREPARATION_275.md`. |
| Jokerless opening product | `Brainstorm/Core/jokerless_opening.lua`, `jokerless_search_runtime.lua`; `Brainstorm/UI/challenge_opening.lua`. Private source-matched RNG/catalog search and visible-step recipe. Default `four_kind` selects Mars; `flush` selects Jupiter; both need Coupon, Telescope, two Blue seals including one Steel. Old `two_blue`/`blue_steel`/`three_blue_steel` IDs and metadata-absent Saturn recipes retain legacy behavior. | `advisor_jokerless_opening.lua`, `advisor_jokerless_planet_targets.lua`, `advisor_jokerless_search_runtime.lua`, `advisor_jokerless_source_recipe.lua`, `advisor_challenge_opening_ui.lua`; `JOKERLESS_OPENING_271.md`, `JOKERLESS_SOURCE_MECHANICS_277.md`. |
| Declared opening purchase financing | `Core/jokerless_opening.lua` has a narrow complete one-card cash bridge for an already-declared visible purchase. It can buy/sell eligible free ordinary off-target Planet stock to fund Telescope; actual cash, cost, resale, room, identity, no mixed held inventory/Jokers/Observatory/modifiers and protected target rules apply. Every first action is replanned; no general spend/sell dominance is claimed. | `advisor_cash_bridge.lua`; push `root_component05_cash_bridge` evidence and final 280/281 checkpoint. |
| Other challenge opening filters | `Brainstorm/Core/challenge_opening.lua`, `Advisor/challenge_route.lua`, shared opening UI; native source `Immolate/src/challenge_opening.cpp`, `immolate.hpp`. Two opening Legendaries plus one optional later vanilla Rare offer by Ante 2â€“8, under declared route/pool/rule conditions. Jokerless has its separate Planet route. | `advisor_challenge_opening.lua`, `advisor_challenge_later.lua`, `advisor_challenge_route.lua`; `LATER_TARGETS_265.md`, `NATIVE_LATER_265.md`, `CHALLENGE_LATER_CORE_UI_265.md`. |
| Five-report manual retry | `retry_memory.lua`, `retry_journal.lua`, `retry_policy.lua`, runtime/decision/UI integration. Public first-action ledger, guarded persistent metadata and deterministic alternatives from complete existing comparisons. | `advisor_retry_memory.lua`, `advisor_retry_journal.lua`, `advisor_retry_policy.lua`, `advisor_runtime.lua`; `RETRY_CHECKPOINTS_270.md`, `RETRY_EVAL_270.md`. |

## Important bounds and support limits

- Ordinary search: at most 140,000 score evaluations. Shared shop allowance:
  50,000; ordinary consumable allowance: 25,000. Reliable fast-clear decisions
  retain the 70-call ceiling, including a 16-call conservation pass and existing
  bounded development/growth work. Added retention candidates do not expand it.
- Whole-blind shop forecast: four common composition worlds and two limited
  policies, one to four hands, at most eight held cards / 120 deck cards. It can
  try no discard or one targeted initial nonclear discard. It is not general
  hands/discards/consumables search, a long Burglar planner or queued gameplay.
- Concealed continuation: shared 8,000-score allowance, 16 immediate worlds,
  at most eight held / 120 deck / 160 unseen cards, small public first-discard
  and future-play families. Incomplete extensions retain complete immediate
  evidence. Some unknown-discard identity signals, random future cash and hidden
  destruction remain unsupported; a public match reveals no hidden RNG.
- Ranked redraw additions exclude owned Jokers, Observatory, concealed/unknown
  identities and unupgraded target hands. Exact finite draw-completion arithmetic
  does not prove survival. Global specialist coverage is deliberately incomplete.
- Scoring must preserve Glass/population conservation, whole-inventory
  Perkeo/Negative/Observatory valuation, Kings development, exact Yorick/Burnt and
  safe growth. Candidate coverage is not permission to weaken these comparisons.
- Jokerless search is fresh-original-run only, 512 seeds per product batch,
  at most one million per user-started job. Saved preset IDs persist; a running
  job freezes its predicate. Planet X/Ceres/Eris are unavailable initial targets;
  Five of a Kind requires actual later deck development. Coupon cards/packs are
  free, but Telescope still needs actual affordable acquisition.
- The Legendary filter supports the other 19 challenge openings; its optional
  later route additionally excludes Bram's unsupported shop path. The route
  constrains skips, packs, rerolls, vouchers and stream-changing generation/
  ownership. Actual affordable acquisition, simultaneous retention and survival
  are not guaranteed. Multiple later targets and general alternate routes remain
  future work; current observations do not prove full prior route conformity.

## What five checkpoint reports actually do

The user creates/restores saves through their own workflow. At a settled
decision, **Remember this decision** records public metadata. The first accepted
Product Execute action becomes the pending line start. After manually restoring
a losing continuation, **I restored after a loss - try another line** spends one
of five reports shared across checkpoints of that conservative run identity.
This permits an original line plus up to five restored lines, not five fresh
independent runs. Mark changes never renew the count.

The system neither saves/restores nor detects a loss. It records the first
executed action, not a whole continuation or proof that this action caused the
loss. Actions outside Execute are not recorded. Alternative selection is narrow:
plain supported visible hand/discard families and complete revealed-Planet
endpoints, with no owned Jokers or Observatory. Complex Knife's Edge positions,
protected growth, concealed or larger/deeper paths commonly remain review-only.

Public identity omits hidden RNG/order and unstable object IDs while checking
known composition. Same profile/seed/challenge/deck/stake may conservatively
inherit previous spending. Journal bounds are 64 identities / 16 MiB, five
reports, 256 marks, 64 current attempted-action records. Missing/corrupt/partial
writes fail closed. The dedicated `.dat`/`.guard` metadata pair must survive
manual save restoration; external rollback of both files is not detectable
tamper-proof storage and never authorizes renewed spending. No actual user
journal or save was used for evaluation. Retry benefit remains unmeasured.

## Current evaluation and evidence navigation

`runs/lucky282_development/read_only_evidence.json` binds source11's six Lucky-
blocked snapshots/results and the already-preserved matching original source.
`LUCKY_CONTINUATIONS_282.md` documents the exact scope and synthetic fixtures.
The private transition is shared by existing after_play callers; their admission
guards remain. two_hand_finish still rejects ordinary uncertain future Lucky
scores before transition. No general joint consumable planner is added.

Candidate: runs/lucky282_candidate/validation; installed freeze:
runs/lucky282_installed; installed regression: runs/lucky282_installed_validation.
Release/budget: runs/lucky282_development/runtime_slices.json and FINAL_BUDGET_282.json.
Final hashes/docs preservation: runs/context_reset282_20260913/final_verification.json.
No source component, captured replay, seed search or complete attempt ran in282.

For evaluator source/tool navigation and historical outcome audits, use only
the relevant Evaluation and durable evidence section of ARCHITECTURE_MAP_281.md.
All old allowances are closed. The original12 attempts remain10 losses,1 error,
1 unsupported; furthest274 lost finalBell38,802/100,000.281/282 have no complete
attempt. No player win odds or measured real-time improvement follows.

## Release and preservation

Keep the existing dirty workspace and all untracked work on codex/exact-search-speedups.
No commit/reset/clean/deletion/PR; never launch/control Balatro or access saves for
evaluation. Product Execute remains user-clicked; loaded version unknown until
the user's normal restart. No training/automations. All genuinely new experiments
require fresh caps/cost authorization and prospective frozen provenance/one-use
limits. Relevant routine fixtures/regressions and read-only analysis are authorized.

Install coherent tested runtime slices immediately with explicit install_slice.py
files/backups, current settings protection, unchanged DLLs and verified installed
hashes/version/ledger. Changed native work requires its sidecar/evidence gate.
Freeze exact installed bytes and run bounded full regression. Current checkpoint,
priority and resume records supersede old component-note pending wording.

## Read-only diagnosis and tuning navigation

POSTMORTEM_METHOD_282.md: selected decision-time reviews, ex-ante counterfactual
standards, milestone/terminal metrics, paired-seed uncertainty and interaction
analysis. Source05 final-shop/Bell review and source05/06/10 dependent Eye review
with exact source hashes: runs/postmortem282_readonly/late_run/ and dependent_runs/.
These are retrospective analysis artifacts; no policy was executed or altered.

Fixed consumable base ratings: strategy.lua base_consumable_value (around524).
Six bounded coefficient defaults: policy_weights.lua. Existing calibrate_policy.py
and checkpoint_calibration.py can screen frozen variants only under fresh bounded
experiment authority. parameter_inventory.json records the read-only inventory;
no tuning, coefficient promotion, source qualification or terminal validation ran.
Use runs/postmortem282_readonly/final_verification.json for latest doc hashes;
installed282 product hashes/regression stay unchanged.
