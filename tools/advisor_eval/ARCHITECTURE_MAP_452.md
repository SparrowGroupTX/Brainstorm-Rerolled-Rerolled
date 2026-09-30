# Focused code map for simulator fidelity and later training

Post-452 addendum: [slice 453](development453/REPORT.md) adds an in-memory
plain-Juggler expiry repair, source-derived comparison contract and manufactured
receipts. The broad learning-episode expiry guard remains; the rest of this
452 map describes the baseline at that checkpoint.

Paths are relative to the repository. Read narrow relevant ranges, not every
module. Statements below were checked by source inspection; no source callbacks,
captured states, simulator episodes or training were executed for documentation452.

## Production advisor: installed451/2.226

| Component | Main responsibility / limitation |
|---|---|
| `Brainstorm/Advisor/snapshot.lua` | Public snapshot, identity/redaction and fingerprints; preserve legal information boundaries |
| `Brainstorm/Advisor/scoring.lua` | Score, after_play, after_discard; distinguish exact, mean, supported floor and sampled effects; not a universal exact world engine |
| `Brainstorm/Advisor/sampled_outcomes.lua` | Keyed private outcomes for compared branches; same-world consistency, not source RNG equivalence |
| `Brainstorm/Advisor/draws.lua` | Supported refill and automatic ordering; resource/visibility boundaries matter |
| `Brainstorm/Advisor/consumables.lua` | Actual supported owned use, physical inventory removal, Negative capacity, retained effects |
| `Brainstorm/Advisor/strategy.lua` | Heuristic strategic/economic valuation, full Perkeo inventory and preservation costs; these are policy judgments, not game laws |
| `Brainstorm/Advisor/decision.lua` | Search/consumable/specialist arbitration, work accounting, selected action |
| `Brainstorm/Advisor/search.lua` | Current play/discard families and bounded continuations; candidates can be omitted by admission/budgets |
| `Brainstorm/Advisor/growth.lua` | Retained-clear discard proof and candidate shortlist;450 adds Steel-preserving candidates |
| `Brainstorm/Advisor/two_hand_finish.lua` |451 adds no-discard two-hand Planet use/hold comparison; existing remaining-discard mode preserved |
| `Brainstorm/Advisor/phase_copy.lua` | Phase-specific Blueprint/Brainstorm/Burnt/Perkeo ordering |
| `Brainstorm/Advisor/finish_rewards.lua`, `conditional_value.lua` | Selected bounded reward/value support; not a complete round/shop lifecycle |
| `Brainstorm/Advisor/acorn_belief.lua`, `acorn_ordering.lua`, `acorn_discard.lua` | Public retained Joker-order belief; unknown worlds must stay unknown |
| `Brainstorm/Advisor/player_journal.lua`, `player_log_archive.lua` | Public observation/advice/action/settlement evidence, BRJ2 archives |
| `Brainstorm/Core/auto_run_product.lua`, `auto_run_settlement.lua`, `auto_terminal.lua` | User-started product execution/settlement/terminal handling; do not invoke game control |

The current generic scorer header explicitly says random effects can use their
mean. A simulator must select an actual outcome and advance actual state; a
mean above the blind target is not necessarily a reliable clear. Do not remove
uncertainty warnings or substitute an expected-value score for transition parity.

## Lua continuation tooling

`tools/advisor_eval/continuation_adapter.lua`:

- `canonical` keeps public composition stable, handles Acorn redaction/belief.
- `legal` qualifies concrete play/discard selections and forced constraints.
- Current loop supports reorder, owned use, discard/refill and sampled play.
- `run` sets `full_run=false`, `round_rewards_modeled=false`; action cap1..16.
- It uses `world_seed`/`world_order`, its own sample stream, not a source seed replay.
- It stops once chips meet the current blind; no general rewards/shop/next-blind
  cycle. Narrow pack intervention support is not arbitrary pack/game support.
- Acorn consumable transitions and other explicit mechanics can remain unsupported.

`continuation_evidence.lua` exports bounded structured frames and unsupported
diagnostics. `run_frames` is a tool entry point, not a launcher or authorization.
Closed continuation studies under435,437,439 are evidence only. Modern updates
to this Lua adapter did not automatically repair the separate Python simulator.

## Python learning simulator

`tools/advisor_learning/environment.py` wraps pinned Jackdaw commit
`92df18c27e26e6d324132942905e41242e4e24bf`. Default source is under
`tools/advisor_eval/development355/external/jackdaw`.

Constructing `Environment` starts an episode. Do not instantiate it during casual
inspection or a manufactured test. The wrapper directly imports engine modules,
applies its overlay, emits public numeric observations and enumerates concrete
candidate actions. It does not use the upstream live bridge/Gym encoder.

