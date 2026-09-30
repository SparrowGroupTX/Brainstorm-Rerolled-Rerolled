# Advisor improvement and evaluation

Current checkpoint: [SESSION_RESET_265.md](SESSION_RESET_265.md) and
[NEXT_PRIORITIES_265.md](NEXT_PRIORITIES_265.md). Installed 2.65 completes the
resumed bounded repairs and the requested later Rare-target challenge search.
[LATER_TARGETS_265.md](LATER_TARGETS_265.md) explains user controls and conditional
route limits; [NATIVE_LATER_265.md](NATIVE_LATER_265.md) records source evidence.
All 46 deployed files and 61 frozen dependencies match repository/installation.
86 Lua fixtures / 175 Python tests pass. No full-run win-rate improvement is
demonstrated. The registered 16-worker comparison remains deferred, unexecuted.
Search-only misses and source mechanics fixtures cannot be counted as game outcomes.

Historical checkpoint: [SESSION_RESET_262.md](SESSION_RESET_262.md),
[NEXT_PRIORITIES_262.md](NEXT_PRIORITIES_262.md), and
[INTERVENTIONS_TOP10_254.md](INTERVENTIONS_TOP10_254.md). Installed2.62 has completed
the authorized next-ten program within bounded scopes.80Lua fixtures/129Python
tests pass; all44deployed files and58frozen product/dependency files match.
No measured win gain, coefficient promotion or filtered-route recommendation.
[CALIBRATION_FILTER_TOOLING_258.md](CALIBRATION_FILTER_TOOLING_258.md) documents
declared profiles, meaningful checkpoint screens and retained-engine total costs.
Start here rather than following historical unchecked priorities below.

Historical2.46 checkpoint: [SESSION_RESET_246.md](SESSION_RESET_246.md),
[NEXT_PRIORITIES_246.md](NEXT_PRIORITIES_246.md), and
[INTERVENTIONS_6.md](INTERVENTIONS_6.md). The installed version then was2.46;
later dated status supersedes historical proposals below. Verified prefix replay
and real decision comparison are documented in [VERIFIED_REPLAY_245.md](VERIFIED_REPLAY_245.md)
and [COEFFICIENT_CALIBRATION.md](COEFFICIENT_CALIBRATION.md). New bounded tools:
`decision_replay.py`, `component_profile.py`, `filtered_engine_compare.py` and
`conditional_value_source_parity.py`. None qualifies a policy or claims measured
win-rate improvement. Final evidence includes the same selected loss after one
unnecessary purchase is removed, variable cache benefit, and real filtered attrition.

For the 2026-09-10 handoff, start with
[ADVISOR_START_HERE.md](../../ADVISOR_START_HERE.md). Sections 7–10 of the
[comprehensive handoff](../../ADVISOR_HANDOFF.md) record the latest proposals
for Joker progression, offline evolutionary tuning of deterministic heuristic
coefficients, and profiling. Bounded batch accounting, component profiling and
runtime dependency manifests now exist as described below. The separate filtered
source setup route now runs original callbacks and checks the real native pair.
Representative full-run collection and successful coefficient calibration remain incomplete.

The requested milestones apply to **every challenge individually**: establish
50% wins, then improve to 75%. The latest instruction is to work on the
deterministic system only. Neither win-rate milestone is established yet.
Model development and GPU training are set aside unless requested again.

After the baseline qualifies, the user's ultimate objective is **expected time
to complete each challenge**, including failed attempts and retries. A shorter
80% policy may beat a much slower 90% policy. Measure successful and failed run
durations, inference latency, hands played, rerolls and skips. For stationary
independent retries, expected time to first success is mean attempt duration
divided by win probability; equivalently successful-run mean time plus
`(1-p)/p` times failed-run mean time. Prefer timing measured with the game's
animation/action costs over raw headless simulation speed. Bounded Joker-order
search is implemented; qualified speed-aware blind skipping and full-run time
comparisons remain outstanding.

## What exists

- `benchmark.py` freezes the advisor source, registers fresh seeds, and audits
  complete episode results against the per-challenge gates.
