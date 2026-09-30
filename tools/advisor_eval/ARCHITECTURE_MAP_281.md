# Advisor architecture and remaining work — 2.81 checkpoint map

This is a component/navigation map, not a deployment receipt. Read
`ADVISOR_START_HERE.md`, the finalized `SESSION_RESET_281` and
`NEXT_PRIORITIES_281` records first for installed hashes, final validation,
activation and experiment closure. Those records supersede interim 279 status
and historical component-note defaults. Paths below are repository-relative;
bare component notes live in `tools/advisor_eval/`. Do not reread the whole
historical `ADVISOR_HANDOFF.md` or reuse old chat/agent memory as evidence.

The installed-281 receipt is `runs/jokerless281_installed/record.json`: installed
2026-09-13T19:12:34.2093921Z and frozen/verified at 19:12:45Z. Final exact-installed
regression status belongs to the final root checkpoint, not this navigation map.

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
| Other challenge opening filters | `Brainstorm/Core/challenge_opening.lua`, `Advisor/challenge_route.lua`, shared opening UI; native source `Immolate/src/challenge_opening.cpp`, `immolate.hpp`. Two opening Legendaries plus one optional later vanilla Rare offer by Ante 2–8, under declared route/pool/rule conditions. Jokerless has its separate Planet route. | `advisor_challenge_opening.lua`, `advisor_challenge_later.lua`, `advisor_challenge_route.lua`; `LATER_TARGETS_265.md`, `NATIVE_LATER_265.md`, `CHALLENGE_LATER_CORE_UI_265.md`. |
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

## Evaluation and durable evidence

`tools/advisor_eval/engine_probe.py/.lua`, `engine_run.lua`, `engine_contract.lua`
load original source through ZIP reads and isolated Lua, freeze the adapter,
policy, synthetic profile and options, and record actual legal actions, score
checks, terminal/censor categories and failure observations. `development_report.py`,
`outcome_validation.py`, `paired_policy_audit.py`, `decision_replay.py`,
`action_replay.py`, `checkpoint_calibration.py`, `filtered_engine_compare.py`,
`filtered_opening_audit.py` and `filtered_route_selection.py` provide audit,
replay/calibration/route tooling. Existing replay is not a save-restoration
adapter. Source attempts explicitly bind `disabled_clean_attempt_v1` retry
context; no checkpoint-retry source cohort is implemented or qualified.

Tests include `advisor_engine_contract.lua`, `test_advisor_outcome_validation.py`,
`test_advisor_episode_boundaries.py`, `test_advisor_replay.py`,
`test_advisor_action_replay.py`, `test_advisor_retry_eval.py` and calibration/
filtered-route fixtures. Original mechanic probes are named `*_source_parity.py`
and `.lua` under the evaluator tools; source inspection and synthetic fixture
checks are distinct from executed source-parity workers and whole attempts.

The resumed push lives in `runs/jokerless271_push_20260912_214242/`:

- `authorization_resume_20260913.json` binds the original authority and prior
  immutable requests. No spent lease is renewed after shutdown.
- All 12 complete-attempt leases are spent: **10 losses, one malformed-trace
  error and one unsupported result**, 2,160 seconds reserved and
  484.6128155000624 seconds actual. The furthest run, source 5, lost at the final
  Bell, 38,802/100,000. `GAME.won=true` was an intermediate source flag;
  GAME_OVER and profile-completed=false correctly classify the attempt as loss.
- Seed search consumed all 300 reserved seconds. The final 40 complete batches
  cover four million new indices: 2.7 million Mars-tested with no candidate,
  1.3 million Jupiter-tested with three candidates. Its raw `not_found` means
  the requested fourth match was absent, not that no candidate existed. Earlier
  search timeout/censored tail and failed source probes remain preserved.
- `source_budget_resume_20260913.json`, immutable request/registration/record
  files and final checkpoint ledgers own arithmetic and remaining mechanical
  status. Local source component improvements never rewrite old losses or
  imply a rescued episode. The 281 played-secondary-Planet change occurs after
  all full-attempt leases were spent and has no new terminal outcome.