Base dimensions: global80/entities64/candidates160. Specialized dimensions:
global530/entities67/candidates163, including historical Gold collection objective.
Bounds128 entities/4096 candidates; overflow is unsupported. Candidate coverage
has restrictions: e.g. no boss reroll/buy-and-use, current-order play subsets with
adjacent swaps, conservative hidden-Joker restrictions. These limits also affect
what a learned policy could ever choose.

Important source locations in the pinned engine:

| File under `jackdaw/engine/` | Inspect for |
|---|---|
| `game.py` | `_joker_end_of_round_effects`, `_round_won`, cash-out, shop and phase orchestration |
| `round_lifecycle.py` | Rental/perishable processing; current expiry writes debuff without full passive removal |
| `jokers.py` | Trigger dispatch/order and handlers, Burnt/Perkeo/copy semantics |
| `card.py` | Identity, stickers, debuff and card mutations |
| `consumables.py` | Legality and concrete target/use rules |
| `run_init.py` | Initialization and hidden random starting state |

The frozen upstream is evidence: do not edit it in place. A new implementation
or overlay must have its own source/provenance and qualification.

`tools/advisor_learning/simulator_patches.py` currently repairs Burnt pre-discard
copies, Perkeo copies, sticker compatibility/exclusion and permanent expired
debuff latching. It still stops at near-expiry Perishables, unqualified debuffed
passive effects and Mime held Gold/Blue repetitions. `apply_patches` verifies
upstream hashes; `audit_state_boundary` can inspect private state only to reject
an entire episode, not guide policy decisions. Censoring is not successful fidelity.

## Model, trainer and real-game data are not yet connected

| File under `tools/advisor_learning/` | Current behavior |
|---|---|
| `model.py` | PublicCandidatePolicy scores supplied candidate tensors and predicts state value; invalid candidates masked |
| `train.py` | Simulator workers/PPO collector; imitation target is `heuristic_index`; no current-journal dataset loader |
| `heuristic.py` | Disclosed weak baseline; not installed advisor2.226 |
| `specialized_environment.py`, `objective.py` | Historical synthetic post-Soul Red/Gold opening and distinct-new-Gold objective |
| `gae.py` | Terminal/censor-aware advantage handling; not a simulator validation mechanism |
| `experiment.py` | One-use freeze/cap/receipt mechanism;355 leases are closed |
| `public_context.py` | Structured redacted current-game teacher context; explicitly not old-checkpoint migration |
| `teacher_demonstrations.py` | Link observations/advice/requests/callbacks/settled states/outcomes; unreviewed labels, no candidate reconstruction/training |

The converter reports `legacy_checkpoint_compatible=False`, initially sets
`imitation_eligible=False`, and leaves `semantic_completion_verified=False`.
Callback acceptance plus a first settled state is not automatically a complete
action label. New encoder, legal-candidate mapping, label policy and whole-run
train/validation/test partitioning are still required.

## Independent reference tooling

Selected scripts: `conditional_value_source_parity.py`, `blind_start_source_parity.py`,
`discard_source_parity.py`, `boss_source_parity.py`, `catalog_joker_source_parity.py`,
`qualify_episode_boundaries.py`, `engine_probe.py` and their Lua adapters.
Read them as implementation examples; do not run them automatically. Some read
Balatro.exe as an archive and execute extracted original callbacks in isolated
Lua. That is original-source execution, even though no game window appears.

`qualify_episode_boundaries.py` explicitly excludes intervening full-run transitions,
every effect combination and live frame timing. Its manufactured terminal scenarios
mutate state to reach boundaries; passing is not a completed policy win.

Retained rules evidence: `runs/chicot_order_source1/source/card.lua` and source
references linked by `development355/SIMULATOR_FIDELITY_AUDIT.md`. Check hashes
before relying on source. Never present shared scorer agreement as independence.

## Public log inspection

`read_player_log.py` decodes/verifies JSONL/BRJ2 framing. `flag_suspect_decisions.py`
and `review_decisions.py` operate on immutable copied public logs, without running
policy/scoring. See [DECISION_REVIEW.md](DECISION_REVIEW.md). Structural alternatives,
scalar Joker merit and heuristic flags are leads, not optimal-action labels.
Non-clearing plays, consumables, pack openings and ordering have coverage limits.

Use the manifests/SQLite copies in [current evidence](CURRENT_EVIDENCE_452.md).
SQLite analysis should open `mode=ro`. Do not feed a captured snapshot into Lua
policy or Python engine merely because it can be reconstructed from the log.