- `engine_probe.py` reads the original Lua modules from the user's installed
  `Balatro.exe` ZIP and runs them in its bundled LuaJIT library. It does not
  execute the game EXE, create a window, or access physical save files.
- `engine_probe.lua` supplies explicit non-rendering presentation boundaries
  and in-memory storage. Original game/Card/CardArea/Blind/event rules remain
  the engine. Unknown boundaries fail instead of silently inventing mechanics.
- `engine_run.lua` extends that probe through actual advisor actions. This is
  still a development adapter, not validated full-run win-rate evidence.
- `development_report.py` / `engine_probe_development.py` run bounded hidden,
  sequential episodes with preserved traces and a per-challenge report. Every
  attempt is classified as win, loss, censored, timeout, unsupported or error.
  Component timing uses the host monotonic clock; each decision records actual
  scoring-call counts, and a timeout retains the last started decision.
- `Brainstorm/Advisor/decision.lua` is the shared decision entry point used by
  the in-game runtime and evaluation, including held consumables.

Development seeds such as `ADVISOR1` are for debugging only. A successful test
on one of those seeds is not a held-out evaluation result. Unit fixtures are
synthetic and must never be written into an actual campaign's episodes file.

## Bounded development batches and profiling

```powershell
python tools/advisor_eval/engine_probe_development.py --challenges c_omelette_1 c_fragile_1 --seeds ADVISOR7 --stop-after-step 3 --timeout 45 --label profile001
python -m unittest discover -s tests -p 'test_advisor_*.py'
```

Use a fresh label or `--output-dir`; existing output directories are rejected.
The default directory is `tools/advisor_eval/runs/development_<label>`. Each
batch writes its requested episodes to `manifest.json`, appends one outcome per
attempt to `episodes.jsonl`, and refreshes `report.json` after every attempt.
Trace paths and exact replay commands are retained. Optional `--policy-root`
selects a stable frozen product root; the probe refuses files changing during
loading. Defaults are 40 actions and 45 seconds per episode, with explicit caps
of 500 actions, 300 seconds and 100 episodes. No game executable is launched.

Action/round limits are **censored**, not losses or unsupported mechanics. A
real terminal outcome at the same action boundary takes precedence over the
development limit; GAME_OVER takes precedence over the completion flag.
Timeouts, launch failures, incomplete traces and unsupported mechanics remain
in the attempted denominator. No complete win-rate fraction is reported for a
cohort containing unresolved or censored episodes. A failed or timed-out run
does not prevent later requested episodes from being recorded. Exit code 2
indicates an error, unsupported surface or timeout; a censored smoke test alone
is not an adapter failure.

Reports separate challenges, product hashes, start distributions, engine and
adapter hashes. They include observed failure reasons/replay examples, action
counts, startup/engine/snapshot timing, and advisor p50/p95/p99 latency with
scoring-call counts. Percentiles use nearest rank and always include the sample
count; a three-decision smoke test cannot establish a population tail latency.
Strategic causes of losses are not inferred from the last hand. This is hidden
engine throughput and inference timing, not measured live frame impact or human
completion time; animation/click cost models and source parity remain required.

The first instrumented smoke used frozen 2.17 policy, Omelette development seed
`ADVISORPROFILE217`, and stopped after three actions in 7.14 seconds. Its two
hand decisions took 3.05 and 3.36 seconds with 131,011 and 119,197 scoring calls.
Both were discard decisions. This validated instrumentation and censorship,
not a speed improvement, blind clear or win rate. See
`runs/development_profile217first/report.json` for the preserved provenance.

The final 2.19 smoke used `ADVISORPROFILE219`, Omelette and Fragile, three actions
each and a 35s limit. Both runs were censored (5.67s/1.62s). Fragile's final
clearing action used 16 scoring calls, about 0.28ms advisor time, and both the
model and source engine scored 1,920. Omelette nonclear searches still used
138,220/134,077 calls and 2.61s/2.66s. Different seeds and tiny timing samples do
not establish a paired speedup, tail latency or win rate. Preserved report:
`runs/development_profile219final/report.json`.