- Root component 7, `root_component07_secondary_planet`, compares the actual
  source-11 step-27 public input: the baseline uses 218 score calls and selects
  Small Blind; the candidate uses zero calls and recommends Mercury's exact
  Pair upgrade to level 2, 25 Chips / 3 Mult. This detached comparison passed,
  with no episode replay. Component 6's earlier harness incorrectly asserted a
  zero-evaluation baseline; its failure remains preserved and its lease spent.

These selected/adaptive synthetic profiles are unqualified for player win
rates. No audited Jokerless win, measured retry benefit, calibrated numerical
odds or all-20 completion-time gain follows. Passing tests and feature counts
are not wins. Historical rough percentage guesses remain unreliable estimates.

The old sixteen-worker pilot is **executed and spent**, not pending. As documented
in `SESSION_RESET_267.md` and `NEXT_PRIORITIES_267.md`, the unchanged original
`runs/weakness263_requests` contains only its historical unexecuted plan, but its
deferred allowance was consumed once by fresh `runs/weakness266_current_pilot1`.
That experiment compared frozen 262 against 266, not 267 or the current policy:
all 16 sequential 80-second workers ran under the 1,320-second workflow cap,
with 729.6207304 seconds worker wall time, six losses, five timeouts and five
unsupported outcomes; no wins or audit errors. `outcome_report.json` and
`completion_ledger.json` own the records. Both later step-75 component leases
are also spent. Historical 266 statements that the pilot was deferred are
superseded. Neither unused seconds nor the preserved original plan authorize
another worker, and censored/unsupported outcomes are not silently counted as losses.

## Remaining work, supported by current evidence

1. Collect genuinely new, prospectively frozen complete-attempt evidence only
   under fresh explicit bounded authorization. Existing attempts/seed ranges
   and closed historical pilots cannot be rerun by renewing their budgets.
2. Improve joint hand/discard/consumable/resource planning where complete failure
   comparisons justify it; larger hands, constrained bosses and limited future
   discard policies still dominate important gaps. Keep global caps unchanged
   unless separately justified and authorized.
3. Evaluate the acquisition, Blue generation, slot availability, main/secondary
   hand use and long-run retention of newly searched starts. Initial Mars/Flush
   preferences are implemented, not proven optimal. No matching Mars start was
   found in the last registered search; stronger same-rank Blue constraints and
   later Five-of-a-Kind pivots are not implemented opening guarantees.
4. Extend retry evidence/history beyond the first line-start only with a defined
   dependent-branch protocol; no save IO or five-independent-trials assumption.
5. Address unsupported visibility, ordered scoring/growth and inventory effects
   through exact source mechanics and complete controls, preserving safe fallback.
6. Measure actual endpoint/terminal accuracy and computation/user-action costs
   before calibrating weights. Earlier cache and sensitivity screens do not
   establish useful default promotions or universal speedups.
7. Qualify the expanded Legendary/later-Rare route's actual acquisition and
   simultaneous retention, including miss, death, expiry, sacrifice, capacity,
   stream conformity and setup costs. Broader all-20 targets remain unresolved.

## Operational handoff constraints

Preserve every tracked/untracked change on `codex/exact-search-speedups`.
No commits, reset, clean, deletion of existing work or PR. Never launch
`Balatro.exe`, even headless; never foreground/fullscreen/restart/stop/control
the running game or perform live gameplay. No saves for evaluation. Original
source ZIP reads and isolated hidden `lua51.dll` execution require bounded
registered workers when used for evaluation. No neural/GPU training, schedules
or automations. All future output directories/provenance must be fresh and
errors/timeouts/unsupported/missing/censored results retained.

Use `tests/run_lua_tests.py` inside a hard timeout; it is not itself a cumulative
budget controller. Run meaningful focused checks and the required frozen full
regression. Install each tested coherent runtime slice using
`tools/advisor_eval/install_slice.py` with explicit files, backups, protected
current settings and verified installed hashes/versions/ledgers. Documentation
and tooling-only changes need no release. Preserve both existing native DLLs;
native changes require the documented sidecar/source-evidence gate. Never
restore historical settings over the user's current configuration. Loaded game
version remains unknown until the user's normal restart; tools do not activate it.

Root owns finalized START, HANDOFF, checkpoint/priority, deployment and resume
records. The component notes above explain mechanics and evidence; their old
unchecked items, estimates and installation paragraphs are not current status.