Product manifests now include Advisor/Core/UI and root Lua, Lovely patches,
native library variants/runtime dependencies, and native seed datasets. Personal
config/saves, build symbols and backup directories are excluded. The same
manifest routine is used for formal freezing and source probes. Ordinary runs
record `opening_policy_loaded: false`; only the explicit separate native route
loads `modules.opening`. Qualification and ordinary paired manifests reject
mixed/filtered records. The filtered development protocol below remains
unqualified and does not share the ordinary denominator.

The first complete Omelette development pilot (`ADVISOR1`) **lost at Ante 2**.
Nine deterministic predicted plays matched actual engine chips; the run also
executed Egg sales, purchases, a booster, a voucher, cash-outs and a boss. This
is one development run under a synthetic unlock profile and an experimental
adapter, not an estimate of this user's win probability. The trace suggests
investigating how discards spend Banner's scoring value over remaining hands;
use counterfactual replays before asserting that this caused the loss. Complete
the remaining phase/consumable/terminal parity checks and declare the unlock
profile before qualifying the adapter.

## Reproducible qualification

This protocol is retained for a future request to establish measured targets.
Current work uses targeted regression checks and at most a few bounded headless
development episodes. A large campaign is not required before a useful update
is installed. See [subjective per-challenge estimates](ESTIMATES.md); those
working guesses are not qualification results.

1. Finish the engine action dispatcher for every decision phase. Execute the
   advisor's exact action and fail explicitly on missing/ambiguous actions.
   Preserve scoring/event order, shop/pack generation, challenge restrictions,
   consumable targeting, end-of-round economy and the actual terminal outcome.
   The source game's `G.GAME.won` alone is insufficient: it is set on entering
   the final-boss end-round path even before the loss check. Require actual
   successful win handling; GAME_OVER always takes precedence.
2. Validate engine parity and determinism across all 20 challenges. Review
   every presentation shim for embedded gameplay behavior. Freeze the adapter
   and save a mechanics parity report; hash that report and adapter. Tests must
   include `challenge_setup`, `draw_rng`, `hand_scoring`, `joker_triggers`,
   `boss_rules`, `shop_and_packs`, `consumables`, `round_economy`,
   `terminal_outcomes`, `verbatim_actions`, and `save_isolation`.
3. Freeze a candidate policy before generating fresh evaluation seeds. Keep
   all campaigns in `tools/advisor_eval/runs/`, incrementing the attempt number
   for each fresh qualification attempt, including failed policies. Do not
   tune a candidate on its evaluation seeds or keep rerolling until it wins.
4. Complete the entire registered campaign. Default: 400 independent seeds for
   each challenge, 8,000 episodes total. Missing, timed-out, unsupported, and
   errored episodes prevent passing. Preserve action traces and hashes.
5. Audit every challenge separately. After the 50% gate passes, improve the
   policy on development data and run a fresh 75% campaign. Continue comparing
   deterministic policies by expected completion time. A passing milestone
   does not authorize model building or training under the current instruction.

The gate uses exact one-sided binomial lower confidence bounds, rather than
accepting a raw sample percentage. The calculation inverts the binomial tail
as described in [NIST's confidence interval reference](https://itl.nist.gov/div898/handbook/prc/section2/prc241.htm).
The error allowance is split across both milestones, all 20 challenges, and
adaptive attempts: `0.05 / (2 * 20 * attempt * (attempt + 1))` per bound. This
controls the family error at 5% if each attempt uses fresh independent seeds
and a policy fixed before sampling. Do not reset attempt numbering, relocate
campaigns to bypass its check, inspect future engine RNG in the policy, or
reuse qualification seeds for tuning. Increasing the sample count must also
be decided before running the campaign.

Commands from the repository root:

```powershell
python tests/run_lua_tests.py
python -m unittest discover -s tests -p test_advisor_benchmark.py
python tools/advisor_eval/engine_probe.py --challenge c_omelette_1 --seed ADVISOR1
python tools/advisor_eval/benchmark.py init tools/advisor_eval/runs/stage50-attempt1 --engine "C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe" --stage 50 --attempt 1
python tools/advisor_eval/benchmark.py report tools/advisor_eval/runs/stage50-attempt1 --validation tools/advisor_eval/runs/adapter-validation.json
```

Initialization only registers a campaign; it does **not** run games. Reporting
returns exit code 2 while a target is not established. A 75% initialization
also requires `--previous-gate` pointing to the completed 50% `report.json`.

## Episode/adapter contract

The post-2.31 source dispatcher accepts settled Joker reorder in hand, shop,
blind, pack and round phases, matching `execution.lua`; hand reorder remains
hand/pack only. Buy-and-use uses the original shop UI legality callback. Both
paths retain area, pin, shuffle and drag checks. `engine_contract.lua` separates
exact-score equality from certified random-floor inequality. A source result
above a supported floor is valid and emits `engine_episode_score_verified`.

`episode_source_parity.py --policy-root FROZEN_ROOT --output-dir NEW_DIRECTORY`
runs four hidden bounded source fixtures: preblind Dagger reorder plus real
blind-start sacrifice, a real Misprint play above its certified floor, and final
boss win/loss handling. Synthetic fixture provenance excludes these outcomes
from ordinary/filtered policy evidence. The 2.32 frozen run passed 15 assertions;
the pure adapter/execution contract fixture passes another 19 checks.

`development_report.py --full-episode` removes its development action cutoff,
while retaining the per-process wall-clock cap and the 500-action adapter cap.
Failure and terminal records now preserve the last decision and final detached
snapshot; failed attempts export a trace-hashed `.failure.json`. Reports group
observable symptoms (score deficit, exhausted hands, remaining discards,
unspent consumables, low usable population, active boss) separately from adapter
coverage, score/legality defects and decision/transition timeouts. These groups
identify replay targets and do not prove strategic causation.

The frozen 2.32 `ADVISORCOVERAGE332` pilot attempted four full episodes with 45s
limits: Golden Needle lost at Ante 2 (608 chips short); Knife and Jokerless timed
out in decisions at Ante 3/2; Omelette stopped at Ante 2 on the subsequently
fixed floor-vs-exact adapter assertion. Preserve all four outcomes. This is not
win-rate qualification. Reports and source fixtures are under
`runs/development_episodecoverage332/`.

## Separate filtered source setup comparison

`engine_probe.py --episode --opening-targets j_yorick,j_perkeo
--opening-search-limit 1 --seed I1L21111 --stop-on-opening-complete` invokes the
frozen product's real `challenge_opening_v1` native API with one worker. The
registered seed is the native **search start**; provenance records the actual
found `run_seed` separately. Empty `--opening-targets ""` means Any pair. The
source run starts only after a real native `found` result. Misses retain their
elapsed search cost and `next_seed`, with no playable run seed or terminal result.
Use the bounded collector below; the raw probe alone has no wall-clock cutoff.

The adapter applies exactly the two frozen Lovely Charm callsite replacements,
loads the unmodified frozen Core opening module and copying-source hook, and
records hashes before/after the source patch. Original `start_run`, skip/tag,
pack generation, legal Egg sales and Soul-use callbacks execute in the detached
Lua process. A setup completion requires both actual Legendary keys to equal
the native ordered pair. Subsequent episode decisions use the same advisor;
the optional setup stop is explicitly censored. Unsupported Jokerless searches
remain rejected. Ordinary probes and replay do not silently gain this route.

```powershell
python tools/advisor_eval/filtered_opening_audit.py --policy-root FROZEN_ROOT --output-dir NEW_DIRECTORY --challenge c_omelette_1 --challenge c_knife_1 --seed I1L21111 --targets j_yorick,j_perkeo --search-limit 1 --ordinary-actions 2 --timeout 20 --cohort-label preselected_known_two_soul_source_fixture
```

This freezes product/adapter bytes, alternates ordinary/filtered execution, and
retains separate provenance, native miss/error/timeout attempts, actions, actual
pair and search/setup costs. The two endpoints differ: a short ordinary action
prefix versus completed filtered setup. Their wall times cannot be interpreted
as relative game completion time or win probability. The hidden CPU setup cost
includes one original initialization on the found seed, not disposal of a live
run, real animation/user action time, or the native search's candidate prevalence.

The preserved 2.32 `runs/development_filtered339/paired_setup/` fixture used the
already known `I1L21111` opening: Omelette completed five actions and Knife three,
both yielding Yorick/Perkeo through original callbacks. Native search plus source
setup was about 0.756s/0.649s; ordinary two-action prefixes were censored after
4.739s/2.599s. These are different endpoints and a selected fixture, not a speedup
or win-rate estimate. `no_find/` preserves an unselected `ADVISOR1`, limit-one
miss (~0.028s native search, ~0.297s total process) and its ordinary prefix.
Ten Python tests cover source-patch exactness, separate distributions, seed/pair
identity, costs, native provenance and refusal to turn a miss into a playable run.

The frozen v2.39 `knife239_episode_prefix.log` also continued seven advised
actions past acquisition, cleared Big Blind with predicted/actual 528, cashed
out and bought Mercury (1.164s, censored). At Big Blind entry the pinned Eternal
Dagger consumed immature Yorick: the opening row has no harmless blocker/fodder.
Perkeo survived. Acquiring the searched pair therefore does not imply retaining
two Legendary engines; the adapter emits `engine_opening_pair_changed` when
an acquired target later leaves the owned row. This is a concrete continuation
limitation for filtered challenge valuation, not a source setup failure.
`filtered_retention_parity.py --policy-root FROZEN_ROOT --output-dir NEW_DIRECTORY`
rechecks nine assertions through acquisition, source Dagger sacrifice and the
first clearing play/cash-out. Final evidence is in `retention_parity_final/`
(1.146s, seven-action censor). Original Arcana pack Souls are used immediately;
there is no legal take/store action or blind selection while that pack remains
open. The Core opening policy was left unchanged; no nonexistent deferral action
or extra game-rule exception was added.

`episodes.jsonl` has one JSON object per registered episode: `id`, `challenge`,
`seed`, `manifest_digest`, `policy_digest`, `rules_digest`, `adapter_digest`,
`trace_digest`, `source: "game_engine"`, `followed_advice: true`, `decisions`,
`outcome` (`win`, `loss`, `error`, `timeout`, `unsupported`, or `censored`), `ante`, and
`game_won` (true only after authentic successful win handling).
Schema-2 registrations also require the exact registered `start_distribution`
on every episode. Censored results explicitly block qualification.

The reviewed adapter validation JSON contains `status: "validated"`, the
`rules_digest` of the installed rules bundle, `adapter_digest`,
`parity_report_digest`, the full `challenges` list and `checks_passed` list.
These are provenance/audit checks, not proof that an arbitrary simulator is
correct. Do not issue this attestation before reviewing actual source parity.
Reports deliberately refuse to pass without it.

## Deterministic work only

The current task excludes model building and GPU training. Reports expose the
75% qualification milestone separately and always set `training_allowed` to
false. Neither unit tests nor a qualified milestone restores authorization
for that earlier phase. No GPU workload is started by these evaluation tools.

## Continued work

The unwanted hourly continuation was deleted at the user's request. Do not
recreate it. Continue only during authorized work. Preserve settings/saves,
do not manipulate the user's active run or launch visible game windows, and
avoid overlapping heavy evaluation processes while the user plays. The latest
instruction is to install **each successfully implemented and checked feature**,
with backups, preserved config/saves and installed-file verification. This
replaces the previous estimated ten-percentage-point batching threshold;
never inflate estimates to claim a gain. Separate
ordinary random starts from intentionally filtered opening distributions.
Every installation includes subjective, very-low-confidence estimates and
separate concrete observations. Maintain the [estimate/update ledger](ESTIMATES.md).
The user can execute one displayed recommendation with the HUD button. Never
trigger it autonomously or queue a loop of live-game actions.
